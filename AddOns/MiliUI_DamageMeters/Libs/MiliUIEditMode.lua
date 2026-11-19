------------------------------------------------------------
-- MiliUIEditMode：自訂框在暴雪編輯模式裡可拖曳
--
-- `wow-editmode-draggable` 技能的配方收成一份：套組每支插件原本各抄一份「借
-- EditModeSystemSelectionTemplate 當選取框、搭編輯模式進出訊號順風車、拖曳與存檔自己
-- 來」，而 2026-08-29／09-17／10-02 踩到的地雷（OnMouseDown 要 no-op、StartMoving 在保護框
-- 上是死的、三重訊號、戰鬥中進出編輯模式）每一份都得各補一次。這裡是那些規則的唯一 source。
--
-- 不註冊真的編輯模式系統（那要碰暴雪內部、會污染）：不會出現在暴雪的版面清單，也因此無污染。
--
-- 這是 vendor 複製：每支插件帶一份（`<插件>/Libs/MiliUIEditMode.lua`），掛在自己的
-- `ns.MiliUIEditMode` 上、各自掛暴雪的勾，不寫任何全域。唯一 source 在 MiliUI/Libs/MiliUIEditMode/，
-- 改完跑 `python3 .claude/scripts/sync-widgets.py` 鋪到各插件。契約與理由見同目錄的 README.md。
--
-- 用法（最小）：
--   local EM = ns.MiliUIEditMode
--   local mover = EM.Attach(frame, {
--       name = "我的條",                                -- 選取框上的標籤
--       save = function(f) db.x, db.y = EM.CenterOffset(f); Reposition() end,
--       restore = Reposition,                            -- 拖曳被中斷（進戰鬥）時照存檔放回
--       onChange = function(active) ... end,            -- 進出編輯模式（下一幀）：給樣板內容、Show／Hide 框
--   })
--
-- 規矩（每條都是撞過的，詳見 README）：
--   * 選取框**開檔就建**、包 pcall、建不出來自畫藍框頂著；模板的 OnMouseDown 換掉（它會呼叫
--     EditModeManagerFrame:SelectSystem(self.parent)，自訂框不是真系統，讓它跑＝整條選取流程帶著
--     本插件的 taint 掃過每一個已註冊系統，當下靜默、戰鬥中快捷列才爆）。
--   * 拖曳**手動算**（游標差值＋每幀 SetPoint），不用 StartMoving——保護框＋編輯模式那條路它是死的。
--   * 進出訊號三重（管理視窗 OnShow/OnHide、EnterEditMode/ExitEditMode 後掛勾、EventRegistry），
--     處理器只改旗標，派送**延一幀**（離開暴雪的執行堆疊）。
--   * 編輯模式**不會被戰鬥關掉**：進出處理器可能在鎖定中跑。碰選取框一律走 Write（宿主是保護框
--     且在戰鬥中就記到 PLAYER_REGEN_ENABLED）；進戰鬥那一刻（PLAYER_REGEN_DISABLED，鎖定還沒
--     生效）同步收掉進行中的拖曳、框照存檔放回、不寫 db。
--   * 吸附參數一律讀暴雪的（吸附開關、格線間距、格線看不看得到），Shift 按著一律不吸；
--     放手時再走 MiliUISnap（opts.snapKey）跟套組其他框對齊。
------------------------------------------------------------
local _, ns = ...

local M = {}
ns.MiliUIEditMode = M
M.VERSION = 1

local type, pairs, ipairs, pcall, xpcall, tonumber, tostring = type, pairs, ipairs, pcall, xpcall, tonumber, tostring
local floor, abs = math.floor, math.abs

------------------------------------------------------------
-- 純函式（離線可測，Tests/MiliUIEditMode_test.lua）
------------------------------------------------------------
-- 錨點在矩形上的位置：x 由左到右 0～1、y 由下到上 0～1
local FRAC = {
    TOPLEFT    = { 0,   1   }, TOP    = { 0.5, 1   }, TOPRIGHT    = { 1, 1   },
    LEFT       = { 0,   0.5 }, CENTER = { 0.5, 0.5 }, RIGHT       = { 1, 0.5 },
    BOTTOMLEFT = { 0,   0   }, BOTTOM = { 0.5, 0   }, BOTTOMRIGHT = { 1, 0   },
}
M.POINT_FRAC = FRAC

