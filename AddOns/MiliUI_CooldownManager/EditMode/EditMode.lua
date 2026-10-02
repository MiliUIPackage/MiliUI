------------------------------------------------------------
-- 編輯模式整合（wow-editmode-draggable 技能配方）
--
-- 四條暴雪檢視器
--   系統框維持暴雪自己的狀態（我們不 StartMoving 它、它被釘在容器上）。拖的是**容器**：
--   暴雪的 viewer.Selection 貼到容器的覆蓋層上，它的 OnDragStart／OnDragStop 換成
--   BeginDrag／EndDrag。放手時把容器的錨點那一邊換算回 bars[key].pos（EM.ReadPos）。
--
--   ⚠ Selection 的拖曳腳本用 **SetScript 整條換掉**——計畫 §2「只後掛勾」的唯一例外。
--     暴雪原本的 OnDragStart 是 self.parent:OnDragStart() → 系統框 StartMoving 自己、
--     放手後 OnSystemPositionChange 把位置寫進暴雪的編輯模式版面。後掛勾只能「多做」，
--     不能「不要做」；讓它做了，檢視器會被拖離容器、位置存進暴雪版面，下一幀又被
--     PinViewer 釘回來（拉鋸）。OnMouseDown 不動：那是暴雪自己的 SelectSystem，
--     我們接的是它後面那一步（設定對話框，見下）。
--
--   暴雪的系統設定對話框（EditModeSystemSettingsDialog）對這四條一律藏掉：它的尺寸／
--   方向／間距跟我們的設定不同步，開了只會誤導。第一次藏的時候聊天框印一行指路。
--
-- 自訂條：自己借 EditModeSystemSelectionTemplate 建選取框（Frames.lua），拖曳同一套。
--
-- 拖曳：手動游標差值（不用 StartMoving）。BeginDrag 記游標與容器左上，DragTick（driver 的
-- OnUpdate，只在拖曳中存在）每幀 ClearAllPoints＋SetPoint(TOPLEFT, UIParent)；EndDrag 換算
-- 存檔、SetUserPlaced(false)、結構級重排讓 ApplyStructure 照存檔重貼。拖曳中 ns.dragging = key
-- （Bars 的重排與 PinViewer 會跳過那條）。錨在別條上的條：拖曳一開始就脫離（anchor = false、
-- 把現況換算成 pos 寫進去）。
--
-- 吸附：讀暴雪的「吸附」開關與格線間距（Shift 反轉），只吸容器的錨點那一邊；
-- 放手時再走 MiliUISnap 跟套組其他框對齊（align，不貼附）。
--
-- 進出訊號：三重（管理視窗 OnShow/OnHide、EnterEditMode/ExitEditMode 後掛勾、EventRegistry），
-- 處理器只改旗標，工作一律 ns.Defer 到下一幀（離開暴雪的執行堆疊）；碰容器的動作走 ns.Write。
-- ⚠ 編輯模式**不會被戰鬥關掉**，戰鬥中進得去也出得來 ⇒ 進出處理器可能在鎖定中跑，
--   所以全部經 ns.Write（容器在保護鏈上就記帳）。進戰鬥那一刻（PLAYER_REGEN_DISABLED，
--   鎖定還沒生效）同步收掉進行中的拖曳、容器放回存檔位置，不寫 db。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.EditMode = ns.EditMode or {}
local EM = ns.EditMode

EM.active = false          -- 我們認定的編輯模式狀態（三重訊號維護）
EM.optionsOpen = false     -- 設定視窗開著：覆蓋層照樣出來、條可以拖（不用進暴雪的編輯模式）
EM.hooked = false

-- 「現在可以拖」：暴雪編輯模式，或本插件的設定視窗開著（使用者 2026-10-01 指定：開設定就能拖、磁吸也在）
function EM.Editing()
    return EM.active or EM.optionsOpen
end

local Guard = ns.Guard
local BarCfg = EM.BarCfg
local SNAP_PREFIX = EM.SNAP_PREFIX

-- 讀暴雪的狀態（唯讀；編輯模式戰鬥中也能進出，讀狀態本身沒有限制）
function EM.IsActive()
    local mgr = EditModeManagerFrame
    if not (mgr and mgr.IsEditModeActive) then return EM.active end
    local ok, active = pcall(mgr.IsEditModeActive, mgr)
    if not ok or ns.IsSecret(active) then return EM.active end
    return active and true or false
end

------------------------------------------------------------
-- 格線吸附（參數一律讀暴雪的，不另開設定）
------------------------------------------------------------
local DEFAULT_SPACING = 32

