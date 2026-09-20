------------------------------------------------------------
-- 視窗工廠：建出一個自給自足的統計視窗
--
-- 每個視窗有自己的 frame 樹、長條池、捲動狀態、展開頁、首頁。
-- 多視窗就只是一個 W 的陣列，沒有第二套程式碼。
--
-- ⚠ 刻意**不**把整個視窗寫成一個大工廠閉包：那種寫法很快就會頂到 Lua 5.1 的
--   60 個 upvalue 上限，之後每加一個 helper 都得從 ns 繞一圈回來拿。
--   這裡的分工是：工廠只負責建出 W（frame 樹＋池），實際的繪製／拖曳／展開／首頁
--   都是模組層級的函式，W 當第一個參數傳。效能一樣（多一次 table 索引），
--   但沒有天花板、每個檔案都讀得完。
------------------------------------------------------------
local _, ns = ...

ns.Window = {}
local Win = ns.Window
local D = ns.Data
local M = ns.Media

local BAR_POOL_SIZE = 40
Win.BAR_POOL_SIZE = BAR_POOL_SIZE

local MIN_W, MIN_H = 150, 50
Win.MIN_W, Win.MIN_H = MIN_W, MIN_H

local ICON_ALPHA       = 0.55
local ICON_HOVER_ALPHA = 1.00
-- 按鈕之間留一點縫。零間距的一排圖示會黏成一條帶子 —— 圖檔本身已經有 18% 留白，
-- 這是第二層（見 miliui-damagemeter-icons 技能的「留白是設計的一部分」）。
local BTN_GAP = 2
local TYPE_PAD = 5     -- 左側類型圖示離視窗左緣
local TYPE_GAP = 4     -- 類型圖示與標題之間
local STATUS_GAP = 6   -- 標題與狀態標籤（目前／總計／首領名）之間
local TIMER_PAD = 6    -- 計時器離右緣（沒有圖示時）
local TIMER_GAP = 4    -- 計時器與圖示、與左邊標題之間

-- 狀態標籤的明暗：跟標題**同一個色相**，往標題列底色混暗（miliui-color-states）。
-- 閒置暗一階，滑過亮到跟標題一樣，智慧顯示自動切換時亮一下再暗回去。
local STATUS_K       = 0.55
local STATUS_HOVER_K = 1
local PULSE_TIME     = 0.9

------------------------------------------------------------
-- 標題列按鈕的貼圖
--
-- 自己畫的一套八款 128px PNG（純白＋alpha，由下面的 SetVertexColor 染職業色）。
-- **不用暴雪的 Interface\Buttons：**那幾張是 16~32px 的舊素材，放到 22px 會糊，
-- 而且來自三個不同年代，湊在一起像雜牌軍。也不用 atlas —— atlas 被拿掉時
-- 是靜默失敗（見 miliui-inspect-icons 技能踩過的坑）。
--
-- ⚠ PNG 是 `.claude/skills/miliui-damagemeter-icons/scripts/dm-icons.py` 畫出來的，
--   要改造型改腳本再跑一次，不要拿繪圖軟體去修 PNG。
------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\MiliUI_DamageMeters\\Media\\"
local BTN_TEX = {
    meters     = MEDIA .. "icon-meters.png",
    segments   = MEDIA .. "icon-segments.png",
    reset      = MEDIA .. "icon-reset.png",
    settings   = MEDIA .. "icon-settings.png",
    locked     = MEDIA .. "icon-locked.png",
    unlocked   = MEDIA .. "icon-unlocked.png",
    publish    = MEDIA .. "icon-publish.png",
    publishOff = MEDIA .. "icon-publish-off.png",
}
Win.BTN_TEX = BTN_TEX

-- 發佈被封鎖時的壓暗係數：強調色三個分量各乘它（套組慣例，狀態只換明暗不換色）
local BLOCKED_K = 0.45

------------------------------------------------------------
-- 字型
------------------------------------------------------------
function Win.SetFont(fs, size)
    local s = ns.DB.Style()
    fs:SetFont(M.Font(s and s.font), size or (s and s.leftFontSize) or 11,
        (s and s.fontOutline ~= "NONE") and s.fontOutline or "")
end

function Win.TextColor(s, which)
    local c = (which == "right") and s.rightTextColor or s.leftTextColor
    return c and c.r or 1, c and c.g or 1, c and c.b or 1
end

-- 長條顏色：職業色 → 拿不到就退中性灰（敵方傷害承受退紅），
-- 或依設定用強調色／自訂色
function Win.BarColor(s, classFile, dmType)
    if s.barColorMode == "class" then
        local r, g, b = M.ClassColor(classFile)
        if r then return r, g, b end
        if dmType == D.T.EnemyDamageTaken then return 0xDD/255, 0x31/255, 0x31/255 end
        return 0.5, 0.5, 0.5
    elseif s.barColorMode == "accent" then
        return M.Accent()
    end
    local c = s.barColor
    return c and c.r or 0.35, c and c.g or 0.55, c and c.b or 0.8
end

------------------------------------------------------------
-- 長條工廠
--
-- 建完就不再銷毀（frame 在 WoW 裡刪不掉，見 wow-frame-lifecycle-costs）。
-- 換排名只是重新 SetPoint ＋填值。
------------------------------------------------------------
function Win.MakeBar(parent, W)
    local bar = {}

    bar.row = CreateFrame("Button", nil, parent)
    bar.row:SetHeight(18)
    bar.row:EnableMouse(true)
    bar.row:RegisterForClicks("AnyUp")

    -- 軌道底色（在填充之下）。預設 alpha 0 = 看不見。
    bar.bg = bar.row:CreateTexture(nil, "BACKGROUND", nil, -8)
    bar.bg:SetAllPoints(bar.row)

    bar.fill = CreateFrame("StatusBar", nil, bar.row)
    bar.fill:SetMinMaxValues(0, 1)
    bar.fill:SetValue(0)
    bar.fill:SetStatusBarTexture(M.WHITE8X8)

    bar.icon = bar.fill:CreateTexture(nil, "OVERLAY")
    bar.icon:SetSize(18, 18)
    bar.icon:SetPoint("LEFT", bar.row, "LEFT", 0, 0)
    bar.icon:Hide()

    -- 文字掛在自己的 frame 上，層級墊在邊框（row+3）之上，
    -- 否則玩家開了邊框之後數字會被邊框壓住
    local tf = CreateFrame("Frame", nil, bar.fill)
    tf:SetAllPoints(bar.fill)
    tf:SetFrameLevel(bar.row:GetFrameLevel() + 4)
    bar.textFrame = tf

    bar.rank = tf:CreateFontString(nil, "OVERLAY")
    bar.rank:SetPoint("LEFT", tf, "LEFT", 3, 0)

    bar.label = tf:CreateFontString(nil, "OVERLAY")
    bar.label:SetPoint("LEFT", bar.rank, "RIGHT", 2, 0)
    bar.label:SetPoint("RIGHT", tf, "RIGHT", -70, 0)
    bar.label:SetJustifyH("LEFT")
    bar.label:SetWordWrap(false)

    bar.amount = tf:CreateFontString(nil, "OVERLAY")
    bar.amount:SetPoint("RIGHT", tf, "RIGHT", -3, 0)
    bar.amount:SetJustifyH("RIGHT")

    -- 建立時就給字型：沒有字型物件的 FontString 一 SetText 就丟錯，而不是所有
    -- 路徑都會經過 RelayoutBar（展開頁的名次欄就不會）
    Win.SetFont(bar.rank, 11)
    Win.SetFont(bar.label, 11)
    Win.SetFont(bar.amount, 11)

    bar.W = W
    bar.row:Hide()
    return bar
end

-- 文字位移：把建立時的錨點加上玩家設定的偏移重設一次
function Win.ApplyBarTextOffsets(bar)
    local s = ns.DB.Style()
    local tf = bar.textFrame
    local lx, ly = s.leftTextOffsetX or 0, s.leftTextOffsetY or 0
    local rx, ry = s.rightTextOffsetX or 0, s.rightTextOffsetY or 0
    bar.rank:SetPoint("LEFT", tf, "LEFT", 3 + lx, ly)
    bar.amount:SetPoint("RIGHT", tf, "RIGHT", -3 + rx, ry)
    Win.AnchorBarLabel(bar, bar._compactLabel)
end