function M.PointXY(point, l, r, t, b)
    local f = FRAC[point] or FRAC.CENTER
    return l + (r - l) * f[1], b + (t - b) * f[2]
end

-- 存檔用：四捨五入到整數（套用時各插件再像素對齊）
function M.Round(v)
    return floor(v + 0.5)
end

function M.SnapValue(v, step)
    if not step or step <= 0 then return v end
    return floor(v / step + 0.5) * step
end

-- 吸附範圍：離格線 SNAP_RANGE（UIParent 座標）以內才吸。固定值、不隨格距（格距 100 時
-- 用比例會變成「很遠就飄過去」）
M.SNAP_RANGE = 4

-- 只吸錨點那一邊：anchorPoint 那一點（相對原點 ox, oy）離格線夠近才吸，兩軸各自判斷，
-- 回傳整個矩形要挪的量
function M.SnapDelta(anchorPoint, l, r, t, b, ox, oy, step)
    if not step or step <= 0 then return 0, 0 end
    local ax, ay = M.PointXY(anchorPoint, l, r, t, b)
    local rx, ry = ax - ox, ay - oy
    local range = M.SNAP_RANGE
    local dx, dy = M.SnapValue(rx, step) - rx, M.SnapValue(ry, step) - ry
    if dx > range or dx < -range then dx = 0 end
    if dy > range or dy < -range then dy = 0 end
    return dx, dy
end

-- rect／parent = { l, r, t, b }：rect 的中心相對 parent 中心的偏移（四捨五入）。
-- 位置存成相對 UIParent CENTER 的偏移，跟解析度／UI 縮放脫鉤
function M.CenterOffsetOf(rect, parent)
    local cx, cy = M.PointXY("CENTER", rect[1], rect[2], rect[3], rect[4])
    local px, py = M.PointXY("CENTER", parent[1], parent[2], parent[3], parent[4])
    return M.Round(cx - px), M.Round(cy - py)
end

------------------------------------------------------------
-- 框的幾何（讀不到、秘密值一律回 nil）
------------------------------------------------------------
local issecretvalue = issecretvalue

local function Plain(v)
    if type(v) ~= "number" then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

function M.RectOf(frame)
    if not frame then return nil end
    local ok, l, r, t, b = pcall(function()
        return frame:GetLeft(), frame:GetRight(), frame:GetTop(), frame:GetBottom()
    end)
    if not ok then return nil end
    l, r, t, b = Plain(l), Plain(r), Plain(t), Plain(b)
    if not (l and r and t and b) then return nil end
    return { l, r, t, b }
end

-- 框的中心相對 UIParent 中心的偏移（整數）；讀不到回 nil
function M.CenterOffset(frame)
    local rect, parent = M.RectOf(frame), M.RectOf(UIParent)
    if not (rect and parent) then return nil end
    return M.CenterOffsetOf(rect, parent)
end

-- 照 CENTER 偏移擺回去（x／y 不是數字就 0）
function M.ApplyCenter(frame, x, y)
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "CENTER", tonumber(x) or 0, tonumber(y) or 0)
end

------------------------------------------------------------
-- 錯誤回報、延一幀、戰鬥閘
------------------------------------------------------------
local function Report(err)
    local handler = geterrorhandler and geterrorhandler()
    if handler then handler(err) else print("MiliUIEditMode: " .. tostring(err)) end
end

local function Safe(fn)
    return function(...) return xpcall(fn, Report, ...) end
end

-- 下一幀（離開暴雪的執行堆疊）
function M.Defer(fn)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, Safe(fn))
    else
        Safe(fn)()
    end
end

local function InCombat()
    return InCombatLockdown and InCombatLockdown() or false
end

