------------------------------------------------------------
-- MiliUISnap：獨立插件的條互相磁吸
--
-- 兩支以上各自獨立的插件（焦點助手的標記列、爆發藥水列…）要能貼在一起、
-- 而且拖前面那條時後面那條跟著走。做法不是每幀搬後面那條，而是**把後面那條
-- 直接錨在前面那條上**：引擎自己會帶著走，零成本、零時序問題。
--
-- 角色：拖過去貼上的那條是「跟隨者」（它的 db.snapTo 記著吸在誰的哪一邊），
-- 被貼的那條是「前面那條」。拖前面那條 → 兩條一起動（錨點的天性）；
-- 拖跟隨者 → 先脫離（StartMoving 本來就會把錨點改回 UIParent），放手時離得近
-- 就再吸回去。
--
-- 這是 vendor 複製：每支插件帶一份，全域 MiliUI_Snap 先到先贏、版本高的蓋掉舊的
-- （bars 註冊表保留）。跟 MiliUI_MenuEntries 同一個理由——插件之間沒有相依宣告，
-- 玩家可能只裝其中一支。改這支要**每份都改**。
--
-- 各插件要做的四件事（見 MiliUI_Focus/Modules/MarkBar.lua）：
--   Register(key, frame, { db = fn })  建好框之後
--   OnDragStart(key)                   StartMoving 之前
--   OnDragStop(key)                    StopMovingOrSizing 之後、存座標之前
--   Restore(key)                       每次照存檔擺位置之後；IsAttached(key) 為真時
--                                      存座標不要再把錨點改回 UIParent
------------------------------------------------------------
local _, ns = ...

local VERSION = 1
local GAP     = 0   -- 貼上之後貼死，沒有間距（使用者指定）
local THRESH  = 2   -- 放手時離 2px 以內才吸（使用者指定）；同軸重疊的容差也用它

local S = _G.MiliUI_Snap
if not S or (S.version or 0) < VERSION then
    S = S or {}
    S.version = VERSION
    S.bars = S.bars or {}

    local function Edges(f)
        return f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
    end

    local function SnapOf(key)
        local info = S.bars[key]
        local db = info and info.db and info.db()
        return db and db.snapTo or nil, db
    end

    -- `target` 是不是（直接或間接）吸在 `key` 身上：避免 A 吸 B、B 又吸 A
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
        S.bars[key] = { frame = frame, db = opts and opts.db, gap = opts and opts.gap }
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

    -- 放手：找最近的可吸邊。同一軸要有重疊（差一點也算），距離在 THRESH 內
    function S.OnDragStop(key)
        local info = S.bars[key]
        if not info or not info.frame then return false end
        local l, r, t, b = Edges(info.frame)
        if not l then return false end

        local best, bestD
        for k, other in pairs(S.bars) do
            if k ~= key and other.frame and other.frame:IsShown() and not HangsUnder(key, k) then
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

        local _, db = SnapOf(key)
        if not best or not db then return false end
        db.snapTo = best
        return Apply(key)
    end

    function S.Restore(key)
        return Apply(key)
    end

    _G.MiliUI_Snap = S
end

ns.Snap = _G.MiliUI_Snap