------------------------------------------------------------
-- 名字的右緣
--
-- 一般清單固定留 70px 給數值。合併檢視的欄只有半寬，而右邊只是幾位數的次數 ——
-- 照樣留 70px 名字會被砍掉一半，所以 compact 時改追**數值的左緣**
-- （展開頁與滑過預覽同一招：數值只錨右緣跟著自己的字長，被截斷的永遠是名字）。
-- SetPoint 同名錨點是覆寫，兩種模式之間來回切不必先清。
-- y 要扣掉數值自己的偏移：錨點是貼在數值身上的，不扣的話名字會跟著右欄上下跑。
------------------------------------------------------------
function Win.AnchorBarLabel(bar, compact)
    local s = ns.DB.Style()
    local ly = s.leftTextOffsetY or 0
    if compact then
        bar.label:SetPoint("RIGHT", bar.amount, "LEFT", -4, ly - (s.rightTextOffsetY or 0))
    else
        bar.label:SetPoint("RIGHT", bar.textFrame, "RIGHT", -70, ly)
    end
end

-- 軌道底色。classFile 可能是秘密 → M.ClassColor 已經擋過，拿不到就用自訂色。
function Win.ApplyBarBg(bar)
    local s = ns.DB.Style()
    local c = s.barBgColor
    local a = c and c.a or 0
    if s.barBgUseClassColor then
        local r, g, b = M.ClassColor(bar._class)
        if r then bar.bg:SetColorTexture(r, g, b, a); return end
    end
    bar.bg:SetColorTexture(c and c.r or 0, c and c.g or 0, c and c.b or 0, a)
end

-- 每列邊框：只有 borderSize > 0 才建 frame（懶建）
function Win.ApplyBarBorder(bar)
    local s = ns.DB.Style()
    local sz = s.barBorderSize or 0
    if sz <= 0 then
        if bar.borderFrame then bar.borderFrame:Hide() end
        return
    end
    if not bar.borderFrame then
        local f = CreateFrame("Frame", nil, bar.row, "BackdropTemplate")
        f:SetAllPoints(bar.row)
        f:SetFrameLevel(bar.row:GetFrameLevel() + 3)
        bar.borderFrame = f
    end
    local c = s.barBorderColor
    bar.borderFrame:SetBackdrop({ edgeFile = M.WHITE8X8, edgeSize = D.Px(sz) })
    bar.borderFrame:SetBackdropBorderColor(c and c.r or 0, c and c.g or 0, c and c.b or 0, c and c.a or 1)
    bar.borderFrame:Show()
end

------------------------------------------------------------
-- 長條樣式：實心填滿 vs 細線
--
-- 細線**不是把填滿條變矮**，而是另外一條 1~4px 的 StatusBar：
--   * 填滿條要留著當圖示與文字的容器 —— 對它 SetAlpha(0) 會連子物件一起隱形，
--     所以改成把它的**材質顏色**設成全透明（SetStatusBarColor 的 a=0）。
--   * 兩條都是 StatusBar，所以「線有多長」由引擎用同一套 min/max/value 算，
--     不必去量填滿條的寬度 —— 那個寬度在秘密值下是量不得的。
--
-- 回傳「這條 bar 實際要餵值與上色的那個 StatusBar」，呼叫端存進 bar._target。
------------------------------------------------------------
local LINE_EDGES = { ["line-bottom"] = "BOTTOM", ["line-top"] = "TOP" }

function Win.ApplyBarStyle(bar, s, texPath)
    local edge = LINE_EDGES[s.barStyle or "fill"]
    bar._lineEdge = edge

    if not edge then
        if bar.line then bar.line:Hide() end
        bar.fill:SetStatusBarTexture(texPath)
        bar.fill:SetAlpha(s.barFillAlpha or 1)
        -- ⚠ 一定要把頂點色救回來：**SetStatusBarTexture 不會清掉 SetStatusBarColor**。
        -- 細線樣式把填滿條的頂點色設成 (0,0,0,0) 當作隱形容器，換回實心時那個
        -- 全透明會原封不動留著 —— 症狀就是「選了實心填滿沒反應，要 /reload 才會出現」
        -- （reload 之後 bar 是全新建的，沒有那個殘留）。設成不透明白，
        -- 真正的顏色隨後由 PaintBar 蓋上去。
        bar.fill:SetStatusBarColor(1, 1, 1, 1)
        return bar.fill
    end

    if not bar.line then
        local ln = CreateFrame("StatusBar", nil, bar.row)
        ln:SetMinMaxValues(0, 1)
        ln:SetValue(0)
        -- 墊在文字層（row+4）之下、邊框（row+3）之上都無所謂，線本來就在列的邊緣
        ln:SetFrameLevel(bar.row:GetFrameLevel() + 2)
        bar.line = ln
    end

    bar.fill:SetStatusBarTexture(M.WHITE8X8)
    bar.fill:SetAlpha(1)
    bar.fill:SetStatusBarColor(0, 0, 0, 0)   -- 退成純容器
    bar.line:SetStatusBarTexture(texPath)
    bar.line:SetAlpha(s.barFillAlpha or 1)
    bar.line:SetHeight(D.Px(s.barLineHeight or 2))
    bar.line:Show()
    return bar.line
end

-- 填滿條與細線的水平錨定（offset = 圖示佔掉的寬度）。兩者都錨在 bar.row 上，
-- 不是「線錨在填滿條上」—— 填滿條的幾何在秘密值下是髒的，不要讓它往下傳染。
function Win.AnchorBarFill(bar, offset)
    bar.fill:ClearAllPoints()
    bar.fill:SetPoint("TOPLEFT", bar.row, "TOPLEFT", offset, 0)
    bar.fill:SetPoint("TOPRIGHT", bar.row, "TOPRIGHT", 0, 0)
    local e = bar._lineEdge
    if bar.line and e then
        bar.line:ClearAllPoints()
        bar.line:SetPoint(e .. "LEFT", bar.row, e .. "LEFT", offset, 0)
        bar.line:SetPoint(e .. "RIGHT", bar.row, e .. "RIGHT", 0, 0)
    end
end

------------------------------------------------------------
-- 標題列按鈕的工具提示要放哪
--
-- 不能用 GameTooltip 的 ANCHOR_TOP：統計視窗常常貼著螢幕頂端，那時候
-- ANCHOR_TOP 沒有空間會自己翻到按鈕**下方** —— 剛好翻進游標底下，
-- 標籤的後半段就被游標的箭頭蓋掉了。
--
-- 關鍵是：**游標圖形是從熱點往「右下」延伸的**，而且大約 32px 見方 ——
-- 比按鈕本身（20px）還寬。所以
--   * 上面放得下 → 放按鈕正上方（游標整個在下方，永遠蓋不到）
--   * 上面放不下 → 提示的**右緣退到按鈕左緣之外**再往下放
--
-- ⚠ 「放按鈕正中央的左下」是不夠的（第一次就是這樣寫的）：熱點可能落在按鈕的
--    左緣，游標往右延伸 32px，剛好把提示右側那幾個字蓋掉 —— 症狀就是
--    「標籤後兩個字看不到」。熱點的 x 最小就是按鈕左緣，所以提示只要整個
--    待在按鈕左緣以左就一定安全。
-- 螢幕邊界由 GameTooltip 自己的 clamp 處理。
------------------------------------------------------------
local TT_GAP = 6

local function AnchorButtonTooltip(btn)
    GameTooltip:SetOwner(btn, "ANCHOR_NONE")
    GameTooltip:ClearAllPoints()
    local top = btn:GetTop()
    local room = top and (UIParent:GetTop() - top) or 0
    if room > 44 then
        GameTooltip:SetPoint("BOTTOM", btn, "TOP", 0, TT_GAP)
    else
        GameTooltip:SetPoint("TOPRIGHT", btn, "BOTTOMLEFT", -2, -TT_GAP)
    end
end

------------------------------------------------------------
-- 狀態標籤的提示：現在看的是哪一段、怎麼換，以及智慧顯示在做什麼。
-- 最後那段是為了「標題自己變了」—— 脫戰幾秒後自動切到總計，玩家沒動任何東西，
-- 滑過來就要看得到為什麼。
------------------------------------------------------------
local function ShowStatusTooltip(W, btn)
    local L = ns.L
    AnchorButtonTooltip(btn)
    GameTooltip:SetText(W._fullStatus or L["Segments"], 1, 1, 1)
    GameTooltip:AddLine(L["Click to switch segments"], 0.7, 0.7, 0.7)
    local note = ns.Windows.SmartDisplayNote(W)
    if note then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(note, 0.7, 0.7, 0.7, true)
    end
    GameTooltip:Show()
end

