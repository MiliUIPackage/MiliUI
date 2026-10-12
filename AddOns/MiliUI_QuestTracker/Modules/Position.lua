------------------------------------------------------------
-- 追蹤器的位置：由我們接管
--
-- ⚠ 先講清楚代價，因為這是這支插件唯一一處**故意跟暴雪搶**的地方。
--
-- ObjectiveTrackerFrame 是編輯模式的系統，位置存在版面設定裡，編輯模式會在
-- 「套用版面／進出編輯模式／重載」時把它貼回自己記的座標。我們用 SetPoint 搬走
-- 之後，那些時機都會被打回原位 —— 所以這裡的做法是**盯著那幾個時機再貼一次**。
-- 這是持續的拉鋸，不是一次性的設定；能少貼一次就少貼一次，所以：
--   * 沒拖過就完全不介入（`position.set` 是 false ⇒ 這支等於不存在）
--   * 編輯模式開著的時候不貼，讓玩家還是能用原生的拖曳
--   * 右鍵遮罩＝放手，把位置整個交還給編輯模式
--   * 玩家在編輯模式裡拖過（或換了一套追蹤器位置不同的版面）＝自動放手。
--     接管時記下編輯模式那份錨點的指紋，之後指紋變了就是編輯模式有了新主意，
--     我們不再貼。沒有這條的話，用編輯模式拖的人每次離開編輯模式／重載都會被
--     貼回很久以前用遮罩拖過的舊座標（2026-10-12 回報「還是跑掉」）
--
-- ⚠ 預設位置的追蹤器還被右側容器（RightManagedFrameContainer）列管著：它是容器的
-- 小孩，容器每次 Layout（首領框／競技場框出現、UIParent 重新顯示、追蹤器自己 OnShow
-- 觸發的 UpdateFrame）都會把小孩重新錨回容器裡 —— 容器又錨在右側快捷列左邊，
-- 所以玩家看到的是「位置一直跑掉、被往左頂一排快捷列寬」（2026-10-12）。
-- 只貼 SetPoint 擋不住，要把 parent 換成 UIParent 讓容器的 Layout 不再碰它；
-- 暴雪的 UpdateFrame 會再 SetParent 回去，掛 SetParent 下一幀再搬一次。
--
-- 垂直錨上緣：追蹤器的內容往下長，用 CENTER 位移的話任務一多整條就會自己往上飄。
-- 水平錨**離得近的那一邊**（point = "TOPLEFT"／"TOPRIGHT"，相對 UIParent 同一角）：
-- 早期一律存「距左緣 x」，追蹤器靠右放時 UIParent 寬度一變（UI 縮放、視窗大小）
-- 右邊就多出一截。編輯模式自己也是存貼近邊。
------------------------------------------------------------
local _, ns = ...

ns.Position = {}
local Pos = ns.Position
local T = ns.Tracker

local function Cfg() return ns.db and ns.db.position end

-- 第一次覆蓋之前先把暴雪原本的錨點抄下來，右鍵放手時才回得去。
-- 只存在記憶體：重載之後編輯模式自己會重新套用它那份，不需要我們記著
local originalPoints

local function CaptureOriginal(otf)
    if originalPoints then return end
    originalPoints = {}
    for i = 1, (otf:GetNumPoints() or 0) do
        originalPoints[i] = { otf:GetPoint(i) }
    end
end

-- UIParent 的四邊換算成追蹤器自己的座標單位（編輯模式可以單獨縮放追蹤器；
-- SetPoint 的位移與 GetLeft 的值都是追蹤器自己的單位，見 wow-setscale-offset-units）
local function ParentRect(otf)
    local pl, pr, pt = UIParent:GetLeft(), UIParent:GetRight(), UIParent:GetTop()
    if not (pl and pr and pt) then return nil end
    local k = (UIParent:GetEffectiveScale() or 1) / (otf:GetEffectiveScale() or 1)
    return pl * k, pr * k, pt * k
end

-- 量現在的位置，存成離得近那一邊的位移
local function Save(otf, c)
    local left, right, top = otf:GetLeft(), otf:GetRight(), otf:GetTop()
    local pl, pr, pt = ParentRect(otf)
    if not (left and right and top and pl) then return false end
    c.set = true
    c.editModeSig = EditModeSig(otf)
    if (left + right) / 2 > (pl + pr) / 2 then
        c.point, c.x = "TOPRIGHT", right - pr
    else
        c.point, c.x = "TOPLEFT", left - pl
    end
    c.y = top - pt
    return true
