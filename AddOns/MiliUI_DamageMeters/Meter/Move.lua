------------------------------------------------------------
-- 移動、縮放、磁吸、編輯模式
--
-- 位置存的是「相對 UIParent 左上角的 TOPLEFT 位移」，不是編輯模式技能推薦的
-- CENTER 位移。理由：這是**可縮放**的視窗——錨 CENTER 的話從右下角拉大會讓整個
-- 框往左上漂，錨 TOPLEFT 才是「標題列不動、往右下長」的直覺行為。
--
-- 拖曳不用 StartMoving：磁吸要在拖的當下就吸住（放手才吸會看起來像跳一下），
-- 所以自己算游標位移。編輯模式那條路也走同一支 ApplySnap。
------------------------------------------------------------
local _, ns = ...

ns.Move = {}
local Move = ns.Move
local D = ns.Data

local GRIP_SIZE = 14

------------------------------------------------------------
-- 位置
------------------------------------------------------------
local function UIScale()
    return UIParent:GetEffectiveScale()
end

------------------------------------------------------------
-- 第一次擺放
--
-- 順序：
--   1. 沿用**暴雪內建傷害統計視窗**的位置 —— 玩家早就把它擺在自己習慣的地方了，
--      直接接手比任何我們猜的位置都準。
--   2. 找不到就靠左上角。
-- 刻意**不放畫面中央**：統計視窗擺中間會壓在施法條與角色身上，沒有人那樣用。
------------------------------------------------------------
local EDGE_MARGIN = 16
local STAGGER     = 24     -- 多視窗錯開量，避免疊成一坨

-- 第二個以後的視窗：貼在前一個的正下方（上緣＝前一個的下緣），
-- 也就是磁吸會吸出來的那個位置。前一個一定先建好（Rebuild 是 1..n 跑的），
-- 所以這裡讀得到它的座標。
local function StackBelowPrevious(W)
    local prev = ns.DB.Win(W.idx - 1)
    if not prev or type(prev.x) ~= "number" or type(prev.y) ~= "number" then return false end
    W.wdb.x = prev.x
    W.wdb.y = prev.y - (prev.height or 200)
    W.wdb.autoPlaced = prev.autoPlaced   -- 前一個還在等接手，這一個也跟著等
    return true
end

local function PlaceInitial(W)
    local wdb = W.wdb
    local x, y, matched = ns.Builtin.WindowOffset(W.idx)

    -- 只認「自己這一號」的內建視窗。第二個以後若只對到內建的第一個，
    -- 照抄就會疊在我們自己的第一個視窗上 —— 那種情況一律改成往下疊。
    if x and matched == W.idx then
        wdb.x, wdb.y = x, y
        wdb.autoPlaced = nil
        return
    end

    if W.idx > 1 and StackBelowPrevious(W) then return end

    if x then
        local off = (W.idx - 1) * STAGGER
        wdb.x, wdb.y = x + off, y - off
        wdb.autoPlaced = nil
        return
    end

    local off = (W.idx - 1) * STAGGER
    wdb.x = EDGE_MARGIN + off
    wdb.y = -(EDGE_MARGIN + off)
    -- 記號：這個位置是我們自己挑的、玩家還沒碰過。內建視窗晚一步才出現的話
    -- （Blizzard_DamageMeter 可能是需求載入），之後還可以再接手一次。
    wdb.autoPlaced = true
end

------------------------------------------------------------
-- 內建視窗晚一步才出現時，再接手一次。
-- 只在玩家還沒自己搬過（autoPlaced 還在）的視窗上動手。
-- 記號存在 SavedVariables 裡，所以這次沒接到，下次登入還會再試。
------------------------------------------------------------
function Move.RetryAdoptBlizzardPosition()
    if not ns.Windows then return end

    local pending = false
    ns.Windows.ForEach(function(W) if W.wdb.autoPlaced then pending = true end end)
    if not pending then return end

    -- 內建視窗還是沒出現：維持現在的暫時位置，下次登入再試（記號留在 SV）
    if not ns.Builtin.WindowOffset(1) then return end

    -- ⚠ 清掉座標整組**照編號順序**重跑一次 PlaceInitial，不要各自算各自的。
    --   第二個以後是貼在前一個下面的 —— 第一個一接手到新位置，
    --   後面那些就得跟著搬，否則會被留在原地變成兩個不相干的框。
    --   ForEach 是 1..n，順序剛好對。
    ns.Windows.ForEach(function(W)
        if not W.wdb.autoPlaced then return end
        W.wdb.x, W.wdb.y = nil, nil
        PlaceInitial(W)
        Move.ApplyPosition(W)
    end)
    ns.Fire("SettingsChanged")
