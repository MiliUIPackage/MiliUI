------------------------------------------------------------
-- 長條繪製：整個插件的熱路徑
--
-- 三層省力，缺一不可：
--   1. cacheKey  一條字串比較決定「這次要不要重排版面」。沒變就只填值。
--   2. 每列備忘  職業／專精／名字／數字字串各記一份，值沒變就不呼叫 setter。
--   3. 可視剔除  只有捲動可視範圍內的列會填內容。
--
-- 結果是穩定狀態下每秒的工作量 ≈「可視列數 × 兩次 SetValue/SetText」，
-- 跟團隊人數、戰鬥記錄流量完全無關。
--
-- ⚠ 秘密值鐵則：**秘密值一律寫入、永不備忘。** `v ~= cached` 對秘密值會丟錯，
--   所以形狀固定是「是秘密就直接寫並把備忘清成 nil」。
------------------------------------------------------------
local _, ns = ...

ns.Rows = {}
local Rows = ns.Rows
local D  = ns.Data
local M  = ns.Media
local Win = ns.Window

local POOL = 40

------------------------------------------------------------
-- 單列上色／填值
--
-- 主清單與「釘住自己」那列共用這一支。同樣的邏輯抄成兩份的下場是修 bug 只修到
-- 一邊 —— spec 圖示的備忘正是那種兩邊都會踩、卻很容易只修一邊的東西。
------------------------------------------------------------
local function PaintBar(W, bar, src, ctx, rank)
    local s = ctx.s

    -- 圖示：只在輸入變了才重畫。
    -- ⚠ 備忘必須連 specIconID 一起記，不能只記 classFilename——
    --   長條是照排名回收的，同職業不同專精的兩個人換位置時 classFilename 沒變，
    --   那一列就會留著前一個人的專精圖。
    local classFile = src.classFilename
    local specIcon  = src.specIconID
    if classFile ~= bar._class or specIcon ~= bar._specIcon then
        bar._class    = classFile
        bar._specIcon = specIcon
        bar._colorClass = nil
        local offset = D.ResolveIcon(src, bar.icon, ctx.barH, ctx.iconStyle, ctx.iconZoom)
        Win.AnchorBarFill(bar, offset)
        if s.barBgUseClassColor then Win.ApplyBarBg(bar) end
    end

    -- 填充值。死亡列表沒有「量」的概念，一律畫滿。
    -- 這裡把可能是秘密的 totalAmount 原封不動交給 StatusBar（引擎自己除），
    -- 代價是這條 bar 的幾何從此是秘密的 —— 所以**任何地方都不准量它**，
    -- 尺寸只能來自設定值。
    local target = bar._target or bar.fill
    if ctx.isDeaths then
        target:SetMinMaxValues(0, 1)
        target:SetValue(1)
    else
        target:SetMinMaxValues(0, ctx.maxAmt)
        target:SetValue(src.totalAmount or 0)
    end

    -- 顏色：職業色模式下只在職業變了才重設；固定色只在整批重建時設一次
    if s.barColorMode == "class" then
        if classFile ~= bar._colorClass then
            bar._colorClass = classFile
            target:SetStatusBarColor(Win.BarColor(s, D.SafeClass(classFile), ctx.dmType))
        end
    elseif ctx.fullRebuild or bar._colorClass ~= false then
        bar._colorClass = false
        target:SetStatusBarColor(Win.BarColor(s, nil, ctx.dmType))
    end

    -- 文字顏色
    if s.leftTextUseClassColor then
        local r, g, b = M.ClassColor(classFile)
        if not r then r, g, b = 1, 1, 1 end
        bar.label:SetTextColor(r, g, b)
        bar.rank:SetTextColor(r, g, b)
    elseif ctx.fullRebuild then
        bar.label:SetTextColor(Win.TextColor(s, "left"))
        bar.rank:SetTextColor(Win.TextColor(s, "left"))
    end
    if s.rightTextUseClassColor then
        local r, g, b = M.ClassColor(classFile)
        if not r then r, g, b = 1, 1, 1 end
        bar.amount:SetTextColor(r, g, b)
    elseif ctx.fullRebuild then
        bar.amount:SetTextColor(Win.TextColor(s, "right"))
    end

    -- 排名
    if s.hideRank then
        if bar._rank ~= false then bar._rank = false; bar.rank:SetText("") end
    elseif rank ~= bar._rank then
        bar._rank = rank
        bar.rank:SetText(D.RANK[rank] or (rank .. "."))
    end

    -- 名字（秘密值：直接寫、清備忘）
    local name = src.name
    if D.IsSecret(name) then
        bar.label:SetText(D.StripRealm(name))
        bar._name = nil
    elseif name ~= bar._name then
        bar._name = name
        bar.label:SetText(D.StripRealm(name))
    end

    -- 數值
    local text
    if ctx.isDeaths then
        -- 總計視圖的死亡沒有「距今幾秒」可言（跨了好幾場戰鬥），留白
        text = ctx.isOverall and "" or D.FormatTimer(src.deathTimeSeconds)
    elseif ctx.isCount then
        text = D.Abbrev(src.totalAmount)
    else
        text = D.FormatValue(src.totalAmount, src.amountPerSecond, ctx.numFmt)
        if ctx.total and ctx.total > 0 then
            local amt = src.totalAmount
            if not D.IsSecret(amt) and type(amt) == "number" then
                text = text .. format("  %.1f%%", amt / ctx.total * 100)
            end
        end
    end
    if D.IsSecret(text) then
        bar.amount:SetText(text)
        bar._amtText = nil
    elseif text ~= bar._amtText then
        bar._amtText = text
        bar.amount:SetText(text)
    end

    bar._src  = src
    bar._guid = src.sourceGUID
    -- 這一列是哪種統計：合併檢視的兩欄類型不同，展開頁與滑過預覽要照這個查，
    -- 不能照視窗的 curDMType（那是合併類型本身，API 不認得）
    bar._dmType = ctx.dmType
