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
-- 格子外觀（每格的暗底、1px 黑邊、格與格之間的分隔）是另外畫的「裝飾」：
--   * 一直顯示的列：裝飾畫在列上（不在按鈕子樹裡），尺寸變了原地重排，不必換容器
--   * 「有光環才顯示」的列：裝飾也建在按鈕子樹裡（按鈕只在有光環時顯示 ⇒ 整列跟著出現），
--     裝飾的幾何進簽章
-- 整列寬的填色跨過格距：第 k 層的填色終點落在第 k 個格距裡（W·k/n 與格子邊界差 gap·(1-k/n) < gap），
-- 所以分隔（跟黑邊同色）剛好蓋住，看起來還是一格一格的。
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
function AB.Geometry(W, n, gap, segW)
    local out = { cells = {}, gaps = {} }
    n = math.max(1, math.floor(tonumber(n) or 1))
    gap = tonumber(gap) or 0
    if not segW then segW = (W - gap * (n - 1)) / n end
    for i = 1, n do
        local x = (i - 1) * (segW + gap)
        out.cells[i] = { x = x, w = segW }
        if i < n and gap > 0 then out.gaps[i] = { x = x + segW, w = gap } end
    end
    return out
end

-- 在 parent 上建一組裝飾貼圖（暗底 BACKGROUND、黑邊與分隔在 overlay 子框上）。
-- anchor：幾何的基準框（列本身或按鈕）
local function NewDecor(parent)
    local d = { parent = parent, bgs = {}, edges = {}, seps = {} }
    local ov = CreateFrame("Frame", nil, parent)
    ov:SetAllPoints(parent)
    d.overlay = ov
    return d
end

local function Tex(pool, i, parent, layer)
    local t = pool[i]
    if not t then
        t = parent:CreateTexture(nil, layer)
        t:SetTexture(SOLID)
        pool[i] = t
    end
    return t
end

-- geom = { W, H, n, gap, segW, reversed, segments, dim = { r, g, b, a }, px (1 實體像素) }
local function LayoutDecor(d, anchor, geom)
    local g = AB.Geometry(geom.W, geom.segments and geom.n or 1, geom.segments and geom.gap or 0,
        geom.segments and geom.segW or geom.W)
    local px = geom.px or 1
    local H = geom.H
    local dim = geom.dim
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
    for _, c in ipairs(g.cells) do
        nb = nb + 1
        local bg = Tex(d.bgs, nb, d.parent, "BACKGROUND")
        bg:SetVertexColor(dim[1], dim[2], dim[3], dim[4])
        Place(bg, c.x, c.w, 0, H)
        -- 1px 黑邊：上下左右各一條（疊在填色之上）
        for side = 1, 4 do
            ne = ne + 1
            local e = Tex(d.edges, ne, d.overlay, "OVERLAY")
            e:SetVertexColor(0, 0, 0, 1)
            if side == 1 then Place(e, c.x, c.w, 0, px)
            elseif side == 2 then Place(e, c.x, c.w, H - px, px)
            elseif side == 3 then Place(e, c.x, px, 0, H)
            else Place(e, c.x + c.w - px, px, 0, H) end
        end
    end
    for _, s in pairs(g.gaps) do
        ns2 = ns2 + 1
        local t = Tex(d.seps, ns2, d.overlay, "OVERLAY")
        t:SetVertexColor(0, 0, 0, 1)
        Place(t, s.x, s.w, 0, H)
    end
    for i = nb + 1, #d.bgs do d.bgs[i]:Hide() end
    for i = ne + 1, #d.edges do d.edges[i]:Hide() end
    for i = ns2 + 1, #d.seps do d.seps[i]:Hide() end
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
    for _, t in ipairs(d.bgs) do if t:IsShown() then t:SetAlpha(1) end end
    return d
end

function AB.HideRowDecor(row)
    local d = row.abDecor
    if not d then return end
    d.overlay:Hide()
    for _, t in ipairs(d.bgs) do t:Hide() end
end