end

-- 編輯模式記的追蹤器位置（唯讀暴雪欄位，不寫）。沒初始化完回 nil
local function EditModeSig(otf)
    local info = otf.systemInfo
    local a = info and info.anchorInfo
    if not a then return nil end
    return table.concat({
        info.isInDefaultPosition and "default" or "custom",
        tostring(a.point), tostring(a.relativeTo), tostring(a.relativePoint),
        string.format("%.1f", tonumber(a.offsetX) or 0),
        string.format("%.1f", tonumber(a.offsetY) or 0),
    }, "|")
end

local function EditModeOpen()
    local emm = _G.EditModeManagerFrame
    return emm and emm:IsShown()
end

------------------------------------------------------------
-- 套用
------------------------------------------------------------
function Pos.Apply()
    local c = Cfg()
    if not c or not c.set then return end
    local otf = T.OTF()
    if not otf then return end
    -- 戰鬥中對受保護的追蹤器 SetPoint 會被靜默封鎖；PLAYER_REGEN_ENABLED 會補
    if not T.CanReposition() then return end
    -- 編輯模式開著就讓開：玩家這時候可能正在用原生方式拖，兩邊搶會變成拖不動
    if EditModeOpen() then return end

    -- 編輯模式那份位置換過了 ⇒ 玩家用編輯模式拖過，放手。
    -- 舊存檔沒有指紋：編輯模式已經有自訂位置就聽它的，還在預設位置才補記指紋繼續接管
    local sig = EditModeSig(otf)
    if sig then
        local stale = c.editModeSig and c.editModeSig ~= sig
        local legacyCustom = not c.editModeSig and sig:find("^custom")
        if stale or legacyCustom then
            c.set, c.point, c.x, c.y, c.editModeSig = false, nil, 0, 0, nil
            ns.Fire("PositionChanged")
            return
        end
        c.editModeSig = sig
    end

    CaptureOriginal(otf)
    -- 摺著的時候 parent 是隱藏容器，那是 Tracker.lua 的；只把它從右側容器手上拿走
    local container = _G.GetRightManagedFrameContainer and GetRightManagedFrameContainer()
    if container and otf:GetParent() == container then otf:SetParent(UIParent) end
    local point = c.point == "TOPRIGHT" and "TOPRIGHT" or "TOPLEFT"
    otf:ClearAllPoints()
    otf:SetPoint(point, UIParent, point, c.x, c.y)
    -- 舊格式（沒有 point，一律距左緣）就地換成貼近邊：這一刻的位置照舊，
    -- 之後換了寬度的角色才不會再被往左頂
    if not c.point then Save(otf, c) end
end

function Pos.IsOverridden()
    local c = Cfg()
    return c and c.set or false
end

------------------------------------------------------------
-- 放手：位置交還給編輯模式
------------------------------------------------------------
function Pos.Reset()
    local c = Cfg()
    if not c then return end
    c.set, c.point, c.x, c.y, c.editModeSig = false, nil, 0, 0, nil

    local otf = T.OTF()
    if not otf or not T.CanReposition() then return end
    -- 我們 ClearAllPoints 過，編輯模式那份錨點在這個 session 裡已經沒了，
    -- 所以要自己貼回抄下來的那組。抄不到（例如一載入就重設）就只能等重載，
    -- 編輯模式在載入時會自己套用
    if originalPoints and #originalPoints > 0 then
        -- Apply 把它從右側容器搬出來過；原本錨在容器上就放回去，容器下次 Layout 會接手
        local container = _G.GetRightManagedFrameContainer and GetRightManagedFrameContainer()
        if container and originalPoints[1][2] == container and otf:GetParent() == UIParent then
            otf:SetParent(container)
        end
        otf:ClearAllPoints()
        for _, pt in ipairs(originalPoints) do
            otf:SetPoint(unpack(pt))
        end
    end
    ns.Fire("PositionChanged")
end