------------------------------------------------------------
-- 標題列按鈕
------------------------------------------------------------
-- id  這顆按鈕在設定裡的身分（segments / publish / reset / settings / lock），
--     顯示與順序都查它。**是存檔內容**，不要改名。
-- key 貼圖 key。跟 id 多半一樣，但會切換的兩顆不是：鎖頭在 locked/unlocked 之間切、
--     發佈在 publish/publishOff 之間切。
local function MakeHeaderButton(W, id, key, tooltip, onClick)
    local s = ns.DB.Style()
    local btn = CreateFrame("Button", nil, W.header)
    btn:SetSize(s.hdrIconSize or 20, s.hdrIconSize or 20)
    btn:SetFrameLevel(W.header:GetFrameLevel() + 2)

    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints()
    icon:SetTexture(BTN_TEX[key])
    -- 不 SetDesaturated：素材本來就是純白，去色是多一道沒有作用的著色步驟
    icon:SetVertexColor(M.Accent())
    icon:SetAlpha(ICON_ALPHA)
    btn.icon = icon
    btn.id = id
    btn.key = key

    btn:SetScript("OnEnter", function(self)
        self.icon:SetAlpha(ICON_HOVER_ALPHA)
        if ns.W.Menu.IsOpenFor(self) then return end   -- 選單開著時不要再疊工具提示
        AnchorButtonTooltip(self)
        GameTooltip:SetText(tooltip, 1, 1, 1)
        -- 動態補一行：狀態會變的按鈕（發佈）用它講「為什麼現在按不下去」。
        -- 掛成函式而不是字串，提示才是打開的那一刻才求值的。
        local note = self.tooltipNote and self.tooltipNote(self)
        if note then GameTooltip:AddLine(note, 0.7, 0.7, 0.7, true) end
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        self.icon:SetAlpha(ICON_ALPHA)
        GameTooltip:Hide()
    end)
    btn:SetScript("OnClick", function(self)
        GameTooltip:Hide()
        onClick(self)
    end)

    W.hdrButtons[#W.hdrButtons + 1] = btn
    W.hdrButtonById[id] = btn
    return btn
end

-- 這顆按鈕被關掉了沒。三個地方要用同一個判斷（排版、滑過顯示、切換顯示），
-- 所以收斂成一支 —— 之前三處各寫一份，加按鈕時就會漏改。
local function HiddenByOption(btn)
    local cfg = ns.DB.HdrButton(btn.id)
    return not (cfg and cfg.enabled)
end

-- 排序緩衝：Layout 只走設定變動路徑（不在刷新迴圈裡），但沒必要每次配一張新表。
-- 整支是同步的，兩個視窗不會同時用到它。
local _laySeq = {}

local function ByOrder(a, b)
    local oa = ns.DB.HdrButton(a.id).order
    local ob = ns.DB.HdrButton(b.id).order
    if oa ~= ob then return oa < ob end
    return a.id < b.id      -- 同 order 用 id 定生死，排列才是穩定的
end

-- 依 hdrButtons 的 order 排成「由左到右」的序列，再從右緣往左貼
-- （序列最後一顆在最右邊）。回傳實際顯示的顆數，給 FitTitle 算可用寬度。
function Win.LayoutHeaderButtons(W)
    local s = ns.DB.Style()
    local size = s.hdrIconSize or 20

    local seq = _laySeq
    wipe(seq)
    for _, btn in ipairs(W.hdrButtons) do
        if HiddenByOption(btn) then
            btn:Hide()
        else
            seq[#seq + 1] = btn
        end
    end
    table.sort(seq, ByOrder)

    local x = -(BTN_GAP + 1)
    for i = #seq, 1, -1 do
        local btn = seq[i]
        btn:SetSize(size, size)
        btn:ClearAllPoints()
        btn:SetPoint("RIGHT", W.header, "RIGHT", x, 0)
        btn:Show()
        x = x - size - BTN_GAP
    end

    local n = #seq
    W._hdrButtonCount = n
    return n
end

------------------------------------------------------------
-- 「滑過才顯示」的收合：靠輪詢，不能靠 OnLeave
--
-- ⚠ 為什麼不用 OnLeave（原本就是那樣寫的，會卡住）：
--   標題左邊的 typeBtn 是**覆蓋在 header 上的子按鈕，它會搶走滑鼠焦點**。
--   游標從左側標題那一塊進來時 header 根本沒收到 OnEnter，自然也永遠等不到
--   OnLeave —— 圖示就一直掛在那裡。慢慢移動之所以正常，是因為會經過標題與
--   按鈕之間那條裸露的 header，剛好補觸發到；移動快就跳過去了。
--   （症狀：游標明明已經在長條上了，右邊的圖示還在。）
--
--   `header:IsMouseOver()` 是**用矩形判斷**的，不管焦點在哪個子框都算數，
--   所以一次檢查就涵蓋 typeBtn 與所有按鈕。
--
-- 成本：ticker 只在圖示顯示期間存在（＝游標正在標題列上），其餘時間零成本。
------------------------------------------------------------
local function StopHeaderHoverPoll(W)
    if W._hdrHoverTicker then
        W._hdrHoverTicker:Cancel()
        W._hdrHoverTicker = nil
    end
end
Win.StopHeaderHoverPoll = StopHeaderHoverPoll

local SetHeaderIconsShown   -- 下面兩支互相呼叫，先宣告

local function StartHeaderHoverPoll(W)
    if W._hdrHoverTicker then return end
    W._hdrHoverTicker = C_Timer.NewTicker(0.1, function()
        local h = W.header
        if not h or not h:IsShown() or not h:IsMouseOver() then
            StopHeaderHoverPoll(W)
            SetHeaderIconsShown(W, false)
        end
    end)
end

function SetHeaderIconsShown(W, shown)
    local s = ns.DB.Style()
    if not s.hdrMouseoverIcons then return end
    if shown then StartHeaderHoverPoll(W) else StopHeaderHoverPoll(W) end
    if W._hdrIconsShown == shown then return end
    W._hdrIconsShown = shown
    for _, btn in ipairs(W.hdrButtons) do
        if shown and not HiddenByOption(btn) then btn:Show()
        else btn:Hide() end
    end
    Win.FitTitle(W)
end

-- 選項：圖示藏到滑過標題列才出現
function Win.ApplyHeaderHoverIcons(W)
    local s = ns.DB.Style()
    StopHeaderHoverPoll(W)   -- 換模式時把上一輪的輪詢收掉
    if not s.hdrMouseoverIcons then
        W._hdrIconsShown = true
        for _, btn in ipairs(W.hdrButtons) do
            if not HiddenByOption(btn) then btn:Show() end
        end
        Win.FitTitle(W)
        return
    end
    W._hdrIconsShown = false
    for _, btn in ipairs(W.hdrButtons) do btn:Hide() end
    Win.FitTitle(W)
end

------------------------------------------------------------
-- 標題列的文字排版：類型名 ＋ 狀態標籤（左），計時器（右）
--
--   ▮ 傷害輸出  總計 ▾                         1:23  [圖示…]
--
-- 以前是「總計 傷害輸出」／「傷害輸出」／「分段 - 傷害輸出」三種格式，而且「目前」
-- 沒有字 —— 要靠「有沒有前綴」判斷狀態，前綴又跟類型名同色同字重，讀起來像一個名字。
-- 現在狀態一律寫出來、放在類型名**後面**（類型名在每個視窗都對齊）、調暗一階。
--
-- 放不下時的截斷順序：先砍狀態（首領名可以很長），但至少留約三個字寬 ——
-- 「目前／總計」一定完整；還是放不下才砍類型名。
------------------------------------------------------------
-- 放不下就截斷加省略號
local function Truncate(fs, full, avail)
    fs:SetText(full)
    if avail < 1 then avail = 1 end
    if fs:GetStringWidth() <= avail then return end
    local str = full
    while #str > 1 do
        -- 一次砍一個「字元」不是一個 byte：在地化標題是 UTF-8，
        -- 從碼點中間切開會變成亂碼方塊
        local i = #str
        while i > 1 do
            local b = string.byte(str, i)
            if b < 0x80 or b >= 0xC0 then break end
            i = i - 1
        end
        str = string.sub(str, 1, i - 1)
        fs:SetText(str .. "...")
        if fs:GetStringWidth() <= avail then break end
    end
end

function Win.FitTitle(W)
    local fs, st = W.titleText, W.segText
    local full = W._fullTitle
    if not fs or not st or not full then return end
    local status = W._fullStatus or ""

    local s = ns.DB.Style()
    local iconSz = s.hdrIconSize or 20
    -- 藏起來的圖示不佔空間（不要對著一個不存在的空隙截字）
    local n = W._hdrIconsShown and (W._hdrButtonCount or 0) or 0
    local headerW = W.frame:GetWidth() or (W.wdb.width or 300)

    -- 右側：圖示佔的寬度要跟 LayoutHeaderButtons 同一套算法（右緣留 BTN_GAP+1、
    -- 每顆 size + BTN_GAP），不然計時器會壓到圖示或留一段空。
    -- 計時器貼在最左那顆圖示左邊；圖示藏著就貼右緣。
    local iconsW = (n > 0) and (1 + n * (iconSz + BTN_GAP)) or 0
    local timerRight = (n > 0) and (iconsW + TIMER_GAP) or TIMER_PAD
    local timer = W.timerText
    timer:ClearAllPoints()
    timer:SetPoint("RIGHT", W.header, "RIGHT", -timerRight, s.hdrTextOffY or 0)
    local rightUsed = iconsW
    if timer:IsShown() and W._timerHasText then
        -- 量「00:00」不量現在的字：秒數一跳寬度就變，而這支不在每秒的迴圈裡
        local cur = timer:GetText()
        timer:SetText("00:00")
        rightUsed = timerRight + timer:GetStringWidth() + TIMER_GAP
        timer:SetText(cur)
    end

    -- 左邊要扣掉類型圖示那一塊（TYPE_PAD + 圖示 + TYPE_GAP）
    local leftUsed = TYPE_PAD + iconSz + TYPE_GAP + (s.hdrTextOffX or 0)
    local avail = headerW - rightUsed - leftUsed - 8
    local fixed = STATUS_GAP + (W.segArrow:GetWidth() or 0) + 1

    fs:SetText(full)
    st:SetText(status)
    local typeW, statusW = fs:GetStringWidth(), st:GetStringWidth()
    if typeW + fixed + statusW <= avail then return end

    local keep = math.min(statusW, (s.hdrFontSize or 11) * 3)
    local room = avail - typeW - fixed
    if room >= keep then
        Truncate(st, status, room)
    else
        Truncate(st, status, keep)
        Truncate(fs, full, avail - fixed - st:GetStringWidth())
    end
end

------------------------------------------------------------
-- 狀態標籤的文字：目前／總計／歷史分段的名字（通常是首領名）
-- 右鍵選單「分段」那一項的讀數也用這支，兩邊的字一定一致。
------------------------------------------------------------
function Win.SegmentLabel(W)
    local L = ns.L
    if not W.curSessionID then
        return (W.curSession == D.S.Overall) and L["Overall"] or L["Current"]
    end
    local list = D.GetAvailableSessions()
    if list then
        for i, sess in ipairs(list) do
            if sess.sessionID == W.curSessionID then
                -- 分段名稱可能是秘密字串：不能串接、也不能量寬度截斷，秘密就退回編號
                local label = sess.name
                if label and not D.IsSecret(label) and label ~= "" then return label end
                return L["Segment"] .. " " .. i
            end
        end
    end
    return L["Segment"]
end

function Win.UpdateTitle(W)
    W._fullTitle = D.TYPE_NAMES[W.curDMType] or ns.L["Damage Done"]
    W._fullStatus = Win.SegmentLabel(W)
    Win.FitTitle(W)
end

------------------------------------------------------------
-- 狀態標籤上色：標題的顏色往標題列底色混，k = 1 就是標題本身的亮度。
-- 混色不疊 alpha：標題列底色玩家可以調成半透明，疊 alpha 的觀感會跟著背景飄。
------------------------------------------------------------
local function TitleColor(s)
    if s.hdrTextUseClassColor then return M.Accent() end
    local c = s.hdrTextColor
    return c and c.r or 1, c and c.g or 1, c and c.b or 1
end

function Win.ApplyStatusColor(W, k)
    if not W.segText then return end
    local s = ns.DB.Style()
    local r, g, b = TitleColor(s)
    local hb = s.hdrBgColor
    local br, bg, bb = hb and hb.r or 0, hb and hb.g or 0, hb and hb.b or 0
    local rest = 1 - k
    r, g, b = r * k + br * rest, g * k + bg * rest, b * k + bb * rest
    W.segText:SetTextColor(r, g, b)
    W.segArrow:SetVertexColor(r, g, b)
end

-- 智慧顯示替玩家切了分段：狀態標籤亮一下再暗回去，讓「標題自己變了」有個交代。
-- 只在戰鬥邊界的自動切換叫（見 Manager 的 SmartApply），玩家自己切的不閃。
function Win.PulseStatus(W)
    local ag = W.segPulse
    if not ag or not W.frame or not W.frame:IsShown() then return end
    ag:Stop()
    ag:Play()
end

-- 用「顯示的整數秒」做備忘：0.5 秒的 ticker 敲進來時，同一秒內的重複呼叫是免費的
function Win.UpdateTimerText(W)
    if not W.timerText or not W.timerText:IsShown() then return end

    local dur
    if W.curSessionID then
        -- 歷史分段的時長是**定值**，而 D.GetSessionDuration 要抓整份分段清單再線性
        -- 搜尋 —— 每 tick 做一次是白做的。切分段時清成 nil 重解一次。
        -- ⚠ 只快取真的解出來的數字：剛切過去時分段可能還沒進清單，
        --   存 false 會讓那一格永遠是空的。
        if W._segDur == nil then
            local d = D.GetSessionDuration(nil, W.curSessionID)
            if type(d) == "number" then W._segDur = d end
            dur = d
        else
            dur = W._segDur
        end
    elseif W.curSession == D.S.Current then
        -- 跟長條讀的是同一個分段，所以伺服器換分段時兩邊一起歸零
        dur = ns.Combat.CurrentDuration()
    else
        dur = D.GetSessionDuration(D.S.Overall, nil)
    end

    local isOverall = (not W.curSessionID and W.curSession == D.S.Overall)
    -- 合併檢視兩欄都要算：左欄沒人打斷、右欄有人驅散，這一場照樣是有資料的
    local rows = (W.visibleCount or 0)
    if W._splitOn and W.split then rows = rows + (W.split.visibleCount or 0) end
    local sec = -1
    if not isOverall and dur and not D.IsSecret(dur) and type(dur) == "number"
        and dur > 0 and rows > 0 then
        sec = math.floor(dur)
    end
    if W._timerSec == sec then return end
    W._timerSec = sec
    -- 獨立放在右側，不再用括號黏著標題
    W.timerText:SetText(sec >= 0 and D.FormatTimer(dur) or "")
    -- 有字／沒字切換時，左邊的標題可用寬度跟著變，要重排一次。
    -- 另記一個布林而不是看 _timerSec：_timerSec 會被分段更新清成 nil，
    -- 拿它判斷的話戰鬥中每次有人死就重排一次標題。
    local has = sec >= 0
    if has ~= W._timerHasText then
        W._timerHasText = has
        Win.FitTitle(W)
    end
end

------------------------------------------------------------
-- 切換統計類型／分段
------------------------------------------------------------
function Win.SetDMType(W, dmType)
    W.curDMType = dmType
    W.wdb.curDMType = dmType
    W.curSessionID = nil
    W._barCacheKey = nil
    W._barSources = nil
    W._cachedTargets = nil
    W._segDur = nil
    ns.Breakdown.Close(W)
    ns.Home.Hide(W)
    Win.UpdateTitle(W)
    W.Refresh()
end

-- sessionID 給了就看那個歷史分段，否則看 sessionType（本場／總計）。
-- 勾了「分段連動」的視窗會一起切。
function Win.SetSegment(W, sessionType, sessionID)
    local function apply(w)
        w.curSession = sessionType or w.curSession
        w.curSessionID = sessionID
        if sessionType then w.wdb.curSession = sessionType end
        w._barCacheKey = nil
        w._timerSec = nil
        w._segDur = nil
        w._cachedTargets = nil
        ns.Breakdown.Close(w)
        Win.UpdateTitle(w)
        w.Refresh()
    end
    apply(W)
    if W.wdb.syncSegments then
        ns.Windows.ForEach(function(other)
            if other ~= W and other.wdb.syncSegments then apply(other) end
        end)
    end
end

------------------------------------------------------------
-- 顯示條件
------------------------------------------------------------
function Win.UpdateVisibility(W)
    if not W.frame then return end

    -- 藏著的期間 W.Refresh 是直接早退的，所以「重新顯示」這條邊緣要自己補畫一次，
    -- 否則會停在藏起來那一刻的畫面直到下一個 tick（脫戰時根本沒有下一個 tick）。
    local was = W.frame:IsShown()
    local function Set(shown)
        W.frame:SetShown(shown)
        if shown and not was then
            W._barCacheKey = nil
            W.Refresh()
        end
    end

    -- 編輯模式與設定視窗開著時一律顯示，否則玩家看不到自己在調什麼
    if ns.Move.IsEditing() or ns._optionsOpen then
        Set(true)
        return
    end

    local wdb = W.wdb
    local _, iType = IsInInstance()

    if wdb.hideInDungeon and iType == "party" then Set(false); return end
    if wdb.hideInRaid and iType == "raid" then Set(false); return end
    if wdb.hideInPvP and (iType == "pvp" or iType == "arena") then Set(false); return end
    -- 探究不看 instanceType（它是 scenario，跟其他場景混在一起），走專用偵測
    if wdb.hideInDelve and D.IsInDelve() then Set(false); return end
    if wdb.hideOutOfInstance and (iType == "none" or iType == nil) then Set(false); return end

    local vis = wdb.visibility or "always"
    if vis == "combat" then
        Set(ns.Combat.IsInCombat() or InCombatLockdown())
    elseif vis == "instance" then
        Set(iType == "party" or iType == "raid")
    elseif vis == "group" then
        Set((GetNumGroupMembers() or 0) > 0)
    else
        Set(true)
    end
end

------------------------------------------------------------
-- 建立
------------------------------------------------------------
------------------------------------------------------------
-- 反轉顯示
--
-- 玩家要的是「標題列在最下面、第一名在最底部、整個上下顛倒」。版面上這就只是
-- **垂直翻面**一件事，所以不要在各處寫 if —— 全部收斂成一組錨點常數，呼叫端
-- 寫 O.topL 而不是字面的 "TOPLEFT"，翻面時語意自動跟著走：
--
--   O.topL/topR  「標題列那一端」的左右角      O.botL/botR 「遠離標題列」的那一端
--   O.v          垂直位移的正負號（正常 1、反轉 -1）
--
-- ⚠ 兩張表是模組層級常數、不是每次現配 —— PaintBar 是每 tick 每列都會過的路。
------------------------------------------------------------
local ORIENT_NORMAL = {
    v = 1,
    topL = "TOPLEFT",    topR = "TOPRIGHT",    top = "TOP",
    botL = "BOTTOMLEFT", botR = "BOTTOMRIGHT", bot = "BOTTOM",
}
local ORIENT_FLIP = {
    v = -1,
    topL = "BOTTOMLEFT", topR = "BOTTOMRIGHT", top = "BOTTOM",
    botL = "TOPLEFT",    botR = "TOPRIGHT",    bot = "TOP",
}

function Win.Orient(W)
    return W.wdb.reverse and ORIENT_FLIP or ORIENT_NORMAL
end

------------------------------------------------------------
-- 一欄清單（pane）
--
-- 捲動區＋長條池＋釘住自己那列，再加一個不可見的 area 框定「這一欄佔哪一塊」。
-- 清單裡的錨點一律貼 area，不直接貼標題列／視窗 —— 於是切成左右兩欄就只是
-- 改 area 的兩個錨點，捲動區與釘住的列（不論有沒有正在釘）都自動跟著走。
--
-- 主欄就是 W 本身：這些欄位（W.viewport、W.rowPool…）早就長在 W 上、外部也在讀，
-- 所以不另外包一層。合併檢視的右欄是 W.split，欄位名稱一模一樣 ——
-- Rows 那邊一律寫 pane.xxx，兩欄走同一套程式碼。
------------------------------------------------------------
local SPLIT_GAP = 3   -- 兩欄與中間分隔線之間各留幾像素

function Win.ForEachPane(W, fn)
    fn(W)
    if W.split then fn(W.split) end
end

function Win.ScrollPane(W, pane, delta)
    local cfg = ns.DB.Style()
    local step = D.Px(cfg.barHeight or 18) + D.Px(cfg.barSpacing or 2)
    -- 邏輯捲動：0 永遠是第一名那端，所以滾輪的方向在正反兩種排列下一致
    ns.Rows.SetScroll(W, ns.Rows.GetScroll(W, pane) - delta * step, pane)
    -- 捲動會換可視範圍，要重畫（RefreshUI 只填可視列）
    if W._lastSession or W._lastSession2 then
        ns.Rows.Render(W, W._lastSession, W._lastSession2)
    end
end

local function BuildPane(W, pane)
    local frame = W.frame
    pane.rowPool = {}

    local area = CreateFrame("Frame", nil, frame)
    area:SetFrameLevel(frame:GetFrameLevel() + 1)
    pane.area = area
    -- 沒資料的欄就是空白，不放「沒有資料」之類的提示（使用者要求，跟一般清單一致）

    local viewport = CreateFrame("ScrollFrame", nil, frame)
    viewport:SetFrameLevel(frame:GetFrameLevel() + 1)
    pane.viewport = viewport

    local content = CreateFrame("Frame", nil, viewport)
    content:SetSize(1, 1)
    viewport:SetScrollChild(content)
    viewport:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)
    pane.content = content

    -- 沒有捲軸貼圖，只吃滾輪：40 列的清單畫一條捲軸只是佔寬度。兩欄各捲各的。
    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", function(_, delta) Win.ScrollPane(W, pane, delta) end)

    local function HookBar(bar)
        bar.row:SetScript("OnClick", function(_, button)
            if button == "RightButton" then
                ns.Windows.ShowContextMenu(W)
            else
                ns.Breakdown.OpenFromBar(W, bar)
            end
        end)
        bar.row:SetScript("OnEnter", function() ns.Tooltip.OnBarEnter(bar) end)
        bar.row:SetScript("OnLeave", function() ns.Tooltip.OnBarLeave(bar) end)
    end

    for i = 1, BAR_POOL_SIZE do
        local bar = Win.MakeBar(content, W)
        HookBar(bar)
        pane.rowPool[i] = bar
    end

    -- 釘住自己那列：獨立於捲動區之外，所以它不會跟著捲走
    local sticky = Win.MakeBar(frame, W)
    sticky.row:SetFrameLevel(frame:GetFrameLevel() + 10)
    sticky.fill:SetFrameLevel(sticky.row:GetFrameLevel() + 1)
    sticky.textFrame:SetFrameLevel(sticky.row:GetFrameLevel() + 4)
    HookBar(sticky)
    pane.stickyBar = sticky

    pane.stickySep = frame:CreateTexture(nil, "OVERLAY")
    pane.stickySep:SetColorTexture(1, 1, 1, 0.25)
    pane.stickySep:Hide()
    return pane
end

-- 右欄是懶建的：從來沒選過合併檢視的視窗不必多養 41 條長條
function Win.EnsureSplitPane(W)
    if W.split then return W.split end
    local P = BuildPane(W, {})
    W.split = P

    -- 畫在視窗本體的 BORDER 層：在背景之上、長條（子框）之下
    local div = W.frame:CreateTexture(nil, "BORDER")
    div:SetColorTexture(1, 1, 1, 0.04)   -- 只是分欄的暗示，不要搶過長條（使用者要求再淡）
    div:Hide()
    W.splitDivider = div

    -- 建立當下的 ApplyStyle 早就跑過了，新的這一欄自己補套一次
    local s = ns.DB.Style()
    local texPath = M.BarTexture(s.barTexture)
    for _, bar in ipairs(P.rowPool) do Win.StyleBar(bar, s, texPath) end
    Win.StyleBar(P.stickyBar, s, texPath)
    Win.AnchorPanes(W)
    return P
end

------------------------------------------------------------
-- 兩欄的位置
--
-- 一般：主欄的 area ＝ 標題列下緣到視窗另一端，跟以前捲動區的錨點一模一樣。
-- 合併：以視窗中線切開，各退 SPLIT_GAP，中間一條 1px 分隔線。
-- 「中線」直接用標題列／視窗的 TOP、BOTTOM 錨點，不去量寬度自己除二。
------------------------------------------------------------
function Win.AnchorPanes(W)
    local O = Win.Orient(W)
    local frame, header = W.frame, W.header
    local split = W._splitOn
    local gap = D.Px(SPLIT_GAP)

    W.area:ClearAllPoints()
    W.area:SetPoint(O.topL, header, O.botL, 0, 0)
    if split then
        W.area:SetPoint(O.botR, frame, O.bot, -gap, 0)
    else
        W.area:SetPoint(O.botR, frame, O.botR, 0, 0)
    end

    local P = W.split
    if P then
        P.area:ClearAllPoints()
        P.area:SetPoint(O.topL, header, O.bot, gap, 0)
        P.area:SetPoint(O.botR, frame, O.botR, 0, 0)

        local div = W.splitDivider
        div:ClearAllPoints()
        div:SetPoint(O.top, header, O.bot, 0, 0)
        div:SetPoint(O.bot, frame, O.bot, 0, 0)
        div:SetWidth(D.Px(1))
    end

    -- 釘住自己那列的時候捲動區的錨點屬於那段邏輯（Rows.UpdateSticky），別在這裡搶。
    -- 那段也是貼 area 的，所以欄位改了它照樣跟著走。
    Win.ForEachPane(W, function(pane)
        if pane.stickyPinned then return end
        pane.viewport:ClearAllPoints()
        pane.viewport:SetPoint(O.topL, pane.area, O.topL, 0, 0)
        pane.viewport:SetPoint(O.botR, pane.area, O.botR, 0, 0)
    end)
end

-- 首頁蓋上來時把清單區整個藏起來、關掉時放回來。
-- 釘住的列不在這裡放回：要不要釘得看資料，交給接著的那次繪製決定。
function Win.SetListShown(W, shown)
    local split = (shown and W._splitOn) and true or false
    W.viewport:SetShown(shown)
    if W.split then W.split.viewport:SetShown(split) end
    if W.splitDivider then W.splitDivider:SetShown(split) end
    if not shown then
        Win.ForEachPane(W, function(pane)
            pane.stickyBar.row:Hide()
            pane.stickySep:Hide()
        end)
    end
end

------------------------------------------------------------
-- 把方向套到「跟著翻面」的那幾個框
--
-- 這些點在建立時與每次 ApplyStyle 都要重貼：SetPoint 是**逐個錨點覆寫**，
-- 不先 ClearAllPoints 的話舊方向那一組會留著，兩組打架的結果是框被拉長。
------------------------------------------------------------
function Win.ApplyOrientation(W)
    local s = ns.DB.Style()
    local O = Win.Orient(W)
    local frame, header = W.frame, W.header
    local hdrH = D.Px(s.hdrHeight or 22)

    frame.bg:ClearAllPoints()
    frame.bg:SetPoint(O.topL, frame, O.topL, 0, -hdrH * O.v)
    frame.bg:SetPoint(O.botR, frame, O.botR, 0, 0)

    header:ClearAllPoints()
    header:SetPoint(O.topL, frame, O.topL, 0, 0)
    header:SetPoint(O.topR, frame, O.topR, 0, 0)

    header.bottomBorder:ClearAllPoints()
    header.bottomBorder:SetPoint(O.botL, header, O.botL, 0, 0)
    header.bottomBorder:SetPoint(O.botR, header, O.botR, 0, 0)

    Win.AnchorPanes(W)

    -- 首頁與展開頁是**建一次就重用**的，翻面之後不重貼會留在舊方向。
    -- 兩者都是懶初始化，各自判存在 —— 不要放進一張表用 ipairs 走，
    -- 前面那個是 nil 的話 ipairs 當場就停，後面那個會被靜默跳過。
    local function AnchorPage(page)
        if not page then return end
        page:ClearAllPoints()
        page:SetPoint(O.topL, header, O.botL, 0, 0)
        page:SetPoint(O.botR, frame, O.botR, 0, 0)
    end
    AnchorPage(W.homeFrame)
    AnchorPage(W.srcFrame)

    if ns.Move and ns.Move.ApplyOrientation then ns.Move.ApplyOrientation(W) end
end

function Win.Create(idx)
    local W = {}
    local wdb = ns.DB.Win(idx)
    local s = ns.DB.Style()

    W.idx = idx
    W.wdb = wdb
    W.curDMType    = wdb.curDMType or D.T.DamageDone
    W.curSession   = wdb.curSession or D.S.Current
    W.curSessionID = nil
    W.visibleCount = 0
    W.scrollMax    = 0
    W.rowPool      = {}
    W.hdrButtons   = {}      -- 建立順序（跟畫面上的排列無關）
    W.hdrButtonById = {}     -- id → 按鈕，狀態更新用
    W.sourceOpen   = false

    local hdrH = D.Px(s.hdrHeight or 22)

    ------------------------------------------------------------
    -- 主容器
    ------------------------------------------------------------
    local frame = CreateFrame("Frame", "MiliUI_DamageMeters_Window" .. idx, UIParent)
    frame:SetSize(wdb.width or 300, wdb.height or 200)
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(true)
    frame:SetUserPlaced(false)
    W.frame = frame

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")

    ------------------------------------------------------------
    -- 標題列
    ------------------------------------------------------------
    -- Button 而不是 Frame：右鍵選單走 OnClick，那是 Button 才有的腳本
    local header = CreateFrame("Button", nil, frame)
    header:SetHeight(hdrH)
    header:SetFrameLevel(frame:GetFrameLevel() + 20)
    header:EnableMouse(true)
    W.header = header

    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()

    -- 「標題列與清單之間」那條分隔線。反轉時它會跑到標題列上緣 —— 名字留著
    -- （設定頁與樣式套用都在用），語意是「面向清單的那一邊」。
    header.bottomBorder = header:CreateTexture(nil, "OVERLAY", nil, 7)

    ------------------------------------------------------------
    -- 左側「統計類型」區塊：圖示 ＋ 標題，整塊都是切換按鈕
    --
    -- 這一顆刻意**不放在右邊那組**：右邊是「對這個視窗做什麼」（分段、重置、
    -- 選單、鎖定），這一顆是「這個視窗在看什麼」—— 不同類的東西不該混在一起。
    -- 放在標題左邊，圖示與標題一起讀成「類型：傷害輸出」，而且整塊可點
    -- ＝ 標準的選擇器語彙（點標籤本身就會展開，不必去找那顆小圖示）。
    ------------------------------------------------------------
    local typeBtn = CreateFrame("Button", nil, header)
    typeBtn:SetFrameLevel(header:GetFrameLevel() + 2)
    typeBtn:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    typeBtn:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    W.typeBtn = typeBtn

    typeBtn.hl = typeBtn:CreateTexture(nil, "BACKGROUND")
    typeBtn.hl:SetAllPoints()
    typeBtn.hl:SetColorTexture(M.Accent())
    typeBtn.hl:SetAlpha(0.12)
    typeBtn.hl:Hide()

    W.typeIcon = typeBtn:CreateTexture(nil, "ARTWORK")
    W.typeIcon:SetTexture(BTN_TEX.meters)

    W.titleText = header:CreateFontString(nil, "OVERLAY")
    W.titleText:SetPoint("LEFT", header, "LEFT", 6, 0)

    ------------------------------------------------------------
    -- 狀態標籤（目前／總計／首領名）＋ 下拉箭頭：點一下開分段選單
    --
    -- 標題列右側的分段鈕預設是「滑過才出現」，等於看不到；狀態就寫在標題旁邊，
    -- 讓它本身當入口是最直覺的 —— 「點你看到的那個字就能換」。
    -- 錨點與大小在 ApplyStyle 裡設（跟著字級走）。
    ------------------------------------------------------------
    W.segText = header:CreateFontString(nil, "OVERLAY")
    W.segText:SetJustifyH("LEFT")
    W.segText:SetWordWrap(false)
    Win.SetFont(W.segText, s.hdrFontSize or 11)   -- 先給字型再 SetText

    -- 箭頭跟設定頁下拉選單同一張圖（Widgets.lua 的 CreateDropdown），選擇器長得一樣
    W.segArrow = header:CreateTexture(nil, "OVERLAY")
    W.segArrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    W.segArrow:SetRotation(math.rad(-90))
    W.segArrow:SetDesaturated(true)

    local segBtn = CreateFrame("Button", nil, header)
    segBtn:SetFrameLevel(header:GetFrameLevel() + 2)
    W.segBtn = segBtn

    segBtn.hl = segBtn:CreateTexture(nil, "BACKGROUND")
    segBtn.hl:SetAllPoints()
    segBtn.hl:SetColorTexture(M.Accent())
    segBtn.hl:SetAlpha(0.12)
    segBtn.hl:Hide()

    -- 亮一下再暗回去：純 Animation 只拿來當計時器，每幀自己算混色係數。
    -- 只在播放期間有 OnUpdate，平時零成本。
    local pulse = segBtn:CreateAnimationGroup()
    local pulseAnim = pulse:CreateAnimation("Animation")
    pulseAnim:SetDuration(PULSE_TIME)
    local function RestStatusColor()
        Win.ApplyStatusColor(W, W._segHover and STATUS_HOVER_K or STATUS_K)
    end
    pulseAnim:SetScript("OnUpdate", function(self)
        local p = self:GetProgress() or 1
        -- 前 1/4 亮起來、後 3/4 慢慢暗回去
        local up = (p < 0.25) and (p / 0.25) or (1 - (p - 0.25) / 0.75)
        local base = W._segHover and STATUS_HOVER_K or STATUS_K
        Win.ApplyStatusColor(W, base + (1 - base) * up)
    end)
    pulse:SetScript("OnFinished", RestStatusColor)
    pulse:SetScript("OnStop", RestStatusColor)
    W.segPulse = pulse

    W.timerText = header:CreateFontString(nil, "OVERLAY")
    W.timerText:SetJustifyH("RIGHT")
    W.timerText:SetTextColor(1, 1, 1, 0.7)
    Win.SetFont(W.timerText, s.hdrFontSize or 11)
    if wdb.hideTimer then W.timerText:Hide() end

    -- 邊框畫在獨立的覆蓋層上：這樣「邊框要不要含標題列」只是換個錨點，
    -- 不用動到版面
    local borderTarget = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    borderTarget:EnableMouse(false)
    borderTarget:SetAllPoints(frame)
    -- 墊在首頁(+25)、展開頁(+30)之上，否則開了那兩頁邊框會被蓋掉
    borderTarget:SetFrameLevel(frame:GetFrameLevel() + 50)
    W.borderTarget = borderTarget

    ------------------------------------------------------------
    -- 主欄：捲動區＋長條池＋釘住自己那列（見 BuildPane）
    ------------------------------------------------------------
    BuildPane(W, W)

    -- 視窗層收到的滾輪（游標在釘住的列、或兩欄之間的縫上）：捲游標所在的那一欄
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        local P = W.split
        local pane = (W._splitOn and P and P.area:IsMouseOver()) and P or W
        Win.ScrollPane(W, pane, delta)
    end)

    ------------------------------------------------------------
    -- 標題列按鈕
    --
    -- 建立順序不決定畫面上的排列 —— 那是 style.hdrButtons[id].order 的事
    -- （見 Win.LayoutHeaderButtons）。這裡只負責把五顆都建出來。
    ------------------------------------------------------------
    local L = ns.L
    W.lockBtn = MakeHeaderButton(W, "lock", wdb.locked and "locked" or "unlocked",
        L["Lock window"], function()
            -- 讀 W.wdb 而不是 wdb 這個區域變數：視窗池會在換設定時重綁 W.wdb，
            -- closure 抓住舊表的話按鈕就開始改一張沒人看的設定
            W.wdb.locked = not W.wdb.locked
            Win.UpdateLockIcon(W)
        end)
    MakeHeaderButton(W, "settings", "settings", L["Window menu"], function(btn)
        ns.Windows.ShowContextMenu(W, btn)
    end)
    MakeHeaderButton(W, "reset", "reset", L["Reset data"], function()
        ns.Combat.ResetData()
    end)
    MakeHeaderButton(W, "segments", "segments", L["Segments"], function(btn)
        ns.Windows.ShowSegmentMenu(W, btn)
    end)
    -- ns.Publish 在 TOC 裡排在這支後面，但這兩支都是**點擊／滑過當下**才解的，
    -- 不是檔案層的引用，所以沒有載入順序問題
    local pubBtn = MakeHeaderButton(W, "publish", "publish", L["Publish"], function(btn)
        ns.Publish.OnButtonClick(W, btn)
    end)
    pubBtn.tooltipNote = function()
        return ns.Publish and ns.Publish.BlockedReason()
    end
    ------------------------------------------------------------
    -- 左側區塊的行為：左鍵切類型、右鍵開選單，而且**還是拖得動視窗**
    --
    -- 標題是最自然的拖曳把手，蓋一顆按鈕上去不能把拖曳吃掉。做法是把
    -- 按下／放開轉發給拖曳邏輯，放開時問它「剛剛有沒有真的拖過」——
    -- 沒有才當成點一下（見 Move.lua 的 DRAG_SLOP）。
    ------------------------------------------------------------
    typeBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    typeBtn:SetScript("OnEnter", function(self)
        self.hl:Show()
        W.typeIcon:SetAlpha(ICON_HOVER_ALPHA)
        -- 子按鈕會擋掉 header 的 OnEnter，右側那組「滑過才出現」的圖示得自己叫醒。
        -- 收合不用管：輪詢會處理（而且正是因為這顆按鈕會搶焦點，收合才不能靠事件）
        SetHeaderIconsShown(W, true)
    end)
    typeBtn:SetScript("OnLeave", function(self)
        self.hl:Hide()
        W.typeIcon:SetAlpha(ICON_ALPHA)
    end)
    typeBtn:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        ns.Move.BeginHeaderDrag(W)
    end)
    typeBtn:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            ns.Windows.ShowContextMenu(W)
            return
        end
        if button ~= "LeftButton" then return end
        if not ns.Move.EndHeaderDrag(W) then ns.Home.Toggle(W) end
    end)

    ------------------------------------------------------------
    -- 狀態標籤：左鍵開分段選單、右鍵開視窗選單，一樣拖得動視窗（同上面的類型區塊）
    ------------------------------------------------------------
    segBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    segBtn:SetScript("OnEnter", function(self)
        self.hl:Show()
        W._segHover = true
        if not W.segPulse:IsPlaying() then Win.ApplyStatusColor(W, STATUS_HOVER_K) end
        SetHeaderIconsShown(W, true)
        if ns.W.Menu.IsOpenFor(self) then return end   -- 選單開著時不要再疊提示
        ShowStatusTooltip(W, self)
    end)
    segBtn:SetScript("OnLeave", function(self)
        self.hl:Hide()
        W._segHover = false
        if not W.segPulse:IsPlaying() then Win.ApplyStatusColor(W, STATUS_K) end
        GameTooltip:Hide()
    end)
    segBtn:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        ns.Move.BeginHeaderDrag(W)
    end)
    segBtn:SetScript("OnMouseUp", function(self, button)
        if button == "RightButton" then
            GameTooltip:Hide()
            ns.Windows.ShowContextMenu(W)
            return
        end
        if button ~= "LeftButton" then return end
        if not ns.Move.EndHeaderDrag(W) then
            GameTooltip:Hide()
            ns.Windows.ShowSegmentMenu(W, self)
        end
    end)

    -- 只需要 OnEnter：收合交給輪詢（見 SetHeaderIconsShown 上方的說明）
    header:SetScript("OnEnter", function() SetHeaderIconsShown(W, true) end)

    ------------------------------------------------------------
    -- 右鍵：整個視窗背景都能開選單
    ------------------------------------------------------------
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:SetScript("OnClick", function(_, button)
        if button == "RightButton" then ns.Windows.ShowContextMenu(W) end
    end)
    -- 長條下方的空白處：長條自己會處理右鍵，這條負責沒有長條的那一片
    frame:EnableMouse(true)
    frame:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then ns.Windows.ShowContextMenu(W) end
    end)

    ------------------------------------------------------------
    -- 每視窗的方法（薄殼，實作在各模組）
    ------------------------------------------------------------
    W.Refresh = function()
        if not W.frame then return end
        -- 藏起來的視窗不必付這筆（一次 API ＋ 一輪繪製）。顯示條件把它藏起來之後，
        -- ticker 照樣每秒替它跑完整趟是純浪費。
        -- ⚠ 由隱藏轉顯示時 Win.UpdateVisibility 會作廢版面快取並補畫一次，
        --   所以不會看到「藏起來那一刻」的舊資料。
        if not W.frame:IsShown() then return end
        -- 合併檢視：左欄問左邊那種、右欄另外問一次
        local left, right = D.SplitTypes(W.curDMType)
        -- API 呼叫的耗時要量：偶爾會有尖峰（歷史分段、大團隊），
        -- 尖峰那一幀就把繪製推到下一幀，不要讓兩個尖峰疊在同一幀
        local t0 = debugprofilestop()
        local session = D.GetSession(W.curSession, W.curSessionID, left or W.curDMType)
        local session2 = right and D.GetSession(W.curSession, W.curSessionID, right) or nil
        local cost = debugprofilestop() - t0
        if cost > 1.5 then
            C_Timer.After(0, function() ns.Rows.Render(W, session, session2) end)
        else
            ns.Rows.Render(W, session, session2)
        end
    end
    W.UpdateTimerText = function() Win.UpdateTimerText(W) end
    W.UpdateVisibility = function() Win.UpdateVisibility(W) end
    W.ApplyStyle = function() Win.ApplyStyle(W) end

    ------------------------------------------------------------
    -- 收尾
    ------------------------------------------------------------
    ns.Move.Setup(W)
    Win.ApplyStyle(W)
    Win.UpdateTitle(W)
    Win.UpdateLockIcon(W)
    ns.Move.ApplyPosition(W)
    Win.UpdateVisibility(W)

    return W
