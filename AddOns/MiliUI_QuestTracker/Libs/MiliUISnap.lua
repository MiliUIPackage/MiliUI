------------------------------------------------------------
-- MiliUISnap：套組各插件的框互相磁吸
--
-- 兩種磁吸，放手時在 2 **螢幕像素**內才發生（使用者指定「相差 2px 才吸」）：
--
--   1. 貼附（attach）——「條跟條」：專注目標助手的標記列 × 爆發藥水列。
--      拖過去貼上的那條是「跟隨者」（db.snapTo 記著吸在誰的哪一邊），做法不是
--      每幀搬它，而是**直接錨在前面那條上**：引擎自己會帶著走，零成本、零時序。
--      拖前面那條 → 兩條一起動；拖跟隨者 → 先脫離（StartMoving 本來就會把錨點
--      改回 UIParent），放手時離得近就再吸回去。貼上後貼死（0px）。
--      只在**兩邊都** Register 時給 attach = true 才會貼附。
--
--   2. 對齊（align）——其他所有框：資訊列、傷害統計視窗、小地圖、任務追蹤器、
--      聊天列，以及它們跟條之間。放手時找最近的邊（左貼左／右貼右／左貼右／
--      右貼左，上下同理；兩軸各自獨立，所以「只對齊 X」的上下堆疊也吸得到），
--      把框**挪過去貼齊**就結束——不改錨點、不跟隨、不存任何東西，呼叫端照常
--      讀框的現況存座標。
--      為什麼不讓視窗也貼附：這些框的尺寸會變（追蹤器隨任務數長高、統計視窗可縮放、
--      資訊列的寬跟著文字走、小地圖可縮放），錨在它們身上的東西會跟著漂。
--
-- 這是 vendor 複製：每支插件帶一份，全域 MiliUI_Snap 先到先贏、版本高的蓋掉舊的
-- （bars 註冊表保留）。跟 MiliUI_MenuEntries 同一個理由——插件之間沒有相依宣告，
-- 玩家可能只裝其中一支。唯一 source 在 MiliUI/Libs/MiliUISnap/，改完跑
-- `python3 .claude/scripts/sync-widgets.py` 鋪到各插件。
--
-- 各插件要做的事：
--   Register(key, frame, opts)   建好框之後。opts：
--       db      = fn → 回 SavedVariables 表（貼附用，存 snapTo）
--       attach  = true  這是一條可貼附的條（兩邊都要 true 才貼附）
--       group   = "…"   同組的框互不對齊（自己插件內部已經有錨點或自家磁吸的）
--       enabled = fn    回 false 時暫時不當別人的對齊目標
--   OnDragStart(key)             StartMoving 之前（貼附的條要先脫離）
--   OnDragStop(key)              StopMovingOrSizing 之後、存座標之前：先試貼附，再試對齊
--   Restore(key)                 每次照存檔擺位置之後（貼附的條重新錨回目標）；
--                                IsAttached(key) 為真時存座標不要再把錨點改回 UIParent
--   AlignRect(key, l, r, t, b)   拖曳中就想吸的（傷害統計）自己丟螢幕座標進來，
--                                回 (dx, dy) 螢幕像素；沒得吸回 0, 0
--
-- key 是存檔內容（貼附的 db.snapTo.target），改名等於把玩家吸好的組合拆掉。
------------------------------------------------------------
local _, ns = ...

local VERSION = 2
local GAP     = 0   -- 貼上之後貼死，沒有間距（使用者指定）
local THRESH  = 2   -- 放手時離 2 螢幕像素以內才吸（使用者指定）；同軸重疊的容差也用它