local function IsProtected(frame)
    if not frame or type(frame.IsProtected) ~= "function" then return false end
    local ok, v = pcall(frame.IsProtected, frame)
    return ok and v == true
end

-- 脫戰才跑的佇列（進戰鬥中對保護框的 Show／Hide／SetPoint 會被封鎖）
local pending = {}

local function FlushPending()
    if #pending == 0 then return end
    local list = pending
    pending = {}
    for _, fn in ipairs(list) do Safe(fn)() end
end

-- 碰 frame（或它的子孫）的動作：不在戰鬥就當場跑；戰鬥中而 frame 受保護就記到脫戰；
-- 戰鬥中但 frame 不受保護照跑（普通框戰鬥中怎麼動都合法）
function M.Write(frame, fn)
    if not InCombat() or not IsProtected(frame) then
        Safe(fn)()
        return true
    end
    pending[#pending + 1] = fn
    return false
end

------------------------------------------------------------
-- 暴雪的狀態（唯讀；全部 pcall——編輯模式戰鬥中也能進出，讀狀態本身沒有限制）
------------------------------------------------------------
local DEFAULT_SPACING = 32

local function Mgr() return EditModeManagerFrame end

-- 直接問暴雪現在是不是在編輯模式（登入保底用；平常以三重訊號維護的旗標為準）
function M.ReadBlizzard()
    local mgr = Mgr()
    if not (mgr and mgr.IsEditModeActive) then return nil end
    local ok, v = pcall(mgr.IsEditModeActive, mgr)
    if not ok or type(v) ~= "boolean" then return nil end
    return v
end

function M.GridSpacing()
    local mgr = Mgr()
    if not mgr then return DEFAULT_SPACING end
    local ok, v = pcall(function()
        return mgr:GetAccountSettingValue(Enum.EditModeAccountSetting.GridSpacing)
    end)
    if ok and type(v) == "number" and v > 0 then return v end
    local grid = mgr.Grid
    if grid and type(grid.gridSpacing) == "number" and grid.gridSpacing > 0 then
        return grid.gridSpacing
    end
    return DEFAULT_SPACING
end

-- 暴雪的「吸附」開關；Shift 按著一律不吸
function M.SnapEnabled()
    if IsShiftKeyDown and IsShiftKeyDown() then return false end
    local mgr = Mgr()
    if mgr and mgr.IsSnapEnabled then
        local ok, v = pcall(mgr.IsSnapEnabled, mgr)
        return ok and v == true
    end
    return false
end

-- 格線看得到才吸格線（吸一條看不到的線只會讓框停在莫名其妙的位置）；
-- 暴雪格線要問 IsVisible 不是 IsShown。回傳格距，沒有就 nil
function M.ActiveGridSpacing()
    local grid = Mgr() and Mgr().Grid
    if grid and grid.IsVisible then
        local ok, v = pcall(grid.IsVisible, grid)
        if ok and v == true then return M.GridSpacing() end
    end
    return nil
end

------------------------------------------------------------
-- 進出訊號
------------------------------------------------------------
M.active = false          -- 我們認定的編輯模式狀態（三重訊號維護）
M.hooked = false

local movers = {}         -- 已 Attach 的 mover（弱鍵：frame 刪不掉，但不擋 GC）
setmetatable(movers, { __mode = "k" })
local listeners = {}      -- owner → fn(active)
local dispatchArmed = false

function M.IsActive()
    return M.active
end

-- 狀態改變時 fn(active)（下一幀）。owner 任意（字串、表），同 owner 重複登記就覆蓋
function M.OnChange(owner, fn)
    listeners[owner] = fn
end

function M.OffChange(owner)
    listeners[owner] = nil
end

local function Dispatch()
    dispatchArmed = false
    local active = M.active
    for mover in pairs(movers) do
        mover:Refresh()
        if mover.opts.onChange then Safe(mover.opts.onChange)(mover:Editing(), mover) end
    end
    for _, fn in pairs(listeners) do Safe(fn)(active) end
end

-- 派送一次（下一幀；同一幀多次只派一次，送的是當時的狀態）
function M.RequestDispatch()
    if dispatchArmed then return end
    dispatchArmed = true
    M.Defer(Dispatch)
end

local function SetActive(on)
    on = on and true or false
    if M.active == on then return end
    M.active = on
    M.RequestDispatch()
end

local function OnEnter() SetActive(true) end
local function OnExit() SetActive(false) end

local function HookEditMode()
    if M.hooked then return end
    local mgr = Mgr()
    if not mgr then return end
    M.hooked = true
    -- 訊號一：管理視窗的顯示狀態（後掛勾，跑到這裡時暴雪那一輪已做完）
    mgr:HookScript("OnShow", OnEnter)
    mgr:HookScript("OnHide", OnExit)
    -- 訊號二：方法本體。編輯模式真的啟動就必然執行
    if mgr.EnterEditMode and hooksecurefunc then hooksecurefunc(mgr, "EnterEditMode", OnEnter) end
    if mgr.ExitEditMode and hooksecurefunc then hooksecurefunc(mgr, "ExitEditMode", OnExit) end
    if mgr:IsShown() then OnEnter() end
end
M.Hook = HookEditMode

------------------------------------------------------------
-- 拖曳（手動游標差值；driver 只在拖曳中存在 OnUpdate，平常零成本）
------------------------------------------------------------
local dragState, driver

local function Cursor()
    local scale = UIParent:GetEffectiveScale()
    if type(scale) ~= "number" or scale <= 0 then scale = 1 end
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

local function DragTick()
    local d = dragState
    if not d then if driver then driver:Hide() end return end
    local mover = d.mover
    if InCombat() then mover:EndDrag(false) return end
    -- 有些情況收不到 OnDragStop（滑鼠在視窗外放開、被別的框吃掉），自己確認一次
    if not IsMouseButtonDown("LeftButton") then mover:EndDrag(true) return end
    local frame = mover.frame
    local cx, cy = Cursor()
    local l, t = d.left + (cx - d.cx), d.top + (cy - d.cy)
    if mover.opts.grid ~= false and M.SnapEnabled() then
        local step = M.ActiveGridSpacing()
        if step then
            local ox, oy = UIParent:GetCenter()
            local gx, gy = M.SnapDelta(mover.opts.anchorPoint or "CENTER", l, l + d.w, t, t - d.h, ox, oy, step)
            l, t = l + gx, t + gy
        end
    end
    -- 上面剛確認過不在戰鬥中：框直接動
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", l - UIParent:GetLeft(), t - UIParent:GetTop())
end

local function EnsureDriver()
    if driver then return driver end
    driver = CreateFrame("Frame")
    driver:Hide()
    driver:SetScript("OnUpdate", DragTick)
    return driver
end

function M.Dragging()
    return dragState and dragState.mover or nil
end

------------------------------------------------------------
-- mover
------------------------------------------------------------
local Mover = {}
Mover.__index = Mover

-- 現在可以拖：暴雪編輯模式，或宿主自己說可以（設定視窗開著，SetForced）
function Mover:Editing()
    return M.active or self.forced == true
end

-- 宿主自己的「現在可以拖」訊號（例如本插件的設定視窗開著）；改了會重派一次 onChange
function Mover:SetForced(on)
    on = on and true or false
    if self.forced == on then return end
    self.forced = on
    M.RequestDispatch()
end

function Mover:IsDragging()
    return dragState ~= nil and dragState.mover == self
end

-- 依目前狀態顯示／收起選取框（走 Write：宿主是保護框時戰鬥中記帳）
function Mover:Refresh()
    local sel, opts = self.selection, self.opts
    if not sel then return end
    local show = self:Editing() and (opts.enabled == nil or opts.enabled(self.frame) ~= false)
    M.Write(self.frame, function()
        if show then
            if sel.ShowHighlighted then sel:ShowHighlighted() else sel:Show() end
        else
            sel:Hide()
        end
    end)
end

function Mover:BeginDrag()
    if dragState or InCombat() then return false end
    local frame, opts = self.frame, self.opts
    if opts.canDrag and not opts.canDrag(frame) then return false end
    local rect = M.RectOf(frame)
    if not rect then return false end
    local S = ns.Snap
    if opts.snapKey and S and S.OnDragStart then S.OnDragStart(opts.snapKey) end   -- 拖自己＝先脫離
    if opts.onDragStart then Safe(opts.onDragStart)(frame) end
    local cx, cy = Cursor()
    dragState = {
        mover = self, cx = cx, cy = cy,
        left = rect[1], top = rect[3], w = rect[2] - rect[1], h = rect[3] - rect[4],
    }
    EnsureDriver():Show()
    return true
end

-- commit = false：不寫 db（進戰鬥、框不見了），框照存檔放回（opts.restore）
function Mover:EndDrag(commit)
    local d = dragState
    if not d or d.mover ~= self then return end
    dragState = nil
    if driver then driver:Hide() end
    local frame, opts = self.frame, self.opts
    if commit and not InCombat() then
        -- 放手離套組其他框 2px 內就貼齊（MiliUISnap），再讓宿主照現況存座標
        local S = ns.Snap
        if opts.snapKey and S and S.OnDragStop and not (IsShiftKeyDown and IsShiftKeyDown()) then
            S.OnDragStop(opts.snapKey)
        end
        -- 框有名字：不清的話 WoW 的版面快取會跟宿主的 SetPoint 打架
        pcall(frame.SetUserPlaced, frame, false)
        if opts.save then Safe(opts.save)(frame) end
    elseif opts.restore then
        M.Write(frame, function() opts.restore(frame) end)
    end
    if opts.onDragStop then Safe(opts.onDragStop)(frame, commit and true or false) end
end

------------------------------------------------------------
-- 選取框
------------------------------------------------------------
local function HairlineSize()
    local P = ns.P
    if P and P.Pixel then
        local ok, v = pcall(P.Pixel, 1)
        if ok and type(v) == "number" then return v end
    end
    return 1
end

local function BuildSelection(mover)
    local frame, opts = mover.frame, mover.opts
    local function Name()
        local n = opts.name
        if type(n) == "function" then n = n(frame) end
        return n or (frame.GetName and frame:GetName()) or "MiliUI"
    end
    local pressed = false
    local function OnPress(_, button) pressed = (button == "LeftButton") end
    local function OnRelease(self, button)
        local was = pressed
        pressed = false
        if not (was and button == "LeftButton" and opts.onClick) then return end
        if self.IsMouseOver and not self:IsMouseOver() then return end
        -- 開視窗之類的事延一幀：不在滑鼠腳本那一次執行裡做
        M.Defer(function() opts.onClick(frame, button) end)
    end

    -- ⚠ 開檔（Attach 時）就建，不要等進了編輯模式才建：在暴雪的 OnShow 執行路徑裡建框
    --   是沒驗證過的時序，實測會整組靜默失效。模板建立失敗也是靜默的 ⇒ pcall ＋ 自畫備援
    local ok, sel = pcall(CreateFrame, "Frame", nil, frame, "EditModeSystemSelectionTemplate")
    if ok and sel then
        -- ⚠⚠ 模板的 XML 綁了 OnMouseDown → EditModeManagerFrame:SelectSystem(self.parent)。
        --   我們不是真的編輯模式系統，讓它跑下去＝暴雪讀我們寫的 self.parent，整條選取流程
        --   帶著本插件的 taint 掃過每一個已註冊系統（快捷列也在內），當下不報錯、戰鬥中才爆。
        sel:SetScript("OnMouseDown", OnPress)
        -- 標籤與滑鼠提示走 self.system:GetSystemName()，塞個 stub
        sel.system = { GetSystemName = Name }
        mover.isFallback = false
    else
        sel = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        sel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
                          edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = HairlineSize() })
        sel:SetBackdropColor(0.25, 0.6, 1, 0.15)
        sel:SetBackdropBorderColor(0.25, 0.6, 1, 0.9)
        if sel.SetIgnoreParentAlpha then sel:SetIgnoreParentAlpha(true) end
        sel:EnableMouse(true)
        sel.ShowHighlighted = sel.Show
        sel:SetScript("OnMouseDown", OnPress)
        mover.isFallback = true
    end
    sel:SetAllPoints(frame)
    sel:Hide()
    sel:RegisterForDrag("LeftButton")
    sel:SetScript("OnDragStart", function() pressed = false; mover:BeginDrag() end)
    sel:SetScript("OnDragStop", function() mover:EndDrag(true) end)
    sel:SetScript("OnMouseUp", OnRelease)
    return sel