end

function Win.UpdateLockIcon(W)
    if not W.lockBtn then return end
    W.lockBtn.key = W.wdb.locked and "locked" or "unlocked"
    W.lockBtn.icon:SetTexture(BTN_TEX[W.lockBtn.key])
    ns.Move.ApplyLock(W)
end

------------------------------------------------------------
-- 發佈鈕的可用狀態
--
-- 封鎖中（戰鬥、首領戰、傳奇鑰石、PvP）換成打叉的圖並壓暗 —— 套組慣例是
-- **狀態只換明暗不換色**，所以壓暗就是強調色三個分量各乘 BLOCKED_K，不換色相。
-- 「為什麼」由工具提示的第二行說（見 MakeHeaderButton 的 tooltipNote）。
--
-- 這裡碰的全是自己的非保護框上的貼圖與顏色，戰鬥中隨時能做。
-- 圖示狀態只是**提示**：真正的閘在點擊當下與送出當下各重問一次 BlockedReason()。
------------------------------------------------------------
function Win.UpdatePublishState(W)
    local btn = W.hdrButtonById and W.hdrButtonById.publish
    if not btn then return end
    local blocked = (ns.Publish and ns.Publish.BlockedReason() ~= nil) or false
    if btn._blocked == blocked then return end   -- 值沒變就不要動 setter
    btn._blocked = blocked

    btn.key = blocked and "publishOff" or "publish"
    btn.icon:SetTexture(BTN_TEX[btn.key])
    local r, g, b = M.Accent()
    if blocked then r, g, b = r * BLOCKED_K, g * BLOCKED_K, b * BLOCKED_K end
    btn.icon:SetVertexColor(r, g, b)
