------------------------------------------------------------
-- MiliUISnap：套組各插件的框互相磁吸
--
-- 兩種磁吸，放手時在 2 **螢幕像素**內才發生（使用者指定「相差 2px 才吸」）：
--
--   1. 貼附（attach）——標記列、爆發藥水列、傷害統計視窗（使用者指定：後吸上去的
--      以前者為主體，拉動主體一起動）。拖過去貼上的是「跟隨者」（db.snapTo 記著吸在
--      誰的哪一邊），做法不是每幀搬它，而是**直接錨在主體上**：引擎自己會帶著走，
--      零成本、零時序。拖主體 → 整串一起動；拖跟隨者 → 先脫離（StartMoving 本來就會
--      把錨點改回 UIParent），放手時離得近就再吸回去。貼上後貼死（0px）。
--      接觸邊以外的那一軸：上緣（或左緣）2px 內就對齊上緣，下緣（右緣）2px 內就對齊
--      下緣，都不是就**保留放手時的錯位**（snapTo.align / offset）——主體縮放時，
--      對齊的那條邊跟著不動。只在**兩邊都** Register 時給 attach = true 才會貼附。
--
--   2. 對齊（align）——其他框：資訊列、小地圖、任務追蹤器、聊天列，以及它們跟可貼附
--      的框之間。放手時找最近的邊（左貼左／右貼右／左貼右／右貼左，上下同理；
--      兩軸各自獨立，所以「只對齊 X」的上下堆疊也吸得到），把框**挪過去貼齊**就
--      結束——不改錨點、不跟隨、不存任何東西，呼叫端照常讀框的現況存座標。
--      為什麼這幾個不貼附：尺寸會自己變（追蹤器隨任務數長高、資訊列的寬跟著文字走、
--      小地圖可縮放），錨在它們身上的東西會跟著漂。
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
--       label   = "…"   給玩家看的名字（設定頁要說「跟著誰」時用）
--       fade    = { db = fn, active = fn }   見下面「滑鼠淡出」
--   ApplyFade(key) / RefreshFade()  淡出設定改過之後叫一次（立刻重算，不必等輪詢）
--   FadeMaster(key)              回 (主體 key, 主體 label)；沒吸在別人身上就是自己
--
-- 滑鼠淡出（fade）
--   滑鼠不在上面就把整條淡到玩家設定的透明度。opts.fade：
--       db     = fn → 回一張有 `fadeEnabled`（布林）與 `fadeAlpha`（0~1）的表
--       active = fn → 回 true 代表「現在不准淡」（例如選單正開著）
--   ⚠ **吸在一起的條算同一群**：設定一律讀鏈的**根**（也就是被吸的那個主體，
--     跟拖動時「主體帶著跟隨者走」是同一個主從關係），而且滑鼠碰到群裡任何一條，
--     整群一起亮起／一起淡出。使用者指定：淡出與顯示兩件事都要同步。
--   ⚠ 用 `IsMouseOver()` 輪詢，不用 OnEnter/OnLeave：條上面鋪滿了握把與按鈕，
--     子框會把滑鼠事件吃掉，父框的 OnEnter/OnLeave 根本不對稱（移動快就卡住）。
--     IsMouseOver 問的是幾何矩形，跟誰吃掉事件無關。
--   OnDragStart(key)             真的開始拖之前（貼附的要先脫離；點一下不算拖）
--   OnDragStop(key)              StopMovingOrSizing 之後、存座標之前：先試貼附，再試對齊
--   Restore(key)                 每次照存檔擺位置之後（貼附的重新錨回主體）；
--                                IsAttached(key) 為真時存座標不要再把錨點改回 UIParent
--   AlignRect(key, l, r, t, b)   拖曳中就想吸的（傷害統計）自己丟螢幕座標進來，
--                                回 (dx, dy) 螢幕像素；沒得吸回 0, 0
--   HangsUnder(key, other)       other 是不是（直接或間接）吸在 key 身上——拖曳中自家
--                                的磁吸要把跟隨者排除，它們跟著主體走、距離永遠是 0
--
-- key 是存檔內容（貼附的 db.snapTo.target），改名等於把玩家吸好的組合拆掉。
------------------------------------------------------------
local _, ns = ...

