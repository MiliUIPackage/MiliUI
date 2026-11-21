------------------------------------------------------------
-- Options/LiveEdit.lua（畫面編輯）＋ Core/Visibility.lua 的壓條閘（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/LiveEdit_test.lua
--
-- 兩支一起載進同一個假環境（Visibility 讀 ns.LiveEdit.Suppresses），框全是假的。
-- 覆蓋：
--   1. LE.Active 的判準矩陣（收合／視窗顯示／暴雪編輯模式／InCombatLockdown／已還給暴雪）
--   2. Eligible：不是條、沒容器、閒置面板、容器幾何是秘密值或 nil ⇒ 不畫
--   3. Refresh：畫哪幾條、Suppresses 只對畫著的條、Vis.Alpha 壓成 0、容器 alpha 0、
--      面板的「跟著核心技能淡出」讀沒壓過的值（資源條不跟著消失）、狀態變了才重套
--   4. ⚠ 進戰鬥（PLAYER_REGEN_DISABLED 當下、InCombatLockdown 還是 false）：同步把容器 alpha 還回去、
--      宿主全收、Suppresses false；拖到一半的假格當作沒放手；脫戰 0.15 秒後收合中就恢復
--   5. Visibility 自己的閘：LE 說壓但 Vis 的 inCombat／InCombatLockdown 成立 ⇒ 不壓；LE 拋錯 ⇒ 不壓
--   6. 放置目標：來源條優先、只認候選、EndDrop 收邊
--   7. 視窗關掉、進暴雪編輯模式（收合中會叫 SetCompact(false)）
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local VIS = here .. "/../Core/Visibility.lua"
local LIVE = here .. "/../Options/LiveEdit.lua"

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