end

------------------------------------------------------------
-- Attach(frame, opts) → mover
--
-- opts（全部選用，除了 save 幾乎都該給）：
--   name        選取框標籤：字串或 function(frame)
--   save        function(frame)  放手時（已確認不在戰鬥）：宿主照框的現況存座標，並照存檔重貼
--   restore     function(frame)  拖曳被中斷（進戰鬥、ESC 離開編輯模式）：照存檔放回
--   onChange    function(editing, mover)  進出編輯模式（下一幀；Editing() ＝ 暴雪編輯模式 or SetForced）：
--               給樣板內容、平常藏著的框要 Show 讓玩家瞄得到；離開時收回
--   enabled     function(frame) → false 時進了編輯模式也不亮選取框（功能關著）
--   canDrag     function(frame) → false 時不能拖（鎖定、停靠中…）
--   onClick     function(frame, button)  點一下沒拖（下一幀；例如開設定頁）
--   onDragStart function(frame)／onDragStop function(frame, committed)
--   snapKey     MiliUISnap 的 key：Begin 時 OnDragStart、放手時 OnDragStop（Shift 不吸）
--   grid        false 就不吸暴雪格線（預設吸）
--   anchorPoint 吸格線時用框的哪一點（預設 CENTER；錨左下角存檔的條給 BOTTOMLEFT）
--
-- 宿主要自己做的：SetMovable(true)、SetUserPlaced(false)、SetClampedToScreen(true)、
-- 照存檔 SetPoint；位置的存法由 save／restore 決定（CENTER 偏移用 CenterOffset／ApplyCenter）。
------------------------------------------------------------
function M.Attach(frame, opts)
    if type(frame) ~= "table" then return nil end
    opts = opts or {}
    local mover = setmetatable({ frame = frame, opts = opts, forced = false }, Mover)
    mover.selection = BuildSelection(mover)
    movers[mover] = true
    frame.miliuiMover = mover
    if mover:Editing() then mover:Refresh() end
    return mover