end

function Move.ApplyPosition(W)
    local wdb, frame = W.wdb, W.frame
    if not frame then return end
    -- 拖曳／縮放進行中時，錨點屬於那個動作。這裡再 SetPoint 一次會跟它的
    -- 逐幀 SetPoint 打架（畫面上是視窗抽動）。等動作結束，EndDrag/EndResize
    -- 自己會把最終位置寫回去。
    if W._drag or W._resize then return end

    if type(wdb.x) ~= "number" or type(wdb.y) ~= "number" then
        PlaceInitial(W)
    end
    -- 夾回畫面內：換解析度或把視窗拖出去之後至少還抓得到標題列
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    if wdb.x < -(wdb.width or 300) + 40 then wdb.x = 0 end
    if wdb.x > pw - 40 then wdb.x = pw - 40 end
    if wdb.y > 0 then wdb.y = 0 end
    if wdb.y < -ph + 20 then wdb.y = -ph + 20 end

    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", wdb.x, wdb.y)
    frame:SetUserPlaced(false)
end

local function SavePosition(W)
    local frame = W.frame
    local l, t = frame:GetLeft(), frame:GetTop()
    local pl, pt = UIParent:GetLeft(), UIParent:GetTop()
    if not (l and t and pl and pt) then return end
    W.wdb.x = math.floor(l - pl + 0.5)
    W.wdb.y = math.floor(t - pt + 0.5)
    W.wdb.autoPlaced = nil       -- 玩家自己搬過了，不要再去接手內建視窗的位置
    frame:SetUserPlaced(false)
    ns.Fire("SettingsChanged")
end

------------------------------------------------------------
-- 磁吸
--
-- 「彼此磁吸」是設定項（style.snapEnabled），另外每個視窗可以單獨關掉
-- （選單裡的「這個視窗不磁吸」）——把一個視窗釘在固定位置、其他的隨便擺，
-- 是實際會用到的組合。
------------------------------------------------------------
local function SnapEnabled(W)
    local s = ns.DB.Style()
    if not s.snapEnabled then return false end
    if W.wdb.snapDisabled then return false end
    return true, s.snapThreshold or 6
end