------------------------------------------------------------
-- 假框
------------------------------------------------------------
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local frames = {}
local Methods = {}
local function Frame()
    local f = { shown = true, scripts = {}, alpha = 1, mouseOver = false, level = 1, events = {} }
    frames[#frames + 1] = f
    return setmetatable(f, { __index = function(_, k)
        local m = Methods[k]
        if m then return m end
        return function() end
    end })
end
function Methods.Show(f) f.shown = true end
function Methods.Hide(f) f.shown = false end
function Methods.SetShown(f, v) f.shown = v and true or false end
function Methods.IsShown(f) return f.shown end
function Methods.IsVisible(f) return f.shown end
function Methods.SetScript(f, n, fn) f.scripts[n] = fn end
function Methods.GetScript(f, n) return f.scripts[n] end
function Methods.SetAlpha(f, a) f.alpha = a end
function Methods.GetAlpha(f) return f.alpha end
function Methods.GetLeft(f) return f.left end
function Methods.GetTop(f) return f.top end
function Methods.IsMouseOver(f) return f.mouseOver end
function Methods.GetFrameLevel(f) return f.level end
function Methods.SetFrameLevel(f, l) f.level = l end
function Methods.CreateTexture() return Frame() end
function Methods.CreateFontString() return Frame() end
function Methods.GetStringWidth() return 40 end
function Methods.RegisterEvent(f, ev) f.events[ev] = true end

local timers = {}
local inLockdown = false
local env = setmetatable({}, { __index = _G })
env._G = env
env.CreateFrame = function() return Frame() end
env.UIParent = Frame()
env.GameTooltip = Frame()
env.InCombatLockdown = function() return inLockdown end
env.C_Timer = { After = function(sec, fn) timers[#timers + 1] = { sec = sec, fn = fn } end }
env.UnitExists = function() return false end
env.IsMounted = function() return false end
env.IsInInstance = function() return false, "none" end
env.IsInRaid = function() return false end
env.IsInGroup = function() return false end
local function RunTimers()
    local list = timers
    timers = {}
    for _, t in ipairs(list) do t.fn() end
end

------------------------------------------------------------
-- ns
------------------------------------------------------------
local callbacks = {}
local deferred = {}
local containers = {}
local panelShown, compact = true, true
local compactCalls = {}
local applyAllCalls, clRefresh, emRefresh = 0, 0, 0
local ns
ns = {
    L = setmetatable({}, { __index = function(_, k) return k end }),
    W = { Accent = function() return 1, 1, 1, 1 end, fontSmall = {} },
    P = { Pixel = function(n) return n end, Size = function(f, w, h) f.w, f.h = w, h end },
    IsSecret = function(v) return v == SECRET end,
    ReportError = function(e) print("ReportError: " .. tostring(e)) end,
    Defer = function(fn) deferred[#deferred + 1] = fn end,
    RegisterCallback = function(ev, _, fn) callbacks[ev] = callbacks[ev] or {}; table.insert(callbacks[ev], fn) end,
    Events = { Register = function() end },
    Setting = function() return nil end,
    profile = { bars = { essential = { visibility = {} }, utility = { visibility = {} }, cg = { visibility = {} } } },
    Bars = {
        Get = function(k) return containers[k] end,
        Dormant = function() return false end,
        AnchorPoint = function() return "TOP" end,
        ForEachClaimed = function() end,
    },
    EditMode = { active = false, RequestRefresh = function() emRefresh = emRefresh + 1 end },
    ClickLayer = { Refresh = function() clRefresh = clRefresh + 1 end },
    Options = {
        IsCompact = function() return compact end,
        SetCompact = function(on) compactCalls[#compactCalls + 1] = on; compact = on and true or false end,
        PageTitle = function(k) return k end,
        BarTitle = function(k) return k end,
    },
}
local panelCfg = { resources = { enabled = true, fadeWithEssential = true, loadConditions = {} } }
ns.DB = {
    PANEL_ORDER = { "resources" },
    IsPanel = function(k) return panelCfg[k] ~= nil end,
    ConfigTable = function(k) return panelCfg[k] or ns.profile.bars[k] end,
}
ns.Options.panel = { IsShown = function() return panelShown end }
-- 假的 bare 預覽：Refresh 結尾照真的叫 onRefresh；EndDrag 記一筆
local created = {}
ns.Preview = {
    Create = function(_, key, _, opts)
        local pv = { key = key, frame = Frame(), bare = opts and opts.bare, drop = opts and opts.drop, refreshes = 0 }
        function pv:Refresh() self.refreshes = self.refreshes + 1; if self.onRefresh then self.onRefresh(self) end end
        function pv:EndDrag(commit) self.endDrag = commit; self.press = nil end
        created[key] = pv
        return pv
    end,
}
for _, k in ipairs({ "essential", "utility", "cg", "resources" }) do
    local c = Frame()
    c.left, c.top = 100, 500
    containers[k] = c
end

local function Load(path)
    local chunk, err
    if setfenv then
        chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(path, "t", env)
    end
    assert(chunk, err)
    chunk("MiliUI_CooldownManager", ns)
end
Load(VIS)
local Vis = ns.Visibility
local applyAllReal = Vis.ApplyAll
Vis.ApplyAll = function(...) applyAllCalls = applyAllCalls + 1; return applyAllReal(...) end
Load(LIVE)
local LE = ns.LiveEdit

-- LiveEdit 檔案層建的事件框（最後一個有 PLAYER_REGEN_DISABLED 的）
local evFrame
for _, f in ipairs(frames) do
    if f.events.PLAYER_REGEN_DISABLED and f.scripts.OnEvent then evFrame = f end
end
check("LiveEdit 註冊了 PLAYER_REGEN_DISABLED／ENABLED", evFrame ~= nil and evFrame.events.PLAYER_REGEN_ENABLED == true)
local function Fire(event) evFrame.scripts.OnEvent(evFrame, event) end
local function Callback(ev, ...)
    for _, fn in ipairs(callbacks[ev] or {}) do fn(...) end
end
local function FlushDefer()
    local list = deferred
    deferred = {}
    for _, fn in ipairs(list) do fn() end
end

------------------------------------------------------------
-- 1. Active
------------------------------------------------------------
eq("收合＋顯示＋不在戰鬥 → Active", LE.Active(), true)
compact = false
eq("沒收合（視窗展開著）→ 照樣 Active", LE.Active(), true)
compact = true
panelShown = false
eq("視窗沒開 → 不 Active", LE.Active(), false)
panelShown = true
ns.EditMode.active = true
eq("暴雪編輯模式 → 不 Active", LE.Active(), false)
ns.EditMode.active = false
inLockdown = true
eq("InCombatLockdown → 不 Active", LE.Active(), false)
inLockdown = false
ns.released = true
eq("已還給暴雪 → 不 Active", LE.Active(), false)
ns.released = nil
eq("回到預設 → Active", LE.Active(), true)

------------------------------------------------------------
-- 2. Eligible
------------------------------------------------------------
eq("條＋容器 → 可畫", LE.Eligible("essential"), true)
eq("面板（不在 profile.bars）→ 不畫", LE.Eligible("resources"), false)
eq("不存在的條 → 不畫", LE.Eligible("nope"), false)
containers.cg.left = SECRET
eq("容器 left 秘密 → 不畫", LE.Eligible("cg"), false)
containers.cg.left = nil
eq("容器 left nil → 不畫", LE.Eligible("cg"), false)
containers.cg.left = 100
do
    local saved = ns.Bars.Dormant
    ns.Bars.Dormant = function(k) return k == "cg" end
    eq("閒置 → 不畫", LE.Eligible("cg"), false)
    ns.Bars.Dormant = saved
end
eq("Wants ＝ Active 且 Eligible", LE.Wants("essential"), true)
compact = false
eq("Wants：沒收合 → 照樣 true", LE.Wants("essential"), true)
compact = true

------------------------------------------------------------
-- 3. Refresh 與壓條
------------------------------------------------------------
eq("Refresh 之前不壓", LE.Suppresses("essential"), false)
applyAllCalls, clRefresh, emRefresh = 0, 0, 0
LE.Refresh()
for _, k in ipairs({ "essential", "utility", "cg" }) do
    check("畫了 " .. k, LE.hosts[k] and LE.hosts[k].holder:IsShown())
    eq("壓 " .. k, LE.Suppresses(k), true)
    check(k .. " 預覽是 bare、放置目標是 LiveEdit", created[k] and created[k].bare and created[k].drop == LE)
end
eq("面板不畫", LE.hosts.resources, nil)
eq("面板不壓", LE.Suppresses("resources"), false)
eq("狀態變了：ApplyAll 一次", applyAllCalls, 1)
eq("狀態變了：點擊層重對一次", clRefresh, 1)
eq("狀態變了：覆蓋層重對一次", emRefresh, 1)
eq("真實的條 alpha 0", containers.essential.alpha, 0)
eq("Vis.Alpha 回 0", Vis.Alpha("essential"), 0)
eq("Vis.BaseAlpha 照條件（1）", Vis.BaseAlpha("essential"), 1)
eq("Vis.Current 是壓過的", Vis.Current("essential"), 0)
eq("資源條（跟著核心技能淡出）不跟著消失", containers.resources.alpha, 1)
check("Place 錨了預覽框（onRefresh）", created.essential.refreshes >= 1)
-- 再 Refresh 一次：畫的條沒變 ⇒ 不重套
applyAllCalls, clRefresh = 0, 0
LE.Refresh()
eq("沒變：不重套 alpha", applyAllCalls, 0)
eq("沒變：不重對點擊層", clRefresh, 0)
-- 一條變得不能畫（錨到秘密錨點）⇒ 收那一條、只那一條不壓
containers.cg.top = SECRET
LE.Refresh()
eq("秘密錨點：cg 收起來", LE.hosts.cg.holder:IsShown(), false)
eq("秘密錨點：cg 不壓", LE.Suppresses("cg"), false)
eq("秘密錨點：cg 的真實條還原", containers.cg.alpha, 1)
eq("其他條照壓", LE.Suppresses("essential"), true)
containers.cg.top = 500
LE.Refresh()
eq("cg 回來", LE.Suppresses("cg"), true)

------------------------------------------------------------
-- 4. ⚠ 進戰鬥：同步還原
------------------------------------------------------------
created.utility.press = { dragging = true }
applyAllCalls = 0
-- PLAYER_REGEN_DISABLED 那一刻鎖定還沒生效：InCombatLockdown 還是 false
inLockdown = false
Fire("PLAYER_REGEN_DISABLED")
eq("進戰鬥：當場 ApplyAll（同步，不等下一幀）", applyAllCalls >= 1, true)
for _, k in ipairs({ "essential", "utility", "cg" }) do
    eq("進戰鬥：" .. k .. " 真實條 alpha 還原", containers[k].alpha, 1)
    eq("進戰鬥：" .. k .. " 不壓", LE.Suppresses(k), false)
    eq("進戰鬥：" .. k .. " 宿主收起", LE.hosts[k].holder:IsShown(), false)
    eq("進戰鬥：" .. k .. " Vis.Alpha 不是 0", Vis.Alpha(k), 1)
end
eq("進戰鬥：拖到一半當作沒放手", created.utility.endDrag, false)
eq("進戰鬥：Active false（鎖定還沒生效也一樣）", LE.Active(), false)
-- 戰鬥中任何 Refresh 都不畫
inLockdown = true
LE.Refresh()
FlushDefer()
eq("戰鬥中 Refresh：不畫", LE.hosts.essential.holder:IsShown(), false)
eq("戰鬥中 Refresh：不壓", LE.Suppresses("essential"), false)
-- 脫戰：0.15 秒後（期間又進戰鬥就作廢）
inLockdown = false
Fire("PLAYER_REGEN_ENABLED")
eq("脫戰當下還沒恢復", LE.Suppresses("essential"), false)
inLockdown = true
RunTimers()
FlushDefer()
eq("脫戰計時到期時又在戰鬥：不恢復", LE.Active(), false)
inLockdown = false
Fire("PLAYER_REGEN_ENABLED")
RunTimers()
FlushDefer()
-- Visibility 自己的 inCombat 還要它自己的 0.1 秒緩衝才清（Vis.Init 沒跑，這裡 inCombat 一直是 false）
eq("脫戰：收合中就恢復畫面編輯", LE.Suppresses("essential"), true)
eq("脫戰：真實條又壓回 0", containers.essential.alpha, 0)

------------------------------------------------------------
-- 5. Visibility 自己的閘
------------------------------------------------------------
do
    local saved = LE.Suppresses
    LE.Suppresses = function() return true end
    inLockdown = true
    eq("LE 說壓、InCombatLockdown ⇒ Vis 不壓", Vis.Alpha("essential"), 1)
    inLockdown = false
    LE.Suppresses = function() error("boom") end
    eq("LE 拋錯 ⇒ Vis 不壓", Vis.Alpha("essential"), 1)
    LE.Suppresses = saved
end
do
    -- Vis 自己的 inCombat：Init 註冊的 PLAYER_REGEN_DISABLED 處理器同步設旗標
    local handlers = {}
    ns.Events.Register = function(ev, _, fn) handlers[ev] = fn end
    Vis.Init()
    ns.Events.Register = function() end
    local saved = LE.Suppresses
    LE.Suppresses = function() return true end
    handlers.PLAYER_REGEN_DISABLED()
    eq("Vis 的 inCombat（REGEN_DISABLED 當下）⇒ 不壓", Vis.Alpha("essential"), 1)
    handlers.PLAYER_REGEN_ENABLED()
    RunTimers()
    eq("Vis 脫戰緩衝過後 ⇒ 照 LE", Vis.Alpha("essential"), 0)
    LE.Suppresses = saved
    FlushDefer()
end

------------------------------------------------------------
-- 6. 放置目標
------------------------------------------------------------
do
    local h = LE.hosts
    LE.BeginDrop({ utility = true }, "essential")
    eq("候選亮邊", h.utility.edge:IsShown(), true)
    eq("非候選不亮", h.cg.edge:IsShown(), false)
    eq("來源條不亮", h.essential.edge:IsShown(), false)
    h.utility.pv.frame.mouseOver = true
    eq("游標在候選上 → 目標", LE.DropTargetAtCursor(), "utility")
    eq("游標在候選上 → 按鈕", LE.ButtonAtCursor(), "utility")
    h.essential.pv.frame.mouseOver = true
    eq("來源條自己也在游標下 → 來源優先（不算別條）", LE.DropTargetAtCursor(), nil)
    eq("來源條優先：ButtonAtCursor 也 nil", LE.ButtonAtCursor(), nil)
    h.essential.pv.frame.mouseOver = false
    h.utility.pv.frame.mouseOver = false
    h.cg.pv.frame.mouseOver = true
    eq("非候選：不是目標", LE.DropTargetAtCursor(), nil)
    eq("非候選：ButtonAtCursor 回它（要說原因）", LE.ButtonAtCursor(), "cg")
    h.cg.pv.frame.mouseOver = false
    LE.EndDrop()
    eq("EndDrop：邊收起", h.utility.edge:IsShown(), false)
    eq("EndDrop 之後不是目標", LE.DropTargetAtCursor(), nil)
end

------------------------------------------------------------
-- 7. 關視窗、進暴雪編輯模式
------------------------------------------------------------
panelShown = false
Callback("OptionsHidden")
eq("視窗關掉：同步收（不等下一幀）", LE.Suppresses("essential"), false)
eq("視窗關掉：真實條還原", containers.essential.alpha, 1)
panelShown = true
Callback("OptionsShown")
FlushDefer()
eq("視窗再開（收合中）：恢復", LE.Suppresses("essential"), true)
compactCalls = {}
ns.EditMode.active = true
Callback("EditModeChanged", true)
eq("進編輯模式：叫 SetCompact(false)", compactCalls[1], false)
FlushDefer()
eq("進編輯模式：不壓", LE.Suppresses("essential"), false)
eq("進編輯模式：真實條還原", containers.essential.alpha, 1)
ns.EditMode.active = false

-- 條名籤：KeyOfTag 只認畫著的
eq("KeyOfTag：沒畫時不認", LE.KeyOfTag(LE.hosts.essential.tag), nil)

print(("LiveEdit_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