end

------------------------------------------------------------
-- 執行期接線（遊戲裡才有 CreateFrame；離線測試只載純函式那半）
------------------------------------------------------------
if CreateFrame then
    HookEditMode()                                                           -- 檔案層
    if not M.hooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
        EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)   -- 暴雪編輯模式載入時
    end
    -- 訊號三：官方 EventRegistry 事件（EnterEditMode／ExitEditMode 內部發的）。
    -- owner 用這張表：每支插件一份、不會跟別支的登記撞在一起
    if EventRegistry and EventRegistry.RegisterCallback then
        EventRegistry:RegisterCallback("EditMode.Enter", OnEnter, M)
        EventRegistry:RegisterCallback("EditMode.Exit", OnExit, M)
    end

    local runtime = CreateFrame("Frame")
    runtime:RegisterEvent("PLAYER_LOGIN")
    runtime:RegisterEvent("PLAYER_REGEN_DISABLED")
    runtime:RegisterEvent("PLAYER_REGEN_ENABLED")
    runtime:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_LOGIN" then
            HookEditMode()                                                   -- 登入保底
            local blizz = M.ReadBlizzard()
            if blizz ~= nil then SetActive(blizz) end
        elseif event == "PLAYER_REGEN_DISABLED" then
            -- ⚠ 同步跑完：派送當下鎖定還沒生效，延一幀就錯過了。拖曳中：收掉、框放回存檔位置、不寫 db
            local mover = M.Dragging()
            if mover then xpcall(mover.EndDrag, Report, mover, false) end
        else
            FlushPending()
        end
    end)
    M.runtime = runtime
end

return M
