------------------------------------------------------------
-- MiliUIEditMode.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua AddOns/MiliUI/Libs/MiliUIEditMode/Tests/MiliUIEditMode_test.lua
--   （.claude/scripts/run_tests.sh 會一起跑）
--
-- 兩半：純函式（錨點座標、格線吸附、CENTER 偏移）直接驗數字；執行期那半用一套最小的
-- WoW stub（CreateFrame／C_Timer／InCombatLockdown／UIParent）驗 Attach 的備援選取框、
-- 進出訊號派送、戰鬥閘佇列、拖曳放手的 save／restore 路徑。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local LIB_PATH = here .. "/../MiliUIEditMode.lua"

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then passed = passed + 1
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end
local function near(name, got, want)
    check(name, type(got) == "number" and math.abs(got - want) < 1e-9, "got " .. tostring(got) .. ", want " .. tostring(want))
end

------------------------------------------------------------
-- 第一半：純函式（沒有 CreateFrame ⇒ 執行期接線整段跳過）
------------------------------------------------------------
do
    local ns = {}
    local chunk = assert(loadfile(LIB_PATH))
    chunk("MiliUIEditMode_test", ns)
    local M = ns.MiliUIEditMode
    check("掛在 ns.MiliUIEditMode", type(M) == "table")
    eq("離線沒有 runtime", M.runtime, nil)

    -- PointXY：矩形 l=10 r=30 t=50 b=10
    local x, y = M.PointXY("TOPLEFT", 10, 30, 50, 10);     near("TOPLEFT x", x, 10);  near("TOPLEFT y", y, 50)
    x, y = M.PointXY("CENTER", 10, 30, 50, 10);            near("CENTER x", x, 20);   near("CENTER y", y, 30)
    x, y = M.PointXY("BOTTOMRIGHT", 10, 30, 50, 10);       near("BR x", x, 30);       near("BR y", y, 10)
    x, y = M.PointXY("BOTTOM", 10, 30, 50, 10);            near("BOTTOM x", x, 20);   near("BOTTOM y", y, 10)
    x, y = M.PointXY("nonsense", 10, 30, 50, 10);          near("亂填當 CENTER x", x, 20)

    eq("Round 2.5", M.Round(2.5), 3)
    eq("Round -2.5", M.Round(-2.5), -2)
    eq("SnapValue 33/32", M.SnapValue(33, 32), 32)
    eq("SnapValue 49/32", M.SnapValue(49, 32), 64)
    eq("SnapValue step 0 不動", M.SnapValue(49, 0), 49)
    eq("SnapValue step nil 不動", M.SnapValue(49, nil), 49)

    -- SnapDelta：CENTER 在 (1003, 503)，原點 (1000, 500)，格距 32 → 吸到 (992, 496)? 不：
    -- rx=3 → 最近格線 0 → dx=-3（在 range 4 內）；ry=3 → dy=-3
    local dx, dy = M.SnapDelta("CENTER", 993, 1013, 513, 493, 1000, 500, 32)
    near("SnapDelta 範圍內 x", dx, -3); near("SnapDelta 範圍內 y", dy, -3)
    -- rx=10 → 離 0 與 32 都超過 4 → 不吸
    dx, dy = M.SnapDelta("CENTER", 1000, 1020, 510, 490, 1000, 500, 32)
    near("SnapDelta 超出範圍不吸 x", dx, 0); near("SnapDelta 超出範圍不吸 y", dy, 0)
    -- 只吸錨點那一邊：BOTTOMLEFT 在 (1001, 501)
    dx, dy = M.SnapDelta("BOTTOMLEFT", 1001, 1100, 600, 501, 1000, 500, 32)
    near("BOTTOMLEFT 吸 x", dx, -1); near("BOTTOMLEFT 吸 y", dy, -1)
    dx, dy = M.SnapDelta("CENTER", 0, 10, 10, 0, 0, 0, 0)
    near("step 0 不吸", dx, 0)

    -- CenterOffsetOf：框中心 (300, 200)，父 1920×1080 中心 (960, 540)
    local ox, oy = M.CenterOffsetOf({ 250, 350, 250, 150 }, { 0, 1920, 1080, 0 })
    eq("CenterOffset x", ox, -660); eq("CenterOffset y", oy, -340)
    ox, oy = M.CenterOffsetOf({ 0.4, 10.4, 10.6, 0.6 }, { 0, 10, 10, 0 })
    eq("CenterOffset 四捨五入 x", ox, 0); eq("CenterOffset 四捨五入 y", oy, 1)

    -- RectOf 讀不到回 nil
    eq("RectOf nil", M.RectOf(nil), nil)
    local fake = { GetLeft = function() return nil end, GetRight = function() return 1 end,
                   GetTop = function() return 1 end, GetBottom = function() return 0 end }
    eq("RectOf 缺一邊回 nil", M.RectOf(fake), nil)
    fake.GetLeft = function() return 0 end
    local r = M.RectOf(fake)
    check("RectOf 四邊", r and r[1] == 0 and r[2] == 1 and r[3] == 1 and r[4] == 0)
