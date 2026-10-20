------------------------------------------------------------
-- 收合：視窗只剩標題列
--
-- 每視窗 wdb.collapsed（存檔）＋ W._collapsedView（畫面上實際套用的狀態）。
-- 兩者不一定相同：編輯模式或設定視窗開著時一律以展開狀態顯示（跟顯示條件同一條規矩，
-- 玩家要看得到自己在調什麼），離開後恢復。
--
-- 做法：**定位框（W.anchor）大小與位置完全不動**，只把內容框（W.frame）改錨成
-- 「只剩標題列那一截」——正常方向貼定位框上緣，反轉顯示（標題列在下面）貼下緣。
--   * 內容框不是保護框（見 Window.lua 的 Win.SyncAnchor 上方），所以戰鬥中也能收能放。
--   * 騰出來的那一塊只剩不吃滑鼠的定位框 ⇒ 點得到後面的怪。
--   * 磁吸在下面的其他框（另一個統計視窗、爆發藥水列）**不會跟著移動** —— 刻意的：
--     戰鬥中排版不跳，而且那些框可能本來就是保護框，戰鬥中想移也移不了。
--
-- 背景與邊框跟著內容框變成只包標題列（borderTarget 是 SetAllPoints 在內容框上的）；
-- 標題列以外的東西（捲動區、長條、釘住自己那列、右欄、首頁、展開頁、縮放把手、
-- 標題列下緣的分隔線）全部藏起來。W.Refresh 收合時早退，展開那一刻作廢版面快取補畫一次
-- （同 Win.UpdateVisibility「由隱藏轉顯示要補畫」的模式）。
------------------------------------------------------------
local _, ns = ...

ns.Collapse = {}
local Collapse = ns.Collapse
local D = ns.Data

-- 編輯模式／設定視窗開著時強制展開
local function Forced()
    return ns.Move.IsEditing() or ns._optionsOpen
end

local function Effective(W)
    return (W.wdb.collapsed and not Forced()) and true or false
end

------------------------------------------------------------
-- 版面
------------------------------------------------------------
-- entering：這一次是從展開變成收合（要先收掉首頁／展開頁／提示）。
-- 不是的話（ApplyStyle 重套樣式時的強制重排）只重貼錨點、重新藏一次 ——
-- ApplyOrientation 剛剛把背景與分隔線貼回去、重新顯示過了。
local function LayoutCollapsed(W, entering)
    if entering then
        -- 順序：_collapsedView 在呼叫端已經設好 ⇒ 下面這幾支的 W.Refresh 都會早退，
        -- Home.Hide 的 SetListShown(true) 也會被 Win.SetListShown 擋成 false
        ns.Breakdown.Close(W)
        ns.Home.Hide(W)
        ns.Tooltip.HideFor(W)
    end

    local s = ns.DB.Style()
    local O = ns.Window.Orient(W)
    local f, a = W.frame, W.anchor
    f:ClearAllPoints()
    f:SetPoint(O.topL, a, O.topL, 0, 0)
    f:SetPoint(O.topR, a, O.topR, 0, 0)
    f:SetHeight(D.Px(s.hdrHeight or 22))

    f.bg:Hide()
    W.header.bottomBorder:Hide()
    ns.Window.SetListShown(W, false)
    ns.Move.ApplyLock(W)        -- 縮放把手：收合中不顯示（ApplyLock 看 _collapsedView）
end

-- leaving：這一次是從收合變回展開（要把藏起來的東西放回去並補畫）
local function LayoutExpanded(W, leaving)
    local f = W.frame
    f:ClearAllPoints()
    f:SetAllPoints(W.anchor)
    if not leaving then return end

    local s = ns.DB.Style()
    -- 收合時首頁一定是關著的（進收合時收掉了），背景直接放回去
    f.bg:Show()
    W.header.bottomBorder:SetShown((s.hdrBottomBorderSize or 0) > 0)
    ns.Window.SetListShown(W, true)
    ns.Move.ApplyLock(W)
    -- 長條在收合期間沒畫過（W.Refresh 早退），版面快取作廢、整批重排一次
    W._barCacheKey = nil
    W.Refresh()
end

------------------------------------------------------------
-- 按鈕圖示：展開中顯示「收合」（−）、收合中顯示「展開」（+）。−／+ 上下對稱，
-- 反轉顯示時不必鏡射。
-- 看的是**存檔的** collapsed，不是畫面上的：設定視窗開著時強制展開，
-- 這時按下去改的是存檔，提示第二行會說明（Collapse.Note）。
------------------------------------------------------------
function Collapse.UpdateIcon(W)
    local btn = W.collapseBtn
    if not btn then return end
    btn.key = W.wdb.collapsed and "expand" or "collapse"
    btn.icon:SetTexture(ns.Window.BTN_TEX[btn.key])
end

-- force：狀態沒變也重排一次（Win.ApplyStyle 重貼過錨點之後叫）
function Collapse.Apply(W, force)
    if not W or not W.frame or not W.anchor then return end
    local want = Effective(W)
    local prev = W._collapsedView
    if want == prev and not force then return end
    W._collapsedView = want
    if want then
        LayoutCollapsed(W, prev ~= true)
    else
        LayoutExpanded(W, prev == true)
    end
    Collapse.UpdateIcon(W)
end

------------------------------------------------------------
-- 開關的唯一入口（標題列按鈕、右鍵選單、收合中點標題）
------------------------------------------------------------
function Collapse.Set(W, on)
    W.wdb.collapsed = on and true or false
    Collapse.Apply(W)
    Collapse.UpdateIcon(W)   -- 強制展開中 Apply 不會動，但存檔變了，圖示要跟著換
end

function Collapse.Toggle(W)
    Collapse.Set(W, not W.wdb.collapsed)
end

-- 按鈕提示的第二行：存檔是收合、畫面卻是展開的時候講為什麼
function Collapse.Note(W)
    if W.wdb.collapsed and Forced() then
        return ns.L["Shown expanded while Edit Mode or the settings panel is open."]
    end
    return nil
end