end

-- 整批重建一列的版面（只在 cacheKey 變或這一格換了排名時跑）
local function RelayoutBar(pane, bar, i, ctx)
    local s = ctx.s
    bar._slot = i
    bar.row:ClearAllPoints()
    local O = ctx.O
    local y = -((i - 1) * ctx.stride) * O.v
    bar.row:SetPoint(O.topL, pane.content, O.topL, 0, y)
    bar.row:SetPoint(O.topR, pane.content, O.topR, 0, y)
    bar.row:SetHeight(ctx.barH)
    bar.fill:SetHeight(ctx.barH)
    bar._target = Win.ApplyBarStyle(bar, s, ctx.texPath)
    Win.AnchorBarFill(bar, 0)   -- 圖示寬度等 PaintBar 解出來再改
    Win.SetFont(bar.rank,   ctx.leftFS)
    Win.SetFont(bar.label,  ctx.leftFS)
    Win.SetFont(bar.amount, ctx.rightFS)
    bar.label:SetWidth(ctx.labelW)
    bar._compactLabel = ctx.split
    Win.AnchorBarLabel(bar, ctx.split)
    -- 版面重建 = 圖示與顏色的備忘全部失效
    bar._class = nil; bar._specIcon = nil; bar._colorClass = nil; bar._rank = nil
end

local function ClearBar(bar)
    if bar.row:IsShown() then bar.row:Hide() end
    bar._src = nil; bar._guid = nil; bar._class = nil; bar._specIcon = nil
    bar._colorClass = nil; bar._name = nil; bar._amtText = nil
    bar._slot = nil; bar._rank = nil; bar._dmType = nil
end