------------------------------------------------------------
-- 拖曳
--
-- 自己算游標位移，不用 StartMoving —— 那支會走暴雪自己的搬移流程，而我們要的
-- 只是每幀貼一次 SetPoint，控制權留在自己手上比較好收尾。
------------------------------------------------------------
local dragState, dragDriver

local function EndDrag()
    if not dragState then return end
    dragState = nil
    if dragDriver then dragDriver:Hide() end
    -- 放手離套組其他框 2px 內就貼齊（Libs/MiliUISnap.lua）；追蹤器受保護時 lib 自己略過
    if ns.Snap then ns.Snap.OnDragStop("questTracker") end

    local otf = T.OTF()
    local c = Cfg()
    if otf and c then Save(otf, c) end
    ns.Fire("PositionChanged")
end
Pos.EndDrag = EndDrag

local function DragTick()
    local d = dragState
    if not d then return end
    -- 收不到 OnDragStop 的情況是有的（游標移出視窗、被別的框吃掉、進戰鬥），
    -- 自己確認一次，不然框會黏在游標上
    if not IsMouseButtonDown("LeftButton") or not T.CanReposition() then
        EndDrag()
        return
    end
    local otf = T.OTF()
    if not otf then EndDrag(); return end

    local scale = otf:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local dx, dy = cx / scale - d.cx, cy / scale - d.cy
    local pl, _, pt = ParentRect(otf)
    if not pl then return end
    otf:ClearAllPoints()
    otf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (d.left + dx) - pl, (d.top + dy) - pt)
end

function Pos.BeginDrag()
    local otf = T.OTF()
    if not otf or not T.CanReposition() then return end
    local left, top = otf:GetLeft(), otf:GetTop()
    if not (left and top) then return end
    CaptureOriginal(otf)

    local scale = otf:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    dragState = { cx = cx / scale, cy = cy / scale, left = left, top = top }

    if not dragDriver then
        dragDriver = CreateFrame("Frame")
        dragDriver:Hide()
        dragDriver:SetScript("OnUpdate", DragTick)
    end
    dragDriver:Show()
end

------------------------------------------------------------
-- 盯著會把位置打回去的那幾個時機
--
-- 每一個都要**延後**再貼：這些事件是在編輯模式套用版面「之前」派送的，
-- 當場貼會被它接著蓋掉。
------------------------------------------------------------
ns.RegisterCallback("Init", "position", function()
    -- 套組磁吸（Libs/MiliUISnap.lua）：註冊的是暴雪的追蹤器框本身——別的框對齊到它的邊，
    -- 它自己放手時也對齊別人。沒拖過（position.set 為 false）一樣可以當目標。
    if ns.Snap and T.OTF() then ns.Snap.Register("questTracker", T.OTF()) end
    Pos.Apply()

    -- 右側容器把追蹤器收回去的那一刻（ManagedFrameContainerMixin:UpdateFrame）。
    -- 不在 hook 裡直接動：暴雪的 UpdateFrame 接著還要 Layout，當場搬會重入它
    local container = _G.GetRightManagedFrameContainer and GetRightManagedFrameContainer()
    if container and T.OTF() then
        hooksecurefunc(T.OTF(), "SetParent", function(_, parent)
            if parent == container and Pos.IsOverridden() then
                T.Defer("positionReclaim", Pos.Apply)
            end
        end)
    end

    local evt = CreateFrame("Frame")
    for _, e in ipairs({
        "PLAYER_ENTERING_WORLD",
        "EDIT_MODE_LAYOUTS_UPDATED",
        "UI_SCALE_CHANGED",
        "DISPLAY_SIZE_CHANGED",
        "PLAYER_REGEN_ENABLED",
    }) do
        evt:RegisterEvent(e)
    end
    evt:SetScript("OnEvent", function()
        -- 貼兩次，間隔拉開。編輯模式套用版面的時機不保證在我們之前，第一次可能
        -- 白貼；第二次是保險。兩次都很便宜（一個 SetPoint），漏貼的代價卻是
        -- 「重載之後位置自己跑掉」這種最惹人厭的 bug
        T.Defer("positionApply",  Pos.Apply, 0.1)
        T.Defer("positionApply2", Pos.Apply, 0.6)
    end)
end)

ns.RegisterCallback("Apply", "position", function()
    Pos.Apply()
end)