end

-- 一條長條的外觀（ApplyStyle 與懶建的右欄共用）
function Win.StyleBar(bar, s, texPath)
    Win.ApplyBarTextOffsets(bar)
    Win.ApplyBarBorder(bar)
    Win.ApplyBarBg(bar)
    bar._target = Win.ApplyBarStyle(bar, s, texPath)
    Win.AnchorBarFill(bar, 0)     -- 圖示寬度等 PaintBar 解出來再改
    bar._colorClass = nil         -- 逼下一次 PaintBar 重上色
end

------------------------------------------------------------
-- 套用外觀設定
--
-- 這支會走過整個 frame 樹，所以**只在設定變動時呼叫**，絕不在刷新迴圈裡。
-- 刷新迴圈只做 SetValue / SetText。
------------------------------------------------------------
function Win.ApplyStyle(W)
    local s = ns.DB.Style()
    local wdb = W.wdb
    local frame, header = W.frame, W.header

    local hdrH = D.Px(s.hdrHeight or 22)
    header:SetHeight(hdrH)
    Win.ApplyOrientation(W)

    local bg = s.bgColor
    frame.bg:SetColorTexture(bg.r or 0, bg.g or 0, bg.b or 0, bg.a or 0.75)

    local hb = s.hdrBgColor
    header.bg:SetColorTexture(hb.r or 0, hb.g or 0, hb.b or 0, hb.a or 1)

    local bb = s.hdrBottomBorderColor
    header.bottomBorder:SetHeight(D.Px(s.hdrBottomBorderSize or 0))
    header.bottomBorder:SetColorTexture(bb.r or 0, bb.g or 0, bb.b or 0, bb.a or 1)
    header.bottomBorder:SetShown((s.hdrBottomBorderSize or 0) > 0)

    -- 左側類型區塊：圖示貼左緣，標題接在它右邊
    local iconSz = s.hdrIconSize or 20
    W.typeIcon:SetSize(iconSz, iconSz)
    W.typeIcon:ClearAllPoints()
    W.typeIcon:SetPoint("LEFT", header, "LEFT", TYPE_PAD, 0)
    W.typeIcon:SetVertexColor(M.Accent())
    W.typeIcon:SetAlpha(ICON_ALPHA)

    -- 標題文字
    local hdrFS = s.hdrFontSize or 11
    Win.SetFont(W.titleText, hdrFS)
    Win.SetFont(W.segText, hdrFS)
    Win.SetFont(W.timerText, hdrFS)
    W.titleText:ClearAllPoints()
    W.titleText:SetPoint("LEFT", W.typeIcon, "RIGHT", TYPE_GAP + (s.hdrTextOffX or 0), s.hdrTextOffY or 0)
    W.titleText:SetTextColor(TitleColor(s))

    -- 狀態標籤接在標題後面，箭頭再接在它後面（計時器的錨點在 FitTitle，要看圖示顯示與否）
    W.segText:ClearAllPoints()
    W.segText:SetPoint("LEFT", W.titleText, "RIGHT", STATUS_GAP, 0)
    local arrowSz = math.max(8, math.floor(hdrFS * 0.75 + 0.5))
    W.segArrow:SetSize(arrowSz, arrowSz)
    W.segArrow:ClearAllPoints()
    W.segArrow:SetPoint("LEFT", W.segText, "RIGHT", 1, 0)
    Win.ApplyStatusColor(W, W._segHover and STATUS_HOVER_K or STATUS_K)

    -- 兩塊可點範圍：「圖示 ＋ 標題」與「狀態 ＋ 箭頭」，在兩者中間的縫對半分，不重疊
    W.typeBtn:SetPoint("RIGHT", W.titleText, "RIGHT", STATUS_GAP / 2, 0)
    W.segBtn:ClearAllPoints()
    W.segBtn:SetPoint("TOPLEFT", W.typeBtn, "TOPRIGHT", 0, 0)
    W.segBtn:SetPoint("BOTTOMLEFT", W.typeBtn, "BOTTOMRIGHT", 0, 0)
    W.segBtn:SetPoint("RIGHT", W.segArrow, "RIGHT", 3, 0)
    W.segBtn.hl:SetColorTexture(M.Accent())
    W.segBtn.hl:SetAlpha(0.12)

    W.timerText:SetShown(not wdb.hideTimer)

    -- 視窗邊框
    local sz = s.borderSize or 0
    if sz > 0 then
        local c = s.borderColor
        W.borderTarget:SetBackdrop({ edgeFile = M.WHITE8X8, edgeSize = D.Px(sz) })
        W.borderTarget:SetBackdropBorderColor(c and c.r or 0, c and c.g or 0, c and c.b or 0, c and c.a or 1)
        W.borderTarget:Show()
    else
        W.borderTarget:Hide()
    end

    -- 標題列按鈕
    for _, btn in ipairs(W.hdrButtons) do
        btn.icon:SetVertexColor(M.Accent())
    end
    -- ⚠ 上面那個迴圈剛剛把發佈鈕的壓暗洗掉了（換職業色、套任何樣式都會走到這裡）。
    --   備忘要先清掉再重算，否則「值沒變就不做」會讓它停在剛被洗成亮色的狀態。
    local pubBtn = W.hdrButtonById and W.hdrButtonById.publish
    if pubBtn then pubBtn._blocked = nil end
    Win.UpdatePublishState(W)
    Win.LayoutHeaderButtons(W)
    Win.ApplyHeaderHoverIcons(W)

    -- 長條：外觀改了就把版面快取作廢，下一次刷新整批重建
    W._barCacheKey = nil
    W._stickyCacheKey = nil
    W._srcLayGen = (W._srcLayGen or 0) + 1   -- 展開頁那一頁的版面備忘（見 Breakdown.LayoutSpellBar）
    -- 樣式在這裡就直接套到每一條，不要只交給繪製路徑（RelayoutBar）——
    -- 那條路徑只走「有資料而且在可視範圍內」的列，換樣式的當下如果沒有資料
    -- （剛登入、剛重置），就會留在舊樣式直到下一場戰鬥。
    local texPath = M.BarTexture(s.barTexture)
    Win.ForEachPane(W, function(pane)
        for _, bar in ipairs(pane.rowPool) do Win.StyleBar(bar, s, texPath) end
        Win.StyleBar(pane.stickyBar, s, texPath)
    end)

    -- 同理：縮放進行中不要把尺寸拉回設定值（玩家改別的設定剛好在拉的時候）
    if not W._resize then
        frame:SetSize(wdb.width or 300, wdb.height or 200)
    end
    Win.FitTitle(W)
end