------------------------------------------------------------
-- 死亡列表：API 給的是「最近的在前」，反轉成時間順序，並濾掉假死
--
-- holder 只是「緩衝掛在誰身上」：繪製路徑傳 pane，發佈（Meter/Publish.lua）傳
-- 它自己的表。**不要為了別的呼叫端複製一份這段邏輯** —— 假死的判準要是兩套，
-- 清單裡看不到的人會出現在貼進聊天的排行裡。
------------------------------------------------------------
function Rows.FilterDeaths(holder, sources)
    ns.Combat.CleanupFeignCache()
    -- 緩衝重用：這支每 tick 都跑，每次配一張新表就是每秒四張垃圾。
    -- 安全性：回傳的表只在這一趟 Render 裡被讀完（PaintBar／UpdateSticky），
    -- 沒有任何地方跨 tick 抓著它。
    local out = holder._deathBuf
    if not out then out = {}; holder._deathBuf = out end
    wipe(out)
    for i = #sources, 1, -1 do
        local src = sources[i]
        local rid = src.deathRecapID
        -- _feignDeathGUIDs[secret] 會硬錯（不能用秘密值當 key），
        -- 所以只有明碼 GUID 才查得起快取；秘密 GUID 的列只能靠 deathRecapID 篩
        local guid = D.PlainGUID(src.sourceGUID)
        if not D.IsSecret(rid) and rid and rid > 0
            and not (guid and ns.Combat.IsFeigned(guid)) then
            out[#out + 1] = src
        end
    end
    return out
end

------------------------------------------------------------
-- 邏輯捲動
--
-- **0 永遠是「看得到第一名」那一端**，不管排列是正的還是反的。
-- 反轉時第一名在 content 的底部，而 ScrollFrame 的 0 是頂部 —— 所以原始值要倒過來。
-- 有了這層，可視剔除、釘住自己那列、滾輪三處的算式都不必分兩種寫法。
--
-- 另一個好處：存的是邏輯位置，所以列數變多時（新的人打出傷害）第一名那端不會
-- 被推走。反轉時這正是玩家盯著的地方。
--
-- pane 省略＝主欄（W 本身）。合併檢視的右欄傳 W.split，欄位名稱一模一樣
-- （見 Window.lua 的 BuildPane）；反轉與否是整個視窗的設定，一律讀 W.wdb。
------------------------------------------------------------
function Rows.GetScroll(W, pane)
    pane = pane or W
    local raw = pane.viewport:GetVerticalScroll() or 0
    if not W.wdb.reverse then return raw end
    return math.max(0, (pane.scrollMax or 0) - raw)
end

function Rows.SetScroll(W, v, pane)
    pane = pane or W
    local maxv = pane.scrollMax or 0
    v = math.max(0, math.min(maxv, v))
    pane.viewport:SetVerticalScroll(W.wdb.reverse and (maxv - v) or v)
end

------------------------------------------------------------
-- 捲動範圍
------------------------------------------------------------
function Rows.RecalcViewport(W, count, pane)
    pane = pane or W
    local s = ns.DB.Style()
    local stride = D.Px(s.barHeight or 18) + D.Px(s.barSpacing or 2)
    local totalH = count * stride
    local viewH = pane.viewport:GetHeight()
    if viewH < 1 then viewH = 1 end

    -- 先用**舊的** scrollMax 把目前位置解成邏輯值，換完高度再用新的貼回去。
    -- 不這樣做的話，反轉時每次列數一變畫面就會自己跳。
    local logical = Rows.GetScroll(W, pane)

    -- 反轉時內容至少要有一個可視高：content 的底邊就是第一名的位置，
    -- 內容比視窗矮的話它會浮在半空中（ScrollFrame 把 content 貼在頂端）。
    local wantH = totalH
    if W.wdb.reverse and wantH < viewH then wantH = viewH end
    -- 高度沒變就不必再 SetHeight 一次。⚠ 反轉時 viewH 也是輸入（縮放視窗會變），
    -- 所以備忘存的是算完的 wantH 而不是 totalH。
    if pane._contentH ~= wantH then
        pane._contentH = wantH
        pane.content:SetHeight(math.max(10, wantH))
    end

    pane.scrollMax = math.max(0, totalH - viewH)
    Rows.SetScroll(W, logical, pane)
end

-- 貼 pane.area 而不是標題列／視窗：合併檢視時 area 只佔半邊（見 Win.AnchorPanes）
local function ResetScrollAnchors(W, pane)
    local O = Win.Orient(W)
    pane.stickyGuard = true
    pane.viewport:ClearAllPoints()
    pane.viewport:SetPoint(O.topL, pane.area, O.topL, 0, 0)
    pane.viewport:SetPoint(O.botR, pane.area, O.botR, 0, 0)
    pane.stickyGuard = false
end

------------------------------------------------------------
-- 釘住自己那一列
--
-- 自己的排名捲出可視範圍時，把那一列複製到上緣（排名在上方）或下緣（在下方），
-- 並把捲動區縮掉一列高度，這樣兩者不會互相蓋住。合併檢視時兩欄各釘各的。
------------------------------------------------------------
function Rows.UpdateSticky(W, pane, sources, ctx)
    if pane.stickyGuard then return end
    local bar, sep = pane.stickyBar, pane.stickySep
    if not bar or not sep then return end

    local function Off()
        bar.row:Hide(); sep:Hide()
        if pane.stickyPinned then
            pane.stickyPinned = false
            ResetScrollAnchors(W, pane)
            Rows.RecalcViewport(W, pane.visibleCount or 0, pane)
        end
    end

    local s = ctx and ctx.s or ns.DB.Style()
    if not s.showPinnedSelf then return Off() end
    if W.sourceOpen or (W.homeFrame and W.homeFrame:IsShown()) then return Off() end
    if not sources or #sources == 0 then return Off() end

    local idx
    for i, src in ipairs(sources) do
        if D.IsOwnRow(src) then idx = i; break end
    end
    if not idx then return Off() end

    local barH  = ctx and ctx.barH or D.Px(s.barHeight or 18)
    local stride = ctx and ctx.stride or (barH + D.Px(s.barSpacing or 2))
    local scroll = Rows.GetScroll(W, pane)
    local viewH  = pane.area:GetHeight() or 0
    if viewH < 1 then viewH = 1 end

    local top = (idx - 1) * stride
    local bot = top + barH
    -- 完全落在可視範圍內就不必釘（1px 容差吸收浮點誤差）
    if top >= scroll - 1 and bot <= scroll + viewH + 1 then return Off() end

    -- 釘在「標題列那一端」還是「另一端」。名字用不到上下 —— 反轉之後
    -- 標題列那端就是畫面下方，但語意（自己排在可視範圍之前）完全一樣。
    local pinHeaderSide = (top < scroll)
    local pinnedH = barH + 1
    local O = Win.Orient(W)
    local area = pane.area

    bar.row:ClearAllPoints(); sep:ClearAllPoints(); sep:SetHeight(1)
    pane.viewport:ClearAllPoints()
    pane.stickyGuard = true
    if pinHeaderSide then
        bar.row:SetPoint(O.topL, area, O.topL, 0, 0)
        bar.row:SetPoint(O.topR, area, O.topR, 0, 0)
        sep:SetPoint(O.topL, bar.row, O.botL, 0, 0)
        sep:SetPoint(O.topR, bar.row, O.botR, 0, 0)
        pane.viewport:SetPoint(O.topL, area, O.topL, 0, -pinnedH * O.v)
        pane.viewport:SetPoint(O.botR, area, O.botR, 0, 0)
    else
        bar.row:SetPoint(O.botL, area, O.botL, 0, 0)
        bar.row:SetPoint(O.botR, area, O.botR, 0, 0)
        sep:SetPoint(O.botL, bar.row, O.topL, 0, 0)
        sep:SetPoint(O.botR, bar.row, O.topR, 0, 0)
        pane.viewport:SetPoint(O.topL, area, O.topL, 0, 0)
        pane.viewport:SetPoint(O.botR, area, O.botR, 0, pinnedH * O.v)
    end
    pane.stickyGuard = false
    pane.stickyPinned = true

    -- 捲動區變矮了，夾一次捲動位置
    local newViewH = pane.viewport:GetHeight()
    if newViewH and newViewH > 0 then
        local logical = Rows.GetScroll(W, pane)
        pane.scrollMax = math.max(0, #sources * stride - newViewH)
        Rows.SetScroll(W, logical, pane)
    end

    -- 版面快取：釘住那列的字級／材質變了才重排
    local key = table.concat({
        ctx and ctx.leftFS or 11, ctx and ctx.rightFS or 11,
        ctx and ctx.texPath or "", barH, tostring(s.iconStyle), tostring(s.barFillAlpha),
        tostring(s.barStyle), tostring(s.barLineHeight), tostring(ctx and ctx.split),
    }, "|")
    if key ~= pane._stickyCacheKey then
        pane._stickyCacheKey = key
        bar.row:SetHeight(barH)
        bar.fill:SetHeight(barH)
        bar._target = Win.ApplyBarStyle(bar, s, ctx and ctx.texPath or M.WHITE8X8)
        Win.AnchorBarFill(bar, 0)
        Win.SetFont(bar.rank,   ctx and ctx.leftFS or 11)
        Win.SetFont(bar.label,  ctx and ctx.leftFS or 11)
        Win.SetFont(bar.amount, ctx and ctx.rightFS or 11)
        bar.label:SetWidth(math.max(20, (area:GetWidth() or 200) * 0.60))
        bar._compactLabel = ctx and ctx.split or false
        Win.AnchorBarLabel(bar, bar._compactLabel)
        bar._class = nil; bar._specIcon = nil; bar._colorClass = nil; bar._rank = nil
    end

    bar.row:Show()
    sep:Show()
    if ctx then PaintBar(W, bar, sources[idx], ctx, idx) end
end

------------------------------------------------------------
-- 合併檢視的開關
--
-- 不需要每個「換類型」的入口各自記得叫：Render 每次都拿 curDMType 對一次
-- （一個布林比較），不一樣才來這裡。右鍵選單、首頁卡片、設定頁下拉、
-- 登入時從存檔還原，全部自動涵蓋。
------------------------------------------------------------
local function SetSplit(W, on)
    W._splitOn = on
    if on then Win.EnsureSplitPane(W) end
    Win.AnchorPanes(W)

    local P = W.split
    if P then
        local homeOpen = W.homeFrame and W.homeFrame:IsShown()
        P.viewport:SetShown(on and not homeOpen)
        W.splitDivider:SetShown(on and not homeOpen)
        if not on then
            -- 收起來的右欄不能留著上一次的 _src：滑過預覽／展開頁認的就是它
            for i = 1, POOL do ClearBar(P.rowPool[i]) end
            P.stickyBar.row:Hide(); P.stickySep:Hide()
            P.visibleCount = 0
        end
    end
    -- 欄寬與名字的錨點都變了，要整批重排 —— 不必在這裡清 _barCacheKey，
    -- 分欄與否本身就在 cacheKey 裡（見 Rows.Render）。
end

------------------------------------------------------------
-- 一欄的繪製
--
-- ctx 的共用欄位（字級、列高、cacheKey 的判決…）由 Render 算一次，
-- 這裡只覆寫**跟這一欄的資料有關**的那幾個。
------------------------------------------------------------
local function RenderPane(W, pane, session, dmType, ctx)
    local s = ctx.s
    local count = 0

    -- 版面整批重排時，這一欄自己的版面備忘也一起作廢。主欄以前是由各個呼叫端
    -- 順手清的，右欄沒人會記得清 —— 收斂到這裡，兩欄一視同仁。
    if ctx.fullRebuild then
        pane._stickyCacheKey = nil
        pane._contentH = nil
    end

    local sources = session and session.combatSources
    if sources then
        local isDeaths = D.IsDeathType(dmType)
        if isDeaths then sources = Rows.FilterDeaths(pane, sources) end
        pane._barSources = sources

        count = math.min(#sources, POOL)

        -- 百分比欄：要把所有量加起來，秘密值不能做算術 → 秘密就整欄關掉
        local total
        if s.showPercent and not isDeaths then
            local sum, ok = 0, true
            for i = 1, count do
                local amt = sources[i].totalAmount
                if D.IsSecret(amt) or type(amt) ~= "number" then ok = false; break end
                sum = sum + amt
            end
            if ok and sum > 0 then total = sum end
        end

        -- ⚠ 兩欄共用同一張 ctx，這幾個**每一欄都要無條件覆寫**（含可能是 nil 的 total），
        --   漏一個右欄就會吃到左欄的值。加欄位時這裡一起加。
        ctx.labelW = math.max(20, (pane.viewport:GetWidth() or 200) * 0.60)
        ctx.maxAmt = isDeaths and 1 or (sources[1] and sources[1].totalAmount or 1)
        ctx.isDeaths = isDeaths
        ctx.isCount = D.IsCountType(dmType)
        ctx.dmType = dmType
        ctx.total = total

        -- 可視範圍：只有這個區間內的列會填內容
        local scroll = Rows.GetScroll(W, pane)
        local viewH  = pane.viewport:GetHeight() or 200
        local first  = math.floor(scroll / ctx.stride) + 1
        local last   = math.min(count, math.ceil((scroll + viewH) / ctx.stride))

        for i = 1, POOL do
            local bar = pane.rowPool[i]
            if i <= count then
                if not bar.row:IsShown() then bar.row:Show() end
                if ctx.fullRebuild or bar._slot ~= i then
                    RelayoutBar(pane, bar, i, ctx)
                end
                if ctx.painting and i >= first and i <= last then
                    PaintBar(W, bar, sources[i], ctx, i)
                end
            else
                ClearBar(bar)
            end
        end

        Rows.UpdateSticky(W, pane, sources, ctx)
    else
        for i = 1, POOL do ClearBar(pane.rowPool[i]) end
        pane._barSources = nil
        Rows.UpdateSticky(W, pane, nil, nil)
    end

    pane.visibleCount = count
    Rows.RecalcViewport(W, count, pane)
end

------------------------------------------------------------
-- 主繪製
--
-- session2 只有合併檢視才有（右欄的資料）。
------------------------------------------------------------
function Rows.Render(W, session, session2)
    if not W.frame then return end
    -- 捲動時要重畫，不必再問一次 API
    W._lastSession, W._lastSession2 = session, session2

    local left, right = D.SplitTypes(W.curDMType)
    local split = (left ~= nil)
    if W._splitOn ~= split then SetSplit(W, split) end

    local s = ns.DB.Style()
    local barH   = D.Px(s.barHeight or 18)
    local barSp  = D.Px(s.barSpacing or 2)
    local leftFS  = s.leftFontSize or 11
    local rightFS = s.rightFontSize or 11
    local texPath = M.BarTexture(s.barTexture)

    -- ctx 每個視窗一張、重複使用：它只在這一趟 Render 裡流動
    -- （PaintBar／RelayoutBar／UpdateSticky 都不會留著它），每 tick 配一張純浪費。
    -- ⚠ **每個欄位都要無條件覆寫**，漏一個就會把上一個 tick 的值帶進來。
    --   加欄位時這裡（或 RenderPane 裡逐欄的那一組）一起加。
    local ctx = W._ctx
    if not ctx then ctx = {}; W._ctx = ctx end
    ctx.s = s
    ctx.O = Win.Orient(W)
    ctx.barH = barH
    ctx.stride = barH + barSp
    ctx.leftFS = leftFS
    ctx.rightFS = rightFS
    ctx.texPath = texPath
    ctx.isOverall = (not W.curSessionID and W.curSession == D.S.Overall)
    ctx.iconStyle = s.iconStyle or "spec"
    ctx.iconZoom = s.iconZoom or 0.06
    ctx.numFmt = s.numberFormat or 2
    ctx.split = split
    -- 首頁／展開頁蓋在上面時長條根本看不到，填值是純浪費。版面照排
    -- （關掉那一頁時才不會看到一幀舊版面），內容等它關掉再補。
    ctx.painting = not ((W.homeFrame and W.homeFrame:IsShown()) or W.sourceOpen)

    -- cacheKey：一條字串比較決定要不要整批重排版面。兩欄共用一個判決 ——
    -- 外觀是整個視窗的，而且所有「作廢版面」的入口清的都是 W._barCacheKey。
    -- 沒資料的 tick 也會把判決吃掉，這是安全的：沒資料時每一列都被 ClearBar
    -- 清掉了 _slot，下次有資料那些列照樣會走 RelayoutBar。
    local key = table.concat({
        leftFS, rightFS, texPath, ctx.iconStyle, tostring(ctx.iconZoom),
        s.barColorMode, tostring(s.barFillAlpha), barH, barSp,
        tostring(s.barStyle), tostring(s.barLineHeight),
        tostring(s.hideRank), tostring(s.leftTextUseClassColor),
        tostring(s.rightTextUseClassColor), tostring(s.font), tostring(s.fontOutline),
        tostring(W.wdb.reverse),   -- 翻面＝每一列的錨點都要重貼
        tostring(split),           -- 分欄＝欄寬與名字的錨點都變了
    }, "|")
    ctx.fullRebuild = (key ~= W._barCacheKey)
    if ctx.fullRebuild then W._barCacheKey = key end

    RenderPane(W, W, session, left or W.curDMType, ctx)
    if split then RenderPane(W, W.split, session2, right, ctx) end

    Win.UpdateTimerText(W)

    -- 標題刻意不在這裡更新：它只有在切類型／切分段／改尺寸時會變，那三個路徑
    -- 都自己叫過 UpdateTitle 了。放進每秒的迴圈等於每秒做一次 GetStringWidth 迴圈。
    if W.sourceOpen then ns.Breakdown.Refresh(W) end
    -- 首頁開著才刷：它會為八種統計類型各問一次 API，是這支插件最貴的一頁
    if W.homeFrame and W.homeFrame:IsShown() then ns.Home.Refresh(W) end
end