local S = _G.MiliUI_Snap
if not S or (S.version or 0) < VERSION then
    S = S or {}
    S.version = VERSION
    S.bars = S.bars or {}

    -- 螢幕像素。GetLeft 這些回的是框自己座標系的值，小地圖有自己的 SetScale，
    -- 兩個 scale 不同的框不能直接比，一律乘上 effective scale 拉到同一把尺上。
    local function Edges(f)
        local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
        if not (l and r and t and b) then return nil end
        local s = f:GetEffectiveScale()
        return l * s, r * s, t * s, b * s
    end

    local function SnapOf(key)
        local info = S.bars[key]
        local db = info and info.db and info.db()
        return db and db.snapTo or nil, db
    end

    -- `target` 是不是（直接或間接）吸在 `key` 身上：避免 A 吸 B、B 又吸 A；
    -- 對齊時也要排除——跟隨者永遠貼死在我身上（距離 0），會把真正的目標擠掉
    local function HangsUnder(key, target)
        local seen, cur = {}, target
        while cur and not seen[cur] do
            seen[cur] = true
            local st = SnapOf(cur)
            if not st then return false end
            if st.target == key then return true end
            cur = st.target
        end
        return false
    end

    -- 能不能當 `key` 的目標（貼附與對齊共用的門檻）
    local function Eligible(key, k, other)
        if k == key or not other.frame or not other.frame:IsShown() then return false end
        if other.enabled and not other.enabled() then return false end
        return not HangsUnder(key, k)
    end

    -- 依 db.snapTo 重新錨定。目標還沒註冊（那支插件沒裝或還沒載）就回 false，
    -- 呼叫端維持自己的絕對座標；snapTo 留著，目標之後出現會補吸（見 Register）。
    local function Apply(key)
        local info = S.bars[key]
        if not info or not info.frame then return false end
        local st = SnapOf(key)
        if not st then return false end
        local t = S.bars[st.target]
        if not t or not t.frame then return false end
        local f = info.frame
        -- 受保護的框（有 secure 子按鈕的）戰鬥中動不了錨點；讓呼叫端下次再試
        if InCombatLockdown() and f:IsProtected() then return false end
        local g = info.gap or GAP
        f:ClearAllPoints()
        if st.side == "RIGHT" then
            f:SetPoint("TOPLEFT", t.frame, "TOPRIGHT", g, 0)
        elseif st.side == "LEFT" then
            f:SetPoint("TOPRIGHT", t.frame, "TOPLEFT", -g, 0)
        elseif st.side == "BOTTOM" then
            f:SetPoint("TOPLEFT", t.frame, "BOTTOMLEFT", 0, -g)
        elseif st.side == "TOP" then
            f:SetPoint("BOTTOMLEFT", t.frame, "TOPLEFT", 0, g)
        else
            return false
        end
        return true
    end

    function S.Register(key, frame, opts)
        opts = opts or {}
        S.bars[key] = {
            frame   = frame,
            db      = opts.db,
            gap     = opts.gap,
            attach  = opts.attach,
            group   = opts.group,
            enabled = opts.enabled,
        }
        -- 別條可能早就記著要吸在我身上，只是我那時還沒載入
        for k in pairs(S.bars) do
            local st = SnapOf(k)
            if k ~= key and st and st.target == key then Apply(k) end
        end
    end

    function S.IsAttached(key)
        return SnapOf(key) ~= nil
    end

    function S.Detach(key)
        local _, db = SnapOf(key)
        if db then db.snapTo = nil end
    end

    -- StartMoving 會把錨點改回 UIParent，狀態要跟著清；放手時再決定要不要吸回去
    function S.OnDragStart(key)
        S.Detach(key)
    end

    ------------------------------------------------------------
    -- 貼附：找最近的可吸邊。同一軸要有重疊（差一點也算），距離在 THRESH 內，
    -- 而且對方也是可貼附的條
    ------------------------------------------------------------
    local function AttachTarget(key)
        local info = S.bars[key]
        local l, r, t, b = Edges(info.frame)
        if not l then return nil end

        local best, bestD
        for k, other in pairs(S.bars) do
            if other.attach and Eligible(key, k, other) then
                local ol, orr, ot, ob = Edges(other.frame)
                if ol then
                    local vOverlap = (t > ob - THRESH) and (b < ot + THRESH)
                    local hOverlap = (r > ol - THRESH) and (l < orr + THRESH)
                    local cands = {
                        { side = "RIGHT",  d = math.abs(l - orr), ok = vOverlap },
                        { side = "LEFT",   d = math.abs(r - ol),  ok = vOverlap },
                        { side = "BOTTOM", d = math.abs(t - ob),  ok = hOverlap },
                        { side = "TOP",    d = math.abs(b - ot),  ok = hOverlap },
                    }
                    for _, c in ipairs(cands) do
                        if c.ok and c.d <= THRESH and (not bestD or c.d < bestD) then
                            best, bestD = { target = k, side = c.side }, c.d
                        end
                    end
                end
            end
        end
        return best
    end

    ------------------------------------------------------------
    -- 對齊：給定框的螢幕矩形，回「往右、往上各挪多少螢幕像素」才跟最近的邊貼齊。
    -- 兩軸各自獨立（只對齊 X 也很常見：上下堆疊的兩個視窗）；不要求另一軸有重疊，
    -- 所以隔著半個畫面也能對成同一欄——2px 的門檻夠緊，不會誤吸。
    -- 同 group 的框不算（自家已經錨在一起或有自家磁吸的，距離永遠是 0 會搶掉真目標）。
    ------------------------------------------------------------
    function S.AlignRect(key, l, r, t, b)
        local me = S.bars[key]
        if not me then return 0, 0 end
        local bestX, bestXd = 0, THRESH + 1
        local bestY, bestYd = 0, THRESH + 1
        local function tryX(d) local a = math.abs(d); if a < bestXd then bestXd, bestX = a, d end end
        local function tryY(d) local a = math.abs(d); if a < bestYd then bestYd, bestY = a, d end end

        for k, other in pairs(S.bars) do
            if Eligible(key, k, other) and not (me.group and me.group == other.group) then
                local ol, orr, ot, ob = Edges(other.frame)
                if ol then
                    tryX(ol - l)     -- 左貼左
                    tryX(orr - r)    -- 右貼右
                    tryX(orr - l)    -- 左貼右（並排）
                    tryX(ol - r)     -- 右貼左
                    tryY(ot - t)     -- 上貼上
                    tryY(ob - b)     -- 下貼下
                    tryY(ob - t)     -- 上貼下（堆疊）
                    tryY(ot - b)     -- 下貼上
                end
            end
        end
        if bestXd > THRESH then bestX = 0 end
        if bestYd > THRESH then bestY = 0 end
        return bestX, bestY
    end

    -- 把框挪到對齊的位置。位移量的單位是框**自己的** effective scale
    -- （SetPoint 的偏移就是這個單位，見 wow-setscale-offset-units）。
    local function Shift(f, dx, dy)
        if f.AdjustPointsOffset then
            f:AdjustPointsOffset(dx, dy)
            return
        end
        local pts = {}
        for i = 1, f:GetNumPoints() do pts[i] = { f:GetPoint(i) } end
        f:ClearAllPoints()
        for _, p in ipairs(pts) do
            f:SetPoint(p[1], p[2], p[3], (p[4] or 0) + dx, (p[5] or 0) + dy)
        end
    end

    function S.Nudge(key)
        local info = S.bars[key]
        if not info or not info.frame then return false end
        local f = info.frame
        local l, r, t, b = Edges(f)
        if not l then return false end
        local dx, dy = S.AlignRect(key, l, r, t, b)
        if dx == 0 and dy == 0 then return false end
        if InCombatLockdown() and f:IsProtected() then return false end
        local s = f:GetEffectiveScale()
        Shift(f, dx / s, dy / s)
        return true
    end

    -- 放手：可貼附的條先找條，找不到（或本來就不是條）就對齊
    function S.OnDragStop(key)
        local info = S.bars[key]
        if not info or not info.frame then return false end
        if info.attach then
            local best = AttachTarget(key)
            local _, db = SnapOf(key)
            if best and db then
                db.snapTo = best
                return Apply(key)
            end
        end
        return S.Nudge(key)
    end

    function S.Restore(key)
        return Apply(key)
    end

    _G.MiliUI_Snap = S
end

ns.Snap = _G.MiliUI_Snap
