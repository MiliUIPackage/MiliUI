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
end

-- 整批重建一列的版面（只在 cacheKey 變或這一格換了排名時跑）
local function RelayoutBar(W, bar, i, ctx)
    local s = ctx.s
    bar._slot = i
    bar.row:ClearAllPoints()
    local y = -((i - 1) * ctx.stride)
    bar.row:SetPoint("TOPLEFT", W.content, "TOPLEFT", 0, y)
    bar.row:SetPoint("TOPRIGHT", W.content, "TOPRIGHT", 0, y)
    bar.row:SetHeight(ctx.barH)
    bar.fill:SetHeight(ctx.barH)
    bar._target = Win.ApplyBarStyle(bar, s, ctx.texPath)
    Win.AnchorBarFill(bar, 0)   -- 圖示寬度等 PaintBar 解出來再改
    Win.SetFont(bar.rank,   ctx.leftFS)
    Win.SetFont(bar.label,  ctx.leftFS)
    Win.SetFont(bar.amount, ctx.rightFS)
    bar.label:SetWidth(ctx.labelW)
    -- 版面重建 = 圖示與顏色的備忘全部失效
    bar._class = nil; bar._specIcon = nil; bar._colorClass = nil; bar._rank = nil
end

local function ClearBar(bar)
    if bar.row:IsShown() then bar.row:Hide() end
    bar._src = nil; bar._guid = nil; bar._class = nil; bar._specIcon = nil
    bar._colorClass = nil; bar._name = nil; bar._amtText = nil
    bar._slot = nil; bar._rank = nil
end

------------------------------------------------------------
-- 死亡列表：API 給的是「最近的在前」，反轉成時間順序，並濾掉假死
------------------------------------------------------------
local function FilterDeaths(sources)
    ns.Combat.CleanupFeignCache()
    local out = {}
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
-- 捲動範圍
------------------------------------------------------------
function Rows.RecalcViewport(W, count)
    local s = ns.DB.Style()
    local stride = D.Px(s.barHeight or 18) + D.Px(s.barSpacing or 2)
    local totalH = count * stride
    W.content:SetHeight(math.max(10, totalH))
    local viewH = W.viewport:GetHeight()
    if viewH < 1 then viewH = 1 end
    W.scrollMax = math.max(0, totalH - viewH)
    local cur = W.viewport:GetVerticalScroll() or 0
    if cur > W.scrollMax then W.viewport:SetVerticalScroll(W.scrollMax) end
end

local function ResetScrollAnchors(W)
    W.stickyGuard = true
    W.viewport:SetPoint("TOPLEFT", W.header, "BOTTOMLEFT", 0, 0)
    W.viewport:SetPoint("BOTTOMRIGHT", W.frame, "BOTTOMRIGHT", 0, 0)
    W.stickyGuard = false
end