local function GridSpacing()
    local mgr = EditModeManagerFrame
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
EM.GridSpacing = GridSpacing

-- Shift 按著一律不吸（條對齊、格線、套組磁吸都不吸）；設定視窗開著（不在暴雪編輯模式）時一律吸，
-- 暴雪編輯模式裡照暴雪的「吸附」開關。格線另外要看得到才吸（GridShown）
local function SnapEnabled()
    if IsShiftKeyDown() then return false end
    if EM.optionsOpen and not EM.active then return true end
    local mgr = EditModeManagerFrame
    if mgr and mgr.IsSnapEnabled then
        local ok, v = pcall(mgr.IsSnapEnabled, mgr)
        return ok and v == true
    end
    return false
end
EM.SnapEnabled = SnapEnabled

-- 格線看得到才吸格線：設定視窗開著（沒進編輯模式）、或編輯模式沒開格線時，吸一條看不到的線
-- 只會讓條停在莫名其妙的位置
local function GridShown()
    local grid = EditModeManagerFrame and EditModeManagerFrame.Grid
    if not (EM.active and grid and grid.IsShown) then return false end
    local ok, v = pcall(grid.IsShown, grid)
    return ok and v == true
end

-- 拖曳時可以對齊的其他條：看得到、有大小、而且不是（直接或間接）跟著拖的這條走的
-- （跟隨者會一起動，距離永遠是 0）。拖曳中量一次就好，其他條不會動
local function FollowsKey(k, key)
    local B, seen, cur = ns.Bars, {}, k
    while cur and not seen[cur] do
        if cur == key then return true end
        seen[cur] = true
        local a = ns.Layout.AnchorOf(cur, BarCfg)
        cur = (B.StackTarget and B.StackTarget(cur)) or (a and a.to) or nil
    end
    return false
end