------------------------------------------------------------
-- 簽章與樣式（全部解成純數字；initializeFrame 裡只查這張表）
--
-- spec = { kind = "applications"（預設）| "instances", spellIDs = { id, … }, max, texture,
--          color = { r, g, b }, alpha, reversed,
--          inside = geom | nil（「有光環才顯示」：裝飾建在按鈕子樹裡），
--          cell = geom（instances 必填：一格的大小與格距，進簽章） }
------------------------------------------------------------
function AB.Signature(spec)
    local ids = {}
    for _, id in ipairs(spec.spellIDs or {}) do ids[#ids + 1] = tostring(id) end
    table.sort(ids)
    local c = spec.color or {}
    local parts = {
        spec.kind == "instances" and "inst" or "apps",
        table.concat(ids, ","), tostring(spec.max), tostring(spec.texture),
        Fmt(c.r), Fmt(c.g), Fmt(c.b), Fmt(spec.alpha), tostring(spec.reversed and true or false),
    }
    local cg = spec.kind == "instances" and spec.cell
    if cg then
        parts[#parts + 1] = table.concat({ "cell", Fmt(cg.segW), Fmt(cg.H), Fmt(cg.gap) }, ":")
    end
    local g = spec.inside
    if g then
        local dim = g.dim or {}
        parts[#parts + 1] = table.concat({ "in", Fmt(g.W), Fmt(g.H), tostring(g.n), Fmt(g.gap), Fmt(g.segW),
            tostring(g.segments and true or false), Fmt(g.px), Fmt(dim[1]), Fmt(dim[2]), Fmt(dim[3]), Fmt(dim[4]) }, ":")
    end
    return table.concat(parts, "|")
end

------------------------------------------------------------
-- 持有框、容器
------------------------------------------------------------
local function Kick(c)
    pcall(function() c:Hide(); c:Show() end)
    if c.SetEnabled then pcall(c.SetEnabled, c, true) end
end

local function OnHolderShow(h)
    local c = h.container
    if not c then return end
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

-- ⚠ 只能從 initializeFrame 呼叫（外面包 xpcall）。不 CreateColor、不掛 script、顏色純數字
local function InitButton(btn, c, st, h, sig)
    pcall(btn.SetMouseClickEnabled, btn, false)
    pcall(btn.SetMouseMotionEnabled, btn, false)       -- 純顯示：別擋住底下的東西
    if st.kind ~= "instances" then
        pcall(function()
            btn:ClearAllPoints()
            btn:SetAllPoints(c)                        -- slot 的按鈕不參與 flow layout
        end)
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
    else
        -- CustomAuraButtonApplicationBarOptions：maxApplications（必填）、interpolation（可省）。
        -- 12.1.5 多一個 minApplications（預設 0），12.1.0 沒有 ⇒ 不傳
        local opts = { maxApplications = st.max }
        if st.interp then opts.interpolation = st.interp end
        btn:SetApplicationBar(bar, opts)
    end
    h.okSigs[sig] = true
end

local function BuildContainer(h, st, sig)
    local c = CreateFrame("AuraContainer", nil, h, "CustomAuraContainerTemplate")
    c:SetAllPoints(h)
    c:SetFrameLevel((h:GetFrameLevel() or 1) + 1)
    -- 建立順序：SetUnit 在 slot 之前、SetEnabled 最後（本套組實跑過的順序）
    c:SetUnit("player")
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
        c:AddAuraGroup("bar", "HELPFUL", {
            maxFrameCount = st.max,
            candidateFilters = { includeSpellIDs = include },
            initializeFrame = init,
            layout = { elementWidth = cg.segW, elementHeight = cg.H, elementSpacing = cg.gap },
        })
    else
        c:AddAuraSlot("bar", "HELPFUL", {
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
            texture = spec.texture or SOLID,
            r = tonumber(c2.r) or 1, g = tonumber(c2.g) or 1, b = tonumber(c2.b) or 1,
            alpha = tonumber(spec.alpha) or 1, reversed = spec.reversed and true or false,
            inside = spec.inside, kind = spec.kind, cell = spec.cell,
            interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or nil,
            remaining = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or nil,
        }
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
    if h and h.pendingKick and h.container and not InCombatLockdown() then
        h.pendingKick = nil
        Kick(h.container)
    end
end
