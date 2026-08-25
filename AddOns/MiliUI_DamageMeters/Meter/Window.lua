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

------------------------------------------------------------
-- 標題列按鈕的貼圖
--
-- 自己畫的一套六款 128px PNG（純白＋alpha，由下面的 SetVertexColor 染職業色）。
-- **不用暴雪的 Interface\Buttons：**那幾張是 16~32px 的舊素材，放到 22px 會糊，
-- 而且六張來自三個不同年代，湊在一起像雜牌軍。也不用 atlas —— atlas 被拿掉時
-- 是靜默失敗（見 miliui-inspect-icons 技能踩過的坑）。
--
-- ⚠ PNG 是 `.claude/skills/miliui-damagemeter-icons/scripts/dm-icons.py` 畫出來的，
--   要改造型改腳本再跑一次，不要拿繪圖軟體去修 PNG。
------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\MiliUI_DamageMeters\\Media\\"
local BTN_TEX = {
    meters   = MEDIA .. "icon-meters.png",
    segments = MEDIA .. "icon-segments.png",
    reset    = MEDIA .. "icon-reset.png",
    settings = MEDIA .. "icon-settings.png",
    locked   = MEDIA .. "icon-locked.png",
    unlocked = MEDIA .. "icon-unlocked.png",
}
Win.BTN_TEX = BTN_TEX

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
    bar.label:SetPoint("RIGHT", tf, "RIGHT", -70, ly)
    bar.amount:SetPoint("RIGHT", tf, "RIGHT", -3 + rx, ry)
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
-- 標題列按鈕
------------------------------------------------------------
local function MakeHeaderButton(W, key, tooltip, onClick)
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
    btn.key = key

    btn:SetScript("OnEnter", function(self)
        self.icon:SetAlpha(ICON_HOVER_ALPHA)
        if ns.Menu.IsOpenFor(self) then return end   -- 選單開著時不要再疊工具提示
        AnchorButtonTooltip(self)
        GameTooltip:SetText(tooltip, 1, 1, 1)
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
    return btn
end

-- 哪幾顆按鈕被設定藏起來了。三個地方要用同一個判斷（排版、滑過顯示、切換顯示），
-- 所以收斂成一支 —— 之前三處各寫一份，加第三顆按鈕時就會漏改。
local HIDE_OPTION = {
    reset    = "hideResetButton",
    settings = "hideSettingsButton",
    -- ⚠ 鎖頭的 key 會在這兩個值之間切換（見 Win.UpdateLockIcon），兩個都要列
    locked   = "hideLockButton",
    unlocked = "hideLockButton",
}

local function HiddenByOption(btn, s)
    local key = HIDE_OPTION[btn.key]
    return key ~= nil and s[key] == true
end

-- 由右到左排列，回傳實際顯示的顆數（給 FitTitle 算可用寬度）
function Win.LayoutHeaderButtons(W)
    local s = ns.DB.Style()
    local size = s.hdrIconSize or 20
    local x = -(BTN_GAP + 1)
    local n = 0
    for _, btn in ipairs(W.hdrButtons) do
        local hide = HiddenByOption(btn, s)
        if hide then
            btn:Hide()
        else
            btn:SetSize(size, size)
            btn:ClearAllPoints()
            btn:SetPoint("RIGHT", W.header, "RIGHT", x, 0)
            btn:Show()
            x = x - size - BTN_GAP
            n = n + 1
        end
    end
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
        if shown and not HiddenByOption(btn, s) then btn:Show()
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
            if not HiddenByOption(btn, s) then btn:Show() end
        end
        Win.FitTitle(W)
        return
    end
    W._hdrIconsShown = false
    for _, btn in ipairs(W.hdrButtons) do btn:Hide() end
    Win.FitTitle(W)
end

------------------------------------------------------------
-- 標題文字：放不下就截斷加省略號
------------------------------------------------------------
function Win.FitTitle(W)
    local fs = W.titleText
    local full = W._fullTitle
    if not fs or not full then return end
    fs:SetText(full)

    local s = ns.DB.Style()
    local iconSz = s.hdrIconSize or 20
    -- 藏起來的圖示不佔空間，標題就吃整條標題列（不要對著一個不存在的空隙截字）
    local n = W._hdrIconsShown and (W._hdrButtonCount or 0) or 0
    local headerW = W.frame:GetWidth() or (W.wdb.width or 300)
    -- 右邊每顆佔 size + BTN_GAP，要跟 LayoutHeaderButtons 用同一套算法，
    -- 不然標題會截在錯的地方（多留或少留一段）。
    -- 左邊要另外扣掉類型圖示那一塊（TYPE_PAD + 圖示 + TYPE_GAP）。
    local leftUsed = TYPE_PAD + iconSz + TYPE_GAP + (s.hdrTextOffX or 0)
    local avail = headerW - ((iconSz + BTN_GAP) * n) - leftUsed - 8
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

------------------------------------------------------------
-- 標題／計時器
------------------------------------------------------------
function Win.UpdateTitle(W)
    local L = ns.L
    local typeName = D.TYPE_NAMES[W.curDMType] or L["Damage Done"]
    if W.curSessionID then
        W._fullTitle = L["Segment"] .. " - " .. typeName
    elseif W.curSession == D.S.Overall then
        W._fullTitle = L["Overall"] .. " " .. typeName
    else
        W._fullTitle = typeName
    end
    Win.FitTitle(W)
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
    local sec = -1
    if not isOverall and dur and not D.IsSecret(dur) and type(dur) == "number"
        and dur > 0 and (W.visibleCount or 0) > 0 then
        sec = math.floor(dur)
    end
    if W._timerSec == sec then return end
    W._timerSec = sec
    W.timerText:SetText(sec >= 0 and ("(" .. D.FormatTimer(dur) .. ")") or "")
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
    W.hdrButtons   = {}
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
    frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -hdrH)
    frame.bg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    ------------------------------------------------------------
    -- 標題列
    ------------------------------------------------------------
    -- Button 而不是 Frame：右鍵選單走 OnClick，那是 Button 才有的腳本
    local header = CreateFrame("Button", nil, frame)
    header:SetHeight(hdrH)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetFrameLevel(frame:GetFrameLevel() + 20)
    header:EnableMouse(true)
    W.header = header

    header.bg = header:CreateTexture(nil, "BACKGROUND")
    header.bg:SetAllPoints()

    header.bottomBorder = header:CreateTexture(nil, "OVERLAY", nil, 7)
    header.bottomBorder:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    header.bottomBorder:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)

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

    W.timerText = header:CreateFontString(nil, "OVERLAY")
    W.timerText:SetPoint("LEFT", W.titleText, "RIGHT", 4, 0)
    W.timerText:SetTextColor(1, 1, 1, 0.7)
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
    -- 捲動區
    ------------------------------------------------------------
    local viewport = CreateFrame("ScrollFrame", nil, frame)
    viewport:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    viewport:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    viewport:SetFrameLevel(frame:GetFrameLevel() + 1)
    W.viewport = viewport

    local content = CreateFrame("Frame", nil, viewport)
    content:SetSize(1, 1)
    viewport:SetScrollChild(content)
    viewport:SetScript("OnSizeChanged", function(_, w) content:SetWidth(w) end)
    W.content = content

    -- 沒有捲軸貼圖，只吃滾輪：40 列的清單畫一條捲軸只是佔寬度
    local function Wheel(_, delta)
        local cur = viewport:GetVerticalScroll() or 0
        local cfg = ns.DB.Style()
        local step = D.Px(cfg.barHeight or 18) + D.Px(cfg.barSpacing or 2)
        local target = math.max(0, math.min(W.scrollMax or 0, cur - delta * step))
        viewport:SetVerticalScroll(target)
        -- 捲動會換可視範圍，要重畫（RefreshUI 只填可視列）
        if W._lastSession then ns.Rows.Render(W, W._lastSession) end
    end
    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", Wheel)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", Wheel)

    ------------------------------------------------------------
    -- 長條池
    ------------------------------------------------------------
    for i = 1, BAR_POOL_SIZE do
        local bar = Win.MakeBar(content, W)
        bar.row:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                ns.Windows.ShowContextMenu(W)
            else
                ns.Breakdown.OpenFromBar(W, bar)
            end
        end)
        bar.row:SetScript("OnEnter", function() ns.Tooltip.OnBarEnter(bar) end)
        bar.row:SetScript("OnLeave", function() ns.Tooltip.OnBarLeave(bar) end)
        W.rowPool[i] = bar
    end

    -- 釘住自己那列：獨立於捲動區之外，所以它不會跟著捲走
    local sticky = Win.MakeBar(frame, W)
    sticky.row:SetFrameLevel(frame:GetFrameLevel() + 10)
    sticky.fill:SetFrameLevel(sticky.row:GetFrameLevel() + 1)
    sticky.textFrame:SetFrameLevel(sticky.row:GetFrameLevel() + 4)
    sticky.row:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.Windows.ShowContextMenu(W)
        else
            ns.Breakdown.OpenFromBar(W, sticky)
        end
    end)
    sticky.row:SetScript("OnEnter", function() ns.Tooltip.OnBarEnter(sticky) end)
    sticky.row:SetScript("OnLeave", function() ns.Tooltip.OnBarLeave(sticky) end)
    W.stickyBar = sticky

    W.stickySep = frame:CreateTexture(nil, "OVERLAY")
    W.stickySep:SetColorTexture(1, 1, 1, 0.25)
    W.stickySep:Hide()

    ------------------------------------------------------------
    -- 標題列按鈕（由右到左：鎖定／設定／重置／分段／首頁）
    ------------------------------------------------------------
    local L = ns.L
    W.lockBtn = MakeHeaderButton(W, wdb.locked and "locked" or "unlocked",
        L["Lock window"], function()
            -- 讀 W.wdb 而不是 wdb 這個區域變數：視窗池會在換設定時重綁 W.wdb，
            -- closure 抓住舊表的話按鈕就開始改一張沒人看的設定
            W.wdb.locked = not W.wdb.locked
            Win.UpdateLockIcon(W)
        end)
    MakeHeaderButton(W, "settings", L["Window menu"], function(btn)
        ns.Windows.ShowContextMenu(W, btn)
    end)
    MakeHeaderButton(W, "reset", L["Reset data"], function()
        ns.Combat.ResetData()
    end)
    MakeHeaderButton(W, "segments", L["Segments"], function(btn)
        ns.Windows.ShowSegmentMenu(W, btn)
    end)
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
        -- API 呼叫的耗時要量：偶爾會有尖峰（歷史分段、大團隊），
        -- 尖峰那一幀就把繪製推到下一幀，不要讓兩個尖峰疊在同一幀
        local t0 = debugprofilestop()
        local session = D.GetSession(W.curSession, W.curSessionID, W.curDMType)
        local cost = debugprofilestop() - t0
        if cost > 1.5 then
            C_Timer.After(0, function() ns.Rows.Render(W, session) end)
        else
            ns.Rows.Render(W, session)
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
    frame.bg:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -hdrH)

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
    Win.SetFont(W.titleText, s.hdrFontSize or 11)
    Win.SetFont(W.timerText, s.hdrFontSize or 11)
    W.titleText:ClearAllPoints()
    W.titleText:SetPoint("LEFT", W.typeIcon, "RIGHT", TYPE_GAP + (s.hdrTextOffX or 0), s.hdrTextOffY or 0)
    -- 可點範圍蓋住「圖示 ＋ 標題」整塊，右緣跟著標題走
    W.typeBtn:SetPoint("RIGHT", W.titleText, "RIGHT", TYPE_GAP, 0)
    if s.hdrTextUseClassColor then
        W.titleText:SetTextColor(M.Accent())
    else
        local c = s.hdrTextColor
        W.titleText:SetTextColor(c and c.r or 1, c and c.g or 1, c and c.b or 1)
    end
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
    local function styleBar(bar)
        Win.ApplyBarTextOffsets(bar)
        Win.ApplyBarBorder(bar)
        Win.ApplyBarBg(bar)
        bar._target = Win.ApplyBarStyle(bar, s, texPath)
        Win.AnchorBarFill(bar, 0)     -- 圖示寬度等 PaintBar 解出來再改
        bar._colorClass = nil         -- 逼下一次 PaintBar 重上色
    end
    for _, bar in ipairs(W.rowPool) do styleBar(bar) end
    styleBar(W.stickyBar)

    -- 同理：縮放進行中不要把尺寸拉回設定值（玩家改別的設定剛好在拉的時候）
    if not W._resize then
        frame:SetSize(wdb.width or 300, wdb.height or 200)
    end
    Win.FitTitle(W)
end