local function AlignTargets(key)
    local list = {}
    for k, c in pairs(ns.Bars.Containers()) do
        if k ~= key and c:IsShown() and BarCfg(k) and not FollowsKey(k, key) then
            local rect = EM.RectOf(c)
            if rect and rect[2] - rect[1] > 1 and rect[3] - rect[4] > 1 then list[#list + 1] = rect end
        end
    end
    return list
end

------------------------------------------------------------
-- 拖曳
------------------------------------------------------------
local dragState
local driver = CreateFrame("Frame")
driver:Hide()
EM.driver = driver

local function Cursor()
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    local x, y = GetCursorPosition()
    return x / scale, y / scale
end

-- commit = false：不寫 db（進戰鬥、容器不見了），容器照存檔放回去
function EM.EndDrag(commit)
    local d = dragState
    if not d then return end
    dragState = nil
    driver:Hide()
    local key = d.key
    local c, bar = ns.Bars.Get(key), BarCfg(key)
    local canWrite = not InCombatLockdown()
    if commit and canWrite and c and bar then
        -- 放手離套組其他框 2px 內就貼齊，再照現況換算存檔（Shift 按著就不吸）
        if ns.Snap and ns.Snap.OnDragStop and not IsShiftKeyDown() then ns.Snap.OnDragStop(SNAP_PREFIX .. key) end
        local pos = EM.ReadPos(key)
        if pos then bar.pos = pos end
        -- 容器有名字：不清的話 WoW 的版面快取會跟我們的 SetPoint 打架
        pcall(c.SetUserPlaced, c, false)
    end
    ns.dragging = nil
    -- 照存檔重貼。鎖定還沒生效（包含 PLAYER_REGEN_DISABLED 那一刻）就當場套；
    -- 結構級重排也排一次（戰鬥中它會記帳到脫戰）
    if canWrite and c and bar and ns.Bars.ApplyStructure then ns.Bars.ApplyStructure(key) end
    ns.Bars.Request(key, "structure")
    EM.RefreshBar(key)
    if ns.Fire then ns.Fire("BarMoved", key) end
end

local function DragTick()
    local d = dragState
    if not d then driver:Hide() return end
    if InCombatLockdown() then EM.EndDrag(false) return end
    -- 有些情況收不到 OnDragStop（滑鼠在視窗外放開、被別的框吃掉），自己確認一次
    if not IsMouseButtonDown("LeftButton") then EM.EndDrag(true) return end
    local c = ns.Bars.Get(d.key)
    if not c then EM.EndDrag(false) return end
    local cx, cy = Cursor()
    local l, t = d.left + (cx - d.cx), d.top + (cy - d.cy)
    if SnapEnabled() then
        -- 拖曳中就吸，放手才吸的話手感會「跳一下」。先對齊其他條（邊／中心），
        -- 那一軸沒得對才吸格線（格線看得到時；從畫面中心往外畫）
        -- 第一幀才量：BeginDrag 的 Restack 會讓疊在它外面的條補位，要量補位之後的
        d.targets = d.targets or AlignTargets(d.key)
        local ax, ay = EM.AlignDelta({ l, l + d.w, t, t - d.h }, d.targets, EM.SNAP_RANGE)
        if not (ax and ay) and GridShown() then
            local ox, oy = UIParent:GetCenter()
            local gx, gy = EM.SnapDelta(d.anchorPoint, l, l + d.w, t, t - d.h, ox, oy, GridSpacing())
            ax, ay = ax or gx, ay or gy
        end
        l, t = l + (ax or 0), t + (ay or 0)
    end
    -- 上面剛確認過不在戰鬥中：容器直接動（每幀一次，不經 ns.Write 的保護判斷）
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", UIParent, "TOPLEFT", l - UIParent:GetLeft(), t - UIParent:GetTop())
end
driver:SetScript("OnUpdate", DragTick)

function EM.BeginDrag(key)
    if dragState or InCombatLockdown() then return end
    local c, bar = ns.Bars.Get(key), BarCfg(key)
    if not (c and bar) then return end
    local rect = EM.RectOf(c)
    if not rect then return end
    -- 錨在別條上的條：拖了就脫離。先把現況換算成 pos 寫進去，放手時再以放手位置覆蓋。
    -- 提示列（「拖曳會解除跟隨」）拖曳中留著，放手的 RefreshBar 才收掉
    if type(bar.anchor) == "table" then
        local pos = EM.ReadPos(key)
        if not pos then return end
        bar.pos = pos
        bar.anchor = false
    end
    if ns.Snap and ns.Snap.OnDragStart then ns.Snap.OnDragStart(SNAP_PREFIX .. key) end
    local cx, cy = Cursor()
    dragState = {
        key = key, cx = cx, cy = cy,
        left = rect[1], top = rect[3], w = rect[2] - rect[1], h = rect[3] - rect[4],
        anchorPoint = ns.Bars.AnchorPoint(key),
    }
    ns.dragging = key
    -- 脫離錨定之後，原本疊在它外面的（貼在它身上排開的）要補位回去，不然會跟著游標跑
    if ns.Bars.Restack then ns.Bars.Restack() end
    driver:Show()
end

function EM.DraggingKey()
    return dragState and dragState.key or nil
end

------------------------------------------------------------
-- 全部刷新（下一幀）
------------------------------------------------------------
local refreshArmed = false

local function RefreshAll()
    refreshArmed = false
    if not (ns.ready and ns.Bars and ns.Bars.Containers) then return end
    if not EM.Editing() then
        -- 拖到一半離開編輯模式（ESC）：照放手處理；ns.dragging 一律清，卡住的話之後所有重錨都失效
        if dragState then EM.EndDrag(not InCombatLockdown()) end
        ns.dragging = nil
        EM.RestoreDialog()               -- 設定對話框藏著的話還回去
    end
    for key in pairs(ns.Bars.Containers()) do EM.RefreshBar(key) end
    if ns.Visibility and ns.Visibility.ApplyAll then ns.Visibility.ApplyAll() end
end

function EM.RequestRefresh()
    if refreshArmed then return end
    refreshArmed = true
    ns.Defer(RefreshAll)
end

------------------------------------------------------------
-- 進戰鬥的鬆手窗口
--
-- ⚠ 自己這顆 frame 的 OnEvent、同步跑完。PLAYER_REGEN_DISABLED 派送當下鎖定還沒生效，
--   延一幀就錯過了。拖曳中：收掉、容器放回存檔位置，不寫 db。
------------------------------------------------------------
local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if dragState then xpcall(EM.EndDrag, ns.ReportError, false) end
        if EM.Editing() then self:RegisterEvent("PLAYER_REGEN_ENABLED") end
    else
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
        if EM.Editing() then EM.RequestRefresh() end
    end
end)