-- 其他「可以被吸」的視窗：自己不算，隱藏的不算，單獨關掉磁吸的也不算
local function OtherFrames(W)
    local out = {}
    ns.Windows.ForEach(function(other)
        if other ~= W and other.frame and other.frame:IsShown() and not other.wdb.snapDisabled then
            out[#out + 1] = other.frame
        end
    end)
    return out
end

-- 兩軸各自獨立吸附：只對齊 X 也很常見（上下堆疊的兩個視窗）
local function ApplySnap(W, left, top, width, height)
    local ok, thresh = SnapEnabled(W)
    if not ok then return left, top end

    local right, bottom = left + width, top - height
    local bestX, bestXd = left, thresh + 1
    local bestY, bestYd = top,  thresh + 1

    local function tryX(candidate, dist)
        if dist < bestXd then bestXd = dist; bestX = candidate end
    end
    local function tryY(candidate, dist)
        if dist < bestYd then bestYd = dist; bestY = candidate end
    end

    for _, f in ipairs(OtherFrames(W)) do
        local oL, oR = f:GetLeft(), f:GetRight()
        local oT, oB = f:GetTop(), f:GetBottom()
        if oL and oR then
            tryX(oL,          math.abs(left  - oL))   -- 左貼左
            tryX(oR - width,  math.abs(right - oR))   -- 右貼右
            tryX(oR,          math.abs(left  - oR))   -- 左貼右（並排）
            tryX(oL - width,  math.abs(right - oL))   -- 右貼左
        end
        if oT and oB then
            tryY(oT,           math.abs(top    - oT)) -- 上貼上
            tryY(oB + height,  math.abs(bottom - oB)) -- 下貼下
            tryY(oB,           math.abs(top    - oB)) -- 上貼下（堆疊）
            tryY(oT + height,  math.abs(bottom - oT)) -- 下貼上
        end
    end

    if bestXd <= thresh then left = bestX end
    if bestYd <= thresh then top = bestY end
    return left, top
end

-- 縮放時吸附別的視窗的尺寸：兩個視窗一樣寬看起來才整齊
local function SnapSize(W, newW, newH)
    local ok, thresh = SnapEnabled(W)
    if not ok then return newW, newH end
    for _, f in ipairs(OtherFrames(W)) do
        local ow, oh = f:GetWidth(), f:GetHeight()
        if ow and math.abs(newW - ow) <= thresh then newW = ow end
        if oh and math.abs(newH - oh) <= thresh then newH = oh end
    end
    return newW, newH
end

------------------------------------------------------------
-- 手動拖曳
------------------------------------------------------------
local function BeginDrag(W)
    local frame = W.frame
    local scale = UIScale()
    local cx, cy = GetCursorPosition()
    W._drag = {
        cx = cx / scale, cy = cy / scale,
        left = frame:GetLeft(), top = frame:GetTop(),
    }
    W.dragFrame:Show()
end

local function EndDrag(W)
    if not W._drag then return end
    W._drag = nil
    W.dragFrame:Hide()
    SavePosition(W)
end

local function DragTick(W)
    local d = W._drag
    if not d then return end
    -- 有些情況收不到 OnMouseUp（滑鼠移出視窗、被別的 frame 吃掉），自己確認一次
    if not IsMouseButtonDown("LeftButton") then EndDrag(W); return end

    local scale = UIScale()
    local cx, cy = GetCursorPosition()
    local left = d.left + (cx / scale - d.cx)
    local top  = d.top  + (cy / scale - d.cy)

    local frame = W.frame
    left, top = ApplySnap(W, left, top, frame:GetWidth(), frame:GetHeight())

    local pl, pt = UIParent:GetLeft(), UIParent:GetTop()
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", left - pl, top - pt)
end

------------------------------------------------------------
-- 縮放
------------------------------------------------------------
local function BeginResize(W)
    local frame = W.frame
    local scale = UIScale()
    local cx, cy = GetCursorPosition()
    W._resize = {
        cx = cx / scale, cy = cy / scale,
        w = frame:GetWidth(), h = frame:GetHeight(),
    }
    W.dragFrame:Show()
end

local function EndResize(W)
    if not W._resize then return end
    W._resize = nil
    W.dragFrame:Hide()
    W.wdb.width  = math.floor(W.frame:GetWidth() + 0.5)
    W.wdb.height = math.floor(W.frame:GetHeight() + 0.5)
    W._barCacheKey = nil
    W._stickyCacheKey = nil
    W.Refresh()
    ns.Fire("SettingsChanged")
end

local function ResizeTick(W)
    local r = W._resize
    if not r then return end
    if not IsMouseButtonDown("LeftButton") then EndResize(W); return end

    local scale = UIScale()
    local cx, cy = GetCursorPosition()
    local newW = math.max(ns.Window.MIN_W, r.w + (cx / scale - r.cx))
    local newH = math.max(ns.Window.MIN_H, r.h - (cy / scale - r.cy))
    newW, newH = SnapSize(W, newW, newH)
    -- 錨點是 TOPLEFT，所以改尺寸不會動到左上角，不必重設位置
    W.frame:SetSize(newW, newH)
    -- 標題的可用寬度變了，跟著重新截斷（Rows.Render 不做這件事）
    ns.Window.FitTitle(W)
end

------------------------------------------------------------
-- 編輯模式
--
-- 不註冊真正的 Edit Mode system（那要碰暴雪內部、會污染），只是搭它的
-- 顯示/隱藏狀態順風車，並沿用它的藍色選取框當視覺。
------------------------------------------------------------
local _editing = false
local _editHooked = false

function Move.IsEditing() return _editing end

local function UpdateEditState()
    -- 開檔時就可能被呼叫到（EditModeManagerFrame 已經開著的情況），
    -- 而 Manager.lua 在 TOC 排在本檔之後 —— ns.Windows 那時還不存在
    if not ns.Windows then return end
    ns.Windows.ForEach(function(W)
        if not W.frame then return end
        if _editing then
            W.frame:Show()
            if W.editSelection then W.editSelection:ShowHighlighted() end
        else
            if W.editSelection then W.editSelection:Hide() end
            ns.Window.UpdateVisibility(W)
        end
    end)
end
Move.UpdateEditState = UpdateEditState

local function HookEditMode()
    if _editHooked then return end
    if not EditModeManagerFrame then return end
    _editHooked = true
    EditModeManagerFrame:HookScript("OnShow", function() _editing = true;  UpdateEditState() end)
    EditModeManagerFrame:HookScript("OnHide", function() _editing = false; UpdateEditState() end)
    if EditModeManagerFrame:IsShown() then _editing = true; UpdateEditState() end
end
Move.HookEditMode = HookEditMode

-- 三層掛勾：Blizzard_EditMode 是需求載入的，開檔時通常還不在
HookEditMode()
if not _editHooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)
end