------------------------------------------------------------
-- 釘住自己那一列
--
-- 自己的排名捲出可視範圍時，把那一列複製到上緣（排名在上方）或下緣（在下方），
-- 並把捲動區縮掉一列高度，這樣兩者不會互相蓋住。
------------------------------------------------------------
function Rows.UpdateSticky(W, sources, ctx)
    if W.stickyGuard then return end
    local bar, sep = W.stickyBar, W.stickySep
    if not bar or not sep then return end

    local function Off()
        bar.row:Hide(); sep:Hide()
        if W.stickyPinned then
            W.stickyPinned = false
            ResetScrollAnchors(W)
            Rows.RecalcViewport(W, W.visibleCount or 0)
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
    local scroll = W.viewport:GetVerticalScroll() or 0
    local viewH  = W.frame:GetHeight() - D.Px(s.hdrHeight or 22)
    if viewH < 1 then viewH = 1 end

    local top = (idx - 1) * stride
    local bot = top + barH
    -- 完全落在可視範圍內就不必釘（1px 容差吸收浮點誤差）
    if top >= scroll - 1 and bot <= scroll + viewH + 1 then return Off() end

    local pinTop = (top < scroll)
    local pinnedH = barH + 1

    bar.row:ClearAllPoints(); sep:ClearAllPoints(); sep:SetHeight(1)
    W.stickyGuard = true
    if pinTop then
        bar.row:SetPoint("TOPLEFT", W.header, "BOTTOMLEFT", 0, 0)
        bar.row:SetPoint("TOPRIGHT", W.header, "BOTTOMRIGHT", 0, 0)
        sep:SetPoint("TOPLEFT", bar.row, "BOTTOMLEFT", 0, 0)
        sep:SetPoint("TOPRIGHT", bar.row, "BOTTOMRIGHT", 0, 0)
        W.viewport:SetPoint("TOPLEFT", W.header, "BOTTOMLEFT", 0, -pinnedH)
        W.viewport:SetPoint("BOTTOMRIGHT", W.frame, "BOTTOMRIGHT", 0, 0)
    else
        bar.row:SetPoint("BOTTOMLEFT", W.frame, "BOTTOMLEFT", 0, 0)
        bar.row:SetPoint("BOTTOMRIGHT", W.frame, "BOTTOMRIGHT", 0, 0)
        sep:SetPoint("BOTTOMLEFT", bar.row, "TOPLEFT", 0, 0)
        sep:SetPoint("BOTTOMRIGHT", bar.row, "TOPRIGHT", 0, 0)
        W.viewport:SetPoint("TOPLEFT", W.header, "BOTTOMLEFT", 0, 0)
        W.viewport:SetPoint("BOTTOMRIGHT", W.frame, "BOTTOMRIGHT", 0, pinnedH)
    end
    W.stickyGuard = false
    W.stickyPinned = true
    W.stickyAtTop = pinTop

    -- 捲動區變矮了，夾一次捲動位置
    local newViewH = W.viewport:GetHeight()
    if newViewH and newViewH > 0 then
        W.scrollMax = math.max(0, #sources * stride - newViewH)
        if (W.viewport:GetVerticalScroll() or 0) > W.scrollMax then
            W.viewport:SetVerticalScroll(W.scrollMax)
        end
    end

    -- 版面快取：釘住那列的字級／材質變了才重排
    local key = table.concat({
        ctx and ctx.leftFS or 11, ctx and ctx.rightFS or 11,
        ctx and ctx.texPath or "", barH, tostring(s.iconStyle), tostring(s.barFillAlpha),
        tostring(s.barStyle), tostring(s.barLineHeight),
    }, "|")
    if key ~= W._stickyCacheKey then
        W._stickyCacheKey = key
        bar.row:SetHeight(barH)
        bar.fill:SetHeight(barH)
        bar._target = Win.ApplyBarStyle(bar, s, ctx and ctx.texPath or M.WHITE8X8)
        Win.AnchorBarFill(bar, 0)
        Win.SetFont(bar.rank,   ctx and ctx.leftFS or 11)
        Win.SetFont(bar.label,  ctx and ctx.leftFS or 11)
        Win.SetFont(bar.amount, ctx and ctx.rightFS or 11)
        bar.label:SetWidth(math.max(20, (W.frame:GetWidth() or 200) * 0.60))
        bar._class = nil; bar._specIcon = nil; bar._colorClass = nil; bar._rank = nil
    end

    bar.row:Show()
    sep:Show()
    if ctx then PaintBar(W, bar, sources[idx], ctx, idx) end
end

------------------------------------------------------------
-- 主繪製
------------------------------------------------------------
function Rows.Render(W, session)
    if not W.frame then return end
    W._lastSession = session   -- 捲動時要重畫，不必再問一次 API

    local s = ns.DB.Style()
    local count = 0

    if session and session.combatSources then
        local sources = session.combatSources
        local isDeaths = D.IsDeathType(W.curDMType)
        if isDeaths then sources = FilterDeaths(sources) end
        W._barSources = sources

        local barH   = D.Px(s.barHeight or 18)
        local barSp  = D.Px(s.barSpacing or 2)
        local leftFS  = s.leftFontSize or 11
        local rightFS = s.rightFontSize or 11
        local texPath = M.BarTexture(s.barTexture)
        local rowWidth = W.viewport:GetWidth() or 200

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

        local ctx = {
            s = s,
            barH = barH,
            stride = barH + barSp,
            leftFS = leftFS,
            rightFS = rightFS,
            texPath = texPath,
            labelW = math.max(20, rowWidth * 0.60),
            maxAmt = isDeaths and 1 or (sources[1] and sources[1].totalAmount or 1),
            isDeaths = isDeaths,
            isCount = D.IsCountType(W.curDMType),
            isOverall = (not W.curSessionID and W.curSession == D.S.Overall),
            iconStyle = s.iconStyle or "spec",
            iconZoom = s.iconZoom or 0.06,
            numFmt = s.numberFormat or 2,
            dmType = W.curDMType,
            total = total,
        }

        -- cacheKey：一條字串比較決定要不要整批重排版面
        local key = table.concat({
            leftFS, rightFS, texPath, ctx.iconStyle, tostring(ctx.iconZoom),
            s.barColorMode, tostring(s.barFillAlpha), barH, barSp,
            tostring(s.barStyle), tostring(s.barLineHeight),
            tostring(s.hideRank), tostring(s.leftTextUseClassColor),
            tostring(s.rightTextUseClassColor), tostring(s.font), tostring(s.fontOutline),
        }, "|")
        ctx.fullRebuild = (key ~= W._barCacheKey)
        if ctx.fullRebuild then W._barCacheKey = key end

        -- 可視範圍：只有這個區間內的列會填內容
        local scroll = W.viewport:GetVerticalScroll() or 0
        local viewH  = W.viewport:GetHeight() or 200
        local first  = math.floor(scroll / ctx.stride) + 1
        local last   = math.min(count, math.ceil((scroll + viewH) / ctx.stride))

        -- 首頁／展開頁蓋在上面時長條根本看不到，填值是純浪費。版面照排
        -- （關掉那一頁時才不會看到一幀舊版面），內容等它關掉再補。
        local painting = not ((W.homeFrame and W.homeFrame:IsShown()) or W.sourceOpen)

        for i = 1, POOL do
            local bar = W.rowPool[i]
            if i <= count then
                if not bar.row:IsShown() then bar.row:Show() end
                if ctx.fullRebuild or bar._slot ~= i then
                    RelayoutBar(W, bar, i, ctx)
                end
                if painting and i >= first and i <= last then
                    PaintBar(W, bar, sources[i], ctx, i)
                end
            else
                ClearBar(bar)
            end
        end

        Rows.UpdateSticky(W, sources, ctx)
    else
        for i = 1, POOL do ClearBar(W.rowPool[i]) end
        W._barSources = nil
        Rows.UpdateSticky(W, nil, nil)
    end

    W.visibleCount = count
    Rows.RecalcViewport(W, count)
    Win.UpdateTimerText(W)

    -- 標題刻意不在這裡更新：它只有在切類型／切分段／改尺寸時會變，那三個路徑
    -- 都自己叫過 UpdateTitle 了。放進每秒的迴圈等於每秒做一次 GetStringWidth 迴圈。
    if W.sourceOpen then ns.Breakdown.Refresh(W) end
    -- 首頁開著才刷：它會為八種統計類型各問一次 API，是這支插件最貴的一頁
    if W.homeFrame and W.homeFrame:IsShown() then ns.Home.Refresh(W) end
end