end

------------------------------------------------------------
-- 第二半：執行期（最小 stub）
------------------------------------------------------------
do
    local combat = false
    local timers = {}
    local function Flush()                       -- 跑掉所有排程（模擬「下一幀」）
        local list = timers; timers = {}
        for _, fn in ipairs(list) do fn() end
    end

    local function NewFrame(protected)
        local f = { shown = false, scripts = {}, events = {}, points = {}, protected = protected or false }
        function f:Show() self.shown = true end
        function f:Hide() self.shown = false end
        function f:IsShown() return self.shown end
        function f:SetScript(k, fn) self.scripts[k] = fn end
        function f:HookScript(k, fn) self.scripts[k] = fn end
        function f:RegisterEvent(e) self.events[e] = true end
        function f:RegisterForDrag() end
        function f:EnableMouse() end
        function f:SetAllPoints() end
        function f:SetBackdrop() end
        function f:SetBackdropColor() end
        function f:SetBackdropBorderColor() end
        function f:SetIgnoreParentAlpha() end
        function f:SetUserPlaced(v) self.userPlaced = v end
        function f:IsProtected() return self.protected end
        function f:ClearAllPoints() self.points = {} end
        function f:SetPoint(p, rel, rp, x, y) self.points[#self.points + 1] = { p, rel, rp, x, y } end
        function f:GetLeft() return self.l end
        function f:GetRight() return self.r end
        function f:GetTop() return self.t end
        function f:GetBottom() return self.b end
        function f:GetCenter() return (self.l + self.r) / 2, (self.t + self.b) / 2 end
        function f:GetEffectiveScale() return 1 end
        function f:IsMouseOver() return true end
        return f
    end

    local env = setmetatable({}, { __index = _G })
    env.UIParent = NewFrame(); env.UIParent.l, env.UIParent.r, env.UIParent.t, env.UIParent.b = 0, 1920, 1080, 0
    env.CreateFrame = function(_, _, parent, template)
        if template == "EditModeSystemSelectionTemplate" then error("no such template offline") end
        local f = NewFrame(parent and parent.protected)
        return f
    end
    env.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
    env.InCombatLockdown = function() return combat end
    env.IsMouseButtonDown = function() return true end
    env.IsShiftKeyDown = function() return false end
    local cursor = { 0, 0 }
    env.GetCursorPosition = function() return cursor[1], cursor[2] end
    env.EditModeManagerFrame = nil           -- 還沒載入：等 PLAYER_LOGIN 保底再掛
    env.geterrorhandler = function() return function(err) env.__lastErr = err end end

    local ns = {}
    local chunk
    if setfenv then
        chunk = assert(loadfile(LIB_PATH)); setfenv(chunk, env)
    else
        chunk = assert(loadfile(LIB_PATH, "t", env))
    end
    chunk("MiliUIEditMode_test", ns)
    local M = ns.MiliUIEditMode
    check("有 runtime 框", M.runtime ~= nil)
    check("runtime 聽 PLAYER_LOGIN", M.runtime.events.PLAYER_LOGIN)
    check("runtime 聽 REGEN", M.runtime.events.PLAYER_REGEN_DISABLED and M.runtime.events.PLAYER_REGEN_ENABLED)
    eq("還沒掛勾（沒有 EditModeManagerFrame）", M.hooked, false)

    -- 暴雪的管理視窗後來才出現：登入保底掛上
    local mgr = NewFrame()
    mgr.IsEditModeActive = function() return false end
    env.EditModeManagerFrame = mgr
    env.hooksecurefunc = function(t, k, fn) t["__hook_" .. k] = fn end
    mgr.EnterEditMode = function() end
    mgr.ExitEditMode = function() end
    M.runtime.scripts.OnEvent(M.runtime, "PLAYER_LOGIN")
    eq("登入後掛勾", M.hooked, true)
    check("掛了 EnterEditMode", mgr.__hook_EnterEditMode ~= nil)

    -- Attach：模板建不出來 → 備援藍框
    local host = NewFrame(false)
    host.l, host.r, host.t, host.b = 100, 200, 300, 250
    local saved, restored, changes = nil, 0, {}
    local mover = M.Attach(host, {
        name = "測試條",
        save = function(f) saved = { M.CenterOffset(f) } end,
        restore = function() restored = restored + 1 end,
        onChange = function(active) changes[#changes + 1] = active end,
    })
    check("回傳 mover", mover ~= nil)
    eq("備援選取框", mover.isFallback, true)
    eq("選取框先藏著", mover.selection.shown, false)
    check("選取框有 ShowHighlighted", type(mover.selection.ShowHighlighted) == "function")
    eq("宿主記著 mover", host.miliuiMover, mover)

    -- 進編輯模式：旗標立刻變、派送延一幀
    mgr.scripts.OnShow()
    eq("旗標立刻 true", M.IsActive(), true)
    eq("派送還沒跑", #changes, 0)
    Flush()
    eq("派送一次", #changes, 1)
    eq("派送帶 true", changes[1], true)
    eq("選取框亮起", mover.selection.shown, true)

    -- 同一幀進出多次只派一次、送最後狀態
    mgr.scripts.OnHide(); mgr.scripts.OnShow(); mgr.scripts.OnHide()
    Flush()
    eq("合併派送", #changes, 2)
    eq("送的是最後狀態", changes[2], false)
    eq("選取框收起", mover.selection.shown, false)

    -- 同狀態重複訊號不派
    mgr.scripts.OnHide(); Flush()
    eq("同狀態不重派", #changes, 2)

    -- OnChange 聽眾
    local heard
    M.OnChange("t", function(a) heard = a end)
    mgr.__hook_EnterEditMode(); Flush()
    eq("聽眾收到", heard, true)
    M.OffChange("t")
    mgr.scripts.OnHide(); Flush()
    eq("取消後不再收", heard, true)

    -- SetForced：宿主自己說可以拖
    mover:SetForced(true); Flush()
    eq("forced 下 Editing", mover:Editing(), true)
    eq("forced 亮選取框", mover.selection.shown, true)
    eq("forced 也派 onChange", changes[#changes], true)
    mover:SetForced(false); Flush()
    eq("取消 forced", mover.selection.shown, false)

    -- 拖曳：放手 commit → save；框被移到游標差值處
    mgr.scripts.OnShow(); Flush()
    cursor[1], cursor[2] = 500, 500
    check("BeginDrag 成功", mover:BeginDrag())
    check("拖曳中", mover:IsDragging())
    eq("Dragging() 回 mover", M.Dragging(), mover)
    cursor[1], cursor[2] = 510, 520
    -- driver 是 lib 內部的 local，OnUpdate 從外面碰不到；這裡直接模擬框已被 DragTick 移到新位置，驗 save 路徑
    host.l, host.r, host.t, host.b = 110, 210, 320, 270    -- 模擬框已被 DragTick 移到新位置
    mover.selection.scripts.OnDragStop()
    check("放手後不再拖曳", not mover:IsDragging())
    check("save 被叫", saved ~= nil)
    eq("save 讀到新中心 x", saved and saved[1], 160 - 960)
    eq("save 讀到新中心 y", saved and saved[2], 295 - 540)
    eq("放手清 UserPlaced", host.userPlaced, false)
    eq("沒中斷不叫 restore", restored, 0)

    -- 戰鬥中開始拖：拒絕
    combat = true
    check("戰鬥中不能拖", not mover:BeginDrag())
    combat = false

    -- 拖到一半進戰鬥：REGEN_DISABLED 同步收掉、restore、不 save
    saved = nil
    check("再拖", mover:BeginDrag())
    combat = true
    M.runtime.scripts.OnEvent(M.runtime, "PLAYER_REGEN_DISABLED")
    check("進戰鬥收掉拖曳", not mover:IsDragging())
    eq("中斷不 save", saved, nil)
    eq("中斷叫 restore（普通框當場跑）", restored, 1)
    combat = false

    -- 戰鬥閘：保護框在戰鬥中的 Hide 記到脫戰
    local prot = NewFrame(true)
    prot.l, prot.r, prot.t, prot.b = 0, 10, 10, 0
    local pm = M.Attach(prot, { name = "保護條" })
    Flush()
    eq("保護框進編輯模式亮起（不在戰鬥）", pm.selection.shown, true)
    combat = true
    mgr.scripts.OnHide(); Flush()
    eq("戰鬥中離開：保護框的選取框還亮著（記帳）", pm.selection.shown, true)
    eq("戰鬥中離開：普通框的選取框當場收", mover.selection.shown, false)
    combat = false
    M.runtime.scripts.OnEvent(M.runtime, "PLAYER_REGEN_ENABLED")
    eq("脫戰補收", pm.selection.shown, false)

    -- enabled=false 不亮
    local off = NewFrame(false); off.l, off.r, off.t, off.b = 0, 10, 10, 0
    local om = M.Attach(off, { enabled = function() return false end })
    mgr.scripts.OnShow(); Flush()
    eq("enabled false 不亮", om.selection.shown, false)
    eq("其他的照亮", mover.selection.shown, true)

    -- canDrag=false 拒絕
    local lock = NewFrame(false); lock.l, lock.r, lock.t, lock.b = 0, 10, 10, 0
    local lm = M.Attach(lock, { canDrag = function() return false end })
    check("canDrag false 不能拖", not lm:BeginDrag())

    -- ReadBlizzard
    eq("ReadBlizzard false", M.ReadBlizzard(), false)
    mgr.IsEditModeActive = function() return "weird" end
    eq("ReadBlizzard 非布林回 nil", M.ReadBlizzard(), nil)

    -- GridSpacing 預設
    eq("GridSpacing 預設 32", M.GridSpacing(), 32)
    eq("格線看不到不吸", M.ActiveGridSpacing(), nil)
    mgr.Grid = { IsVisible = function() return true end, gridSpacing = 50 }
    eq("格線看得到用格距", M.ActiveGridSpacing(), 50)
end

print(("MiliUIEditMode: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