------------------------------------------------------------
-- 暴雪的系統設定對話框：四條檢視器一律「藏」
--
-- ⚠ 不 Hide：Hide 會從我們的執行跑暴雪的 OnHide（寫 attachedToSystem 等欄位 ⇒ 下一次暴雪自己
--   AttachToSystemFrame 讀到被我們寫過的值，污染帶進編輯模式）。改用純 C 端狀態：
--   後掛勾 AttachToSystemFrame 當場 SetAlpha(0)＋EnableMouse(false)（對話框本身與每個吃滑鼠的
--   子孫，記下原本開著的是哪些），滾輪同理。taint 不追蹤 widget 屬性。
--   還回去：下一次 AttachToSystemFrame 的 systemFrame **不是**我們四條時（同一個後掛勾）、
--   離開編輯模式時（RefreshAll，下一幀）。對話框的內容、Settings 列、欄位一律不寫。
------------------------------------------------------------
local hintPrinted = false
local muted = nil          -- nil ＝ 沒藏；藏著時 = { mouse = { 框… }, wheel = { 框… } }

local function Try(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return nil end
    local ok, v = pcall(fn, obj, ...)
    if not ok or ns.IsSecret(v) then return nil end
    return v
end

-- 對話框與它的子孫：吃滑鼠／滾輪的關掉，記下來
local function MuteTree(frame, rec, depth)
    if depth > 12 then return end
    if Try(frame, "IsMouseEnabled") then
        Try(frame, "EnableMouse", false)
        rec.mouse[#rec.mouse + 1] = frame
    end
    if Try(frame, "IsMouseWheelEnabled") then
        Try(frame, "EnableMouseWheel", false)
        rec.wheel[#rec.wheel + 1] = frame
    end
    local ok, n = pcall(frame.GetNumChildren, frame)
    if ok and type(n) == "number" and n > 0 then
        for _, child in ipairs({ frame:GetChildren() }) do MuteTree(child, rec, depth + 1) end
    end
end

local function MuteDialog(dialog)
    Try(dialog, "SetAlpha", 0)
    if muted then return end                 -- 已經藏著（在四條之間點來點去）
    muted = { mouse = {}, wheel = {} }
    MuteTree(dialog, muted, 0)
end

-- 還給暴雪：alpha 1、關掉的滑鼠／滾輪照記錄打開
function EM.RestoreDialog()
    if not muted then return end
    local rec = muted
    muted = nil
    for _, f in ipairs(rec.mouse) do Try(f, "EnableMouse", true) end
    for _, f in ipairs(rec.wheel) do Try(f, "EnableMouseWheel", true) end
    Try(EditModeSystemSettingsDialog, "SetAlpha", 1)
end
function EM.DialogMuted() return muted ~= nil end

local function OnDialogAttach(dialog, systemFrame)
    local V = ns.Viewers
    local key = V and V.viewerKey[systemFrame]
    if not key or ns.released then
        EM.RestoreDialog()               -- 點到別的系統（或已經還給暴雪）：還給它
        return
    end
    MuteDialog(dialog)
    if not hintPrinted then
        hintPrinted = true
        ns.Defer(function()
            ns.Print(L["Cooldown Manager settings are in /mcdm, or click a bar to open its settings."])
        end)
    end
end

------------------------------------------------------------
-- 進出訊號（三重，全部冪等）
------------------------------------------------------------
-- 狀態真的變了才廣播 "EditModeChanged"（設定視窗的點擊層要讓位；三重訊號會重複進來）
-- 設定視窗的開關（Panel 的 OnShow／OnHide 廣播）：只改旗標，工作延一幀
ns.RegisterCallback("OptionsShown", "editmode", function()
    EM.optionsOpen = true
    EM.RequestRefresh()
end)
ns.RegisterCallback("OptionsHidden", "editmode", function()
    EM.optionsOpen = false
    EM.RequestRefresh()
end)

local function OnEnter()
    local was = EM.active
    EM.active = true
    EM.RequestRefresh()
    if not was and ns.Fire then ns.Fire("EditModeChanged", true) end
end

local function OnExit()
    local was = EM.active
    EM.active = false
    EM.RequestRefresh()
    if was and ns.Fire then ns.Fire("EditModeChanged", false) end
end

-- 暴雪的「冷卻管理器」勾選框切換時會亮起／收起四條的 Selection：跟著換用哪個選取框
local function OnCooldownViewerRefresh()
    if EM.active then EM.RequestRefresh() end
end

local function HookEditMode()
    if EM.hooked then return end
    local mgr = EditModeManagerFrame
    if not mgr then return end
    EM.hooked = true
    -- 訊號一：管理視窗的顯示狀態（後掛勾，跑到這裡時暴雪那一輪已做完）
    mgr:HookScript("OnShow", Guard(OnEnter))
    mgr:HookScript("OnHide", Guard(OnExit))
    -- 訊號二：方法本體。編輯模式真的啟動就必然執行
    if mgr.EnterEditMode then hooksecurefunc(mgr, "EnterEditMode", Guard(OnEnter)) end
    if mgr.ExitEditMode then hooksecurefunc(mgr, "ExitEditMode", Guard(OnExit)) end

    local dialog = EditModeSystemSettingsDialog
    if dialog and dialog.AttachToSystemFrame then
        hooksecurefunc(dialog, "AttachToSystemFrame", Guard(OnDialogAttach))
        EM.dialogHooked = true
    end
    local acct = mgr.AccountSettings
    if acct and acct.RefreshCooldownViewer then
        hooksecurefunc(acct, "RefreshCooldownViewer", Guard(OnCooldownViewerRefresh))
    end

    if mgr:IsShown() then OnEnter() end
end

HookEditMode()                                                           -- 檔案層
if not EM.hooked and EventUtil and EventUtil.ContinueOnAddOnLoaded then
    EventUtil.ContinueOnAddOnLoaded("Blizzard_EditMode", HookEditMode)   -- 暴雪編輯模式載入時
end
-- 訊號三：官方 EventRegistry 事件（EnterEditMode／ExitEditMode 內部發的）
if EventRegistry and EventRegistry.RegisterCallback then
    EventRegistry:RegisterCallback("EditMode.Enter", OnEnter, "MiliUICDM")
    EventRegistry:RegisterCallback("EditMode.Exit", OnExit, "MiliUICDM")
end

-- 登入保底：再掛一次；引擎起來、檢視器就緒、換設定檔之後都要重刷一次
ns.RegisterCallback("Loaded", "editmode", function()
    HookEditMode()
    if EM.IsActive() then EM.active = true end
    EM.RequestRefresh()
end)
ns.RegisterCallback("ViewersReady", "editmode", function()
    for _, key in ipairs(ns.Viewers.ORDER) do EM.WireViewer(key) end
    if EM.active then EM.RequestRefresh() end
end)
ns.RegisterCallback("ProfileChanged", "editmode", function()
    if EM.active then EM.RequestRefresh() end
end)

------------------------------------------------------------
-- /mcdm debug（開發用，字串不進語系檔）
------------------------------------------------------------
-- 跟隨誰；排開之後實際貼在別條身上的話一併寫出來
local function FollowText(key, a)
    local to = ns.Bars.StackTarget and ns.Bars.StackTarget(key) or a.to
    if to and to ~= a.to then return ("%s（貼 %s）"):format(tostring(a.to), tostring(to)) end
    return tostring(a.to)
end

function EM.DebugLines()
    local out = {}
    local function onoff(v) return v and "是" or "否" end
    out[#out + 1] = ("  編輯模式：%s（暴雪 %s）  掛勾 %s  對話框掛勾 %s（藏著 %s）  拖曳中 %s  吸附 %s／格距 %s")
        :format(onoff(EM.active), onoff(EM.IsActive()), onoff(EM.hooked), onoff(EM.dialogHooked), onoff(muted ~= nil),
                tostring(ns.dragging or "—"), onoff(SnapEnabled()), tostring(GridSpacing()))
    local B = ns.Bars
    if not (B and B.Containers) then return out end
    local keys, seen = {}, {}
    for _, key in ipairs(ns.Viewers and ns.Viewers.ORDER or {}) do
        if B.Get(key) then keys[#keys + 1] = key; seen[key] = true end
    end
    local rest = {}
    for key in pairs(B.Containers()) do
        -- 刪掉的自訂群組容器還在（frame 刪不掉），只列設定檔裡有的條與面板
        if not seen[key] and BarCfg(key) then rest[#rest + 1] = key end
    end
    table.sort(rest)
    for _, key in ipairs(rest) do keys[#keys + 1] = key end
    for _, key in ipairs(keys) do
        local bar = BarCfg(key)
        local pos = bar and type(bar.pos) == "table" and bar.pos or {}
        local a = bar and type(bar.anchor) == "table" and bar.anchor
        out[#out + 1] = ("  %-9s pos %s(%s, %s)  錨點 %s  跟隨 %s  選取框 %s")
            :format(key, tostring(pos.point or "CENTER"), tostring(pos.x), tostring(pos.y),
                    tostring(B.AnchorPoint(key)), a and FollowText(key, a) or "—",
                    tostring(EM.selKind[key] or "—"))
    end
    return out
end
