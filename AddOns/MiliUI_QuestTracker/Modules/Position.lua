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
--
-- 錨點用 TOPLEFT 相對 UIParent TOPLEFT：追蹤器的內容往下長，用 CENTER 位移
-- 的話任務一多整條就會自己往上飄。
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

    CaptureOriginal(otf)
    local pl, pt = UIParent:GetLeft(), UIParent:GetTop()
    if not (pl and pt) then return end
    otf:ClearAllPoints()
    otf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", c.x, c.y)
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
    c.set, c.x, c.y = false, 0, 0

    local otf = T.OTF()
    if not otf or not T.CanReposition() then return end
    -- 我們 ClearAllPoints 過，編輯模式那份錨點在這個 session 裡已經沒了，
    -- 所以要自己貼回抄下來的那組。抄不到（例如一載入就重設）就只能等重載，
    -- 編輯模式在載入時會自己套用
    if originalPoints and #originalPoints > 0 then
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

    local otf = T.OTF()
    local c = Cfg()
    if otf and c then
        local left, top = otf:GetLeft(), otf:GetTop()
        local pl, pt = UIParent:GetLeft(), UIParent:GetTop()
        if left and top and pl and pt then
            c.set = true
            c.x = left - pl
            c.y = top - pt
        end
    end
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

    local scale = UIParent:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    local dx, dy = cx / scale - d.cx, cy / scale - d.cy
    local pl, pt = UIParent:GetLeft(), UIParent:GetTop()
    if not (pl and pt) then return end
    otf:ClearAllPoints()
    otf:SetPoint("TOPLEFT", UIParent, "TOPLEFT", (d.left + dx) - pl, (d.top + dy) - pt)
end

function Pos.BeginDrag()
    local otf = T.OTF()
    if not otf or not T.CanReposition() then return end
    local left, top = otf:GetLeft(), otf:GetTop()
    if not (left and top) then return end
    CaptureOriginal(otf)

    local scale = UIParent:GetEffectiveScale()
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
    Pos.Apply()

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