------------------------------------------------------------
-- 掛到視窗上
------------------------------------------------------------
function Move.Setup(W)
    local frame, header = W.frame, W.header

    -- 拖曳／縮放共用一個 OnUpdate frame（一個視窗一個，只在動的時候顯示，
    -- 隱藏的 frame 不跑 OnUpdate）
    local drag = CreateFrame("Frame")
    drag:Hide()
    drag:SetScript("OnUpdate", function()
        if W._drag then DragTick(W) end
        if W._resize then ResizeTick(W) end
    end)
    W.dragFrame = drag

    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:HookScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        if W.wdb.locked and not _editing then return end
        BeginDrag(W)
    end)
    header:HookScript("OnMouseUp", function(_, button)
        if button ~= "LeftButton" then return end
        EndDrag(W)
    end)

    ------------------------------------------------------------
    -- 右下角縮放把手
    ------------------------------------------------------------
    local grip = CreateFrame("Button", nil, frame)
    grip:SetSize(GRIP_SIZE, GRIP_SIZE)
    grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    grip:SetFrameLevel(frame:GetFrameLevel() + 15)
    grip:RegisterForClicks("LeftButtonUp")
    local gripTex = grip:CreateTexture(nil, "OVERLAY")
    gripTex:SetAllPoints()
    gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTex:SetAlpha(0.35)
    grip:SetScript("OnEnter", function() gripTex:SetAlpha(0.9) end)
    grip:SetScript("OnLeave", function() gripTex:SetAlpha(0.35) end)
    grip:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        if W.wdb.locked and not _editing then return end
        BeginResize(W)
    end)
    grip:SetScript("OnMouseUp", function() EndResize(W) end)
    W.resizeGrip = grip

    ------------------------------------------------------------
    -- 編輯模式選取框
    ------------------------------------------------------------
    local ok, selection = pcall(CreateFrame, "Frame", nil, frame, "EditModeSystemSelectionTemplate")
    if ok and selection then
        selection:SetAllPoints(frame)
        selection:Hide()
        selection:RegisterForDrag("LeftButton")
        selection:SetScript("OnDragStart", function() BeginDrag(W) end)
        selection:SetScript("OnDragStop", function() EndDrag(W) end)
        selection.system = {
            GetSystemName = function()
                return ns.L["MiliUI Damage Meters"] .. " " .. W.idx
            end,
        }
        W.editSelection = selection
    end

    if _editing then
        frame:Show()
        if W.editSelection then W.editSelection:ShowHighlighted() end
    end
end

------------------------------------------------------------
-- 鎖定狀態改變：把手要跟著顯示/隱藏
------------------------------------------------------------
function Move.ApplyLock(W)
    if W.resizeGrip then
        W.resizeGrip:SetShown(not W.wdb.locked or _editing)
    end
end