local VERSION = 4
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
    function S.HangsUnder(key, target)
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
    local HangsUnder = S.HangsUnder

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
        local side = st.side
        -- 另一軸的對齊：v1 的存檔沒有 align，等於上緣／左緣；FREE 用 offset
        -- （單位是跟隨者自己的 scale，SetPoint 偏移就是這個單位）
        local align = st.align or ((side == "RIGHT" or side == "LEFT") and "TOP" or "LEFT")
        local off = (align == "FREE") and (st.offset or 0) or 0
        local tf = t.frame
        f:ClearAllPoints()
        if side == "RIGHT" then
            if align == "BOTTOM" then f:SetPoint("BOTTOMLEFT", tf, "BOTTOMRIGHT", g, 0)
            else                      f:SetPoint("TOPLEFT",    tf, "TOPRIGHT",    g, off) end
        elseif side == "LEFT" then
            if align == "BOTTOM" then f:SetPoint("BOTTOMRIGHT", tf, "BOTTOMLEFT", -g, 0)
            else                      f:SetPoint("TOPRIGHT",    tf, "TOPLEFT",    -g, off) end
        elseif side == "BOTTOM" then
            if align == "RIGHT" then  f:SetPoint("TOPRIGHT", tf, "BOTTOMRIGHT", 0,   -g)
            else                      f:SetPoint("TOPLEFT",  tf, "BOTTOMLEFT",  off, -g) end
        elseif side == "TOP" then
            if align == "RIGHT" then  f:SetPoint("BOTTOMRIGHT", tf, "TOPRIGHT", 0,   g)
            else                      f:SetPoint("BOTTOMLEFT",  tf, "TOPLEFT",  off, g) end
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
            label   = opts.label,
            fade    = opts.fade,
        }
        -- 別條可能早就記著要吸在我身上，只是我那時還沒載入
        for k in pairs(S.bars) do
            local st = SnapOf(k)
            if k ~= key and st and st.target == key then Apply(k) end
        end
        if opts.fade then S.RefreshFade() end
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
        if not best then return nil end

        -- 接觸邊以外那一軸怎麼對齊：哪條邊在 2px 內就對哪條，都不是就保留錯位
        local ol, orr, ot, ob = Edges(S.bars[best.target].frame)
        local s = info.frame:GetEffectiveScale()
        if best.side == "RIGHT" or best.side == "LEFT" then
            if math.abs(t - ot) <= THRESH then best.align = "TOP"
            elseif math.abs(b - ob) <= THRESH then best.align = "BOTTOM"
            else best.align, best.offset = "FREE", (t - ot) / s end
        else
            if math.abs(l - ol) <= THRESH then best.align = "LEFT"
            elseif math.abs(r - orr) <= THRESH then best.align = "RIGHT"
            else best.align, best.offset = "FREE", (l - ol) / s end
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

    ------------------------------------------------------------
    -- 滑鼠淡出
    --
    -- 一「群」＝一條磁吸鏈。鏈的根（也就是被吸的主體）握著設定，群裡任何一條被
    -- 滑鼠碰到，**整群一起亮起**；都沒碰到就整群一起淡下去。使用者指定：
    -- 有磁吸時以主體的設定為準，而且淡出與顯示兩件事一起同步。
    --
    -- ⚠ 靠 IsMouseOver 輪詢，不靠 OnEnter/OnLeave —— 條上鋪滿握把與按鈕，
    --   子框會把滑鼠事件吃掉，父框收不到對稱的進出（見 notes 的
    --   wow-child-frame-steals-mouse-focus）。IsMouseOver 問的是幾何矩形。
    -- ⚠ SetAlpha 不是保護動作，戰鬥中照樣可以叫 —— 這也是這個功能只用 alpha、
    --   不用 Show/Hide 的原因（條上掛著保護子按鈕，戰鬥中藏不掉）。
    ------------------------------------------------------------
    local FADE_POLL = 0.1     -- 滑鼠位置沒有事件可訂閱，只能輪詢
    local FADE_TIME = 0.15    -- 淡入／淡出走完的秒數；直接跳 alpha 是「閃一下」不是淡出
    local FADE_DEFAULT = 0.3  -- db 沒給 fadeAlpha 時的退路

    -- 群的頭：一路往「我吸在誰身上」爬。
    -- ⚠ 目標沒註冊（那支插件沒裝）**或它自己不支援淡出**就停在這裡 —— 再往上爬
    --   也讀不到設定，而一個沒有淡出設定的框不該當群主。seen 防環（存檔裡殘留
    --   A 吸 B、B 又吸 A 的殘局）。
    local function FadeRoot(key)
        local seen, cur = {}, key
        while not seen[cur] do
            seen[cur] = true
            local st = SnapOf(cur)
            local t = st and st.target
            local ti = t and S.bars[t]
            if not ti or not ti.fade then return cur end
            cur = t
        end
        return cur
    end

    -- 設定頁要顯示「淡出跟著誰」用：回 (主體 key, 主體的顯示名)
    function S.FadeMaster(key)
        local root = FadeRoot(key)
        local info = S.bars[root]
        return root, (info and info.label) or root
    end

    -- 設定一律讀群主那份（FadeRoot 保證它一定有 fade 註冊）
    local function FadeSettings(root)
        local info = S.bars[root]
        local fade = info and info.fade
        local db = fade and fade.db and fade.db()
        if not db then return false, 1 end
        local a = tonumber(db.fadeAlpha) or FADE_DEFAULT
        if a < 0 then a = 0 elseif a > 1 then a = 1 end
        return db.fadeEnabled == true, a
    end

    -- ⚠ 這四張表放檔案層級、每輪 wipe 重用：輪詢一秒十次，寫成 `{}` 就是一秒
    --   四十張垃圾表。
    local rootOf, onByRoot, alphaByRoot, hoverByRoot = {}, {}, {}, {}
    local fadeAcc, fadeMoving = 0, false

    -- 一輪輪詢：算出每一群現在該是什麼透明度，寫進各條的 fadeTarget
    local function FadePoll()
        wipe(rootOf); wipe(onByRoot); wipe(alphaByRoot); wipe(hoverByRoot)
        -- 分群，順便把群主的設定讀出來（每群只讀一次）
        for key, info in pairs(S.bars) do
            if info.fade and info.frame then
                local root = FadeRoot(key)
                rootOf[key] = root
                if onByRoot[root] == nil then
                    onByRoot[root], alphaByRoot[root] = FadeSettings(root)
                    hoverByRoot[root] = false
                end
            end
        end
        -- 問滑鼠。只問「真的會淡」的群 —— 沒開淡出的群答案用不到
        for key, root in pairs(rootOf) do
            if onByRoot[root] and not hoverByRoot[root] then
                local info = S.bars[key]
                local hit = info.frame:IsShown() and info.frame:IsMouseOver()
                -- active：條自己說「現在不准淡」（例如標記選單正開著，它彈在條的
                -- 上方、不在條的矩形裡）
                if not hit and info.fade.active then hit = info.fade.active() and true or false end
                if hit then hoverByRoot[root] = true end
            end
        end
        -- 寫目標值。群裡每一條拿到的是同一個數字 ⇒ 淡出與亮起天然同步
        for key, root in pairs(rootOf) do
            local info = S.bars[key]
            local target = (not onByRoot[root] or hoverByRoot[root]) and 1 or alphaByRoot[root]
            if info.fadeTarget ~= target then
                info.fadeTarget = target
                fadeMoving = true
            end
        end
    end

    -- 每幀往目標推一格；全部到位就把 fadeMoving 放掉，OnUpdate 回到只輪詢滑鼠
    local function FadeStep(elapsed)
        local moving = false
        for _, info in pairs(S.bars) do
            local target = info.fadeTarget
            if target and info.fade and info.frame then
                local cur = info.fadeCur or info.frame:GetAlpha() or 1
                if cur ~= target then
                    local step = elapsed / FADE_TIME
                    if cur < target then
                        cur = math.min(target, cur + step)
                    else
                        cur = math.max(target, cur - step)
                    end
                    if cur ~= target then moving = true end
                    info.fadeCur = cur
                    info.frame:SetAlpha(cur)
                end
            end
        end
        fadeMoving = moving
    end

    -- ⚠ ticker 跨版本沿用同一顆：WoW 的 frame 刪不掉，每次版本蓋版新建一顆就是
    --   永久多一顆在跑（腳本改指到新的閉包，舊的那顆才會停）。
    S.fadeTicker = S.fadeTicker or CreateFrame("Frame")
    S.fadeTicker:Hide()        -- 先關著，等 RefreshFade 看有沒有人註冊淡出
    S.fadeTicker:SetScript("OnUpdate", function(_, elapsed)
        fadeAcc = fadeAcc + elapsed
        if fadeAcc >= FADE_POLL then
            fadeAcc = 0
            FadePoll()
        end
        -- 到位之後 fadeMoving 會被放掉 ⇒ 平常每幀只有上面那個加法
        if fadeMoving then FadeStep(elapsed) end
    end)

    -- 設定改過（或有新的條註冊進來）就叫一次：立刻重算，不必等下一次輪詢。
    -- 沒有任何一條註冊淡出時整顆 ticker 收掉（隱藏的框不跑 OnUpdate），成本歸零。
    function S.RefreshFade()
        local any = false
        for _, info in pairs(S.bars) do
            if info.fade then any = true break end
        end
        S.fadeTicker:SetShown(any)
        if any then
            fadeAcc = 0
            FadePoll()
        end
    end
    S.ApplyFade = S.RefreshFade

    _G.MiliUI_Snap = S
end

ns.Snap = _G.MiliUI_Snap
