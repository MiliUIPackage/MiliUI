------------------------------------------------------------
-- MiliUIMinimapButton.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua AddOns/MiliUI/Libs/MiliUIMinimapButton/Tests/MiliUIMinimapButton_test.lua
--   （.claude/scripts/run_tests.sh 會一起跑）
--
-- 純函式直接驗數字；執行期用最小 stub 驗：Apply 建／藏、存檔沒就位不建、點一下 vs 拖曳的
-- 判定與角度寫回、被收納袋收走（父層不是 Minimap）後不拖不定位、頭像模式的退路。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local LIB_PATH = here .. "/../MiliUIMinimapButton.lua"

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then passed = passed + 1
    else failed = failed + 1; print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or "")) end
end
local function eq(name, got, want) check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want)) end
local function near(name, got, want) check(name, type(got) == "number" and math.abs(got - want) < 1e-6, "got " .. tostring(got) .. ", want " .. tostring(want)) end

------------------------------------------------------------
-- stub
------------------------------------------------------------
local cursor, mouseDown, now = { 0, 0 }, false, 0
local function NewFrame(kind, name, parent)
    local f = { kind = kind, name = name, parent = parent, shown = true, scripts = {}, events = {}, regions = {}, points = {} }
    function f:Show() self.shown = true end
    function f:Hide() self.shown = false end
    function f:IsShown() return self.shown end
    function f:SetShown(v) self.shown = v and true or false end
    function f:GetParent() return self.parent end
    function f:GetName() return self.name end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:RegisterEvent(e) self.events[e] = true end
    function f:RegisterUnitEvent(e, u) self.events[e] = u end
    function f:RegisterForClicks() end
    function f:SetFrameStrata() end
    function f:SetFrameLevel() end
    function f:SetSize(w, h) self.w, self.h = w, h end
    function f:GetWidth() return self.w end
    function f:ClearAllPoints() self.points = {} end
    function f:SetPoint(p, rel, rp, x, y) self.points[#self.points + 1] = { p, rel, rp, x, y } end
    function f:GetCenter() return self.cx, self.cy end
    function f:GetEffectiveScale() return 1 end
    function f:CreateTexture()
        local t = NewFrame("Texture")
        function t:SetTexture(v) self.tex = v end
        function t:GetTexture() return self.tex end
        function t:SetTexCoord() end
        function t:SetMask() end
        self.regions[#self.regions + 1] = t
        return t
    end
    return f
end

local env = setmetatable({}, { __index = _G })
env.Minimap = NewFrame("Frame", "Minimap"); env.Minimap.w = 200; env.Minimap.cx, env.Minimap.cy = 1000, 500
env.CreateFrame = function(kind, name, parent) return NewFrame(kind, name, parent) end
env.GetCursorPosition = function() return cursor[1], cursor[2] end
env.IsMouseButtonDown = function() return mouseDown end
env.GetTime = function() return now end
env.GameTooltip = { owner = nil }
function env.GameTooltip:SetOwner(o) self.owner = o end
function env.GameTooltip:IsOwned(o) return self.owner == o end
function env.GameTooltip:Hide() self.owner = nil end
function env.GameTooltip:Show() end
function env.GameTooltip:AddLine(t) self.last = t end
local portraitOK = false
env.SetPortraitTexture = function(tex) if portraitOK then tex:SetTexture("portrait") else error("no portrait yet") end end

local ns = {}
local chunk
if setfenv then chunk = assert(loadfile(LIB_PATH)); setfenv(chunk, env)
else chunk = assert(loadfile(LIB_PATH, "t", env)) end
chunk("MiliUIMinimapButton_test", ns)
local M = ns.MiliUIMinimapButton
check("掛在 ns.MiliUIMinimapButton", type(M) == "table")

------------------------------------------------------------
-- 純函式
------------------------------------------------------------
do
    local x, y = M.OffsetFor(0, 200)
    near("0 度在右邊", x, 105); near("0 度 y=0", y, 0)
    x, y = M.OffsetFor(90, 200)
    near("90 度 x≈0", x, 0); near("90 度在上面", y, 105)
    x, y = M.OffsetFor(nil, 200)
    local dx, dy = M.OffsetFor(M.DEFAULT_ANGLE, 200)
    near("角度 nil 用預設 x", x, dx); near("角度 nil 用預設 y", y, dy)

    near("AngleFor 右邊 0 度", M.AngleFor(1100, 500, 1000, 500), 0)
    near("AngleFor 上面 90 度", M.AngleFor(1000, 600, 1000, 500), 90)
    near("AngleFor 左邊 180 度", M.AngleFor(900, 500, 1000, 500), 180)

    check("沒動不算拖", not M.IsDrag(3, 3, 1))
    check("動了但太快不算拖", not M.IsDrag(20, 0, 0.05))
    check("動了且按夠久算拖", M.IsDrag(20, 0, 0.2))
    check("只動 y 也算", M.IsDrag(0, -20, 0.2))
end

------------------------------------------------------------
-- 執行期
------------------------------------------------------------
do
    eq("Create 沒名字回 nil", M.Create({}), nil)

    local db = nil
    local clicks, tips = {}, 0
    local h = M.Create({
        name = "MiliUITest_MinimapButton", icon = "icon.tga",
        db = function() return db end,
        shown = function() return db and db.show end,
        onClick = function(button) clicks[#clicks + 1] = button end,
        tooltip = function(tt, onMinimap) tips = tips + 1; tt:AddLine(onMinimap and "on" or "bag") end,
    })
    check("Create 回 handle", h ~= nil)
    h:Apply()
    eq("存檔沒就位不建", h:Button(), nil)

    db = { show = false }
    h:Apply()
    eq("shown=false 不建", h:Button(), nil)

    db.show = true
    h:Apply()
    local btn = h:Button()
    check("Apply 建了按鈕", btn ~= nil)
    eq("全域名", btn.name, "MiliUITest_MinimapButton")
    eq("父層 Minimap", btn.parent, env.Minimap)
    eq("寬 31", btn.w, 31)
    check("收納袋記號", btn.miliuiMinimapButton == true)
    check(".icon 欄位", btn.icon ~= nil and btn.icon.tex == "icon.tga")
    check("顯示", btn.shown)
    eq("預設角度", h:Angle(), M.DEFAULT_ANGLE)
    local p = btn.points[1]
    local ex, ey = M.OffsetFor(M.DEFAULT_ANGLE, 200)
    check("錨在小地圖中心偏移", p and p[1] == "CENTER" and p[2] == env.Minimap and math.abs(p[4] - ex) < 1e-6 and math.abs(p[5] - ey) < 1e-6)

    db.show = false; h:Apply()
    eq("Apply 藏", btn.shown, false)
    db.show = true; h:Apply()
    eq("Apply 再顯示", btn.shown, true)
    eq("再 Apply 不重建", h:Button(), btn)

    -- 點一下（沒動）
    now = 0; cursor = { 100, 100 }; mouseDown = true
    btn.scripts.OnMouseDown(btn, "LeftButton")
    now = 1
    btn.scripts.OnUpdate(btn)
    mouseDown = false
    btn.scripts.OnMouseUp(btn, "LeftButton")
    eq("點一下 → onClick", clicks[1], "LeftButton")
    eq("OnUpdate 清掉", btn.scripts.OnUpdate, nil)

    -- 右鍵
    btn.scripts.OnMouseDown(btn, "RightButton")
    eq("右鍵不掛 OnUpdate", btn.scripts.OnUpdate, nil)
    btn.scripts.OnMouseUp(btn, "RightButton")
    eq("右鍵 → onClick", clicks[2], "RightButton")

    -- 拖曳：移 50px、按 0.5 秒 → 角度寫回、不 onClick
    now = 0; cursor = { 1000, 500 }; mouseDown = true
    btn.scripts.OnMouseDown(btn, "LeftButton")
    now = 0.5; cursor = { 1000, 600 }           -- 正上方
    btn.scripts.OnUpdate(btn)
    check("進入拖曳", btn.dragging)
    near("角度寫回 90", db.angle, 90)
    local last = btn.points[#btn.points]
    near("位置跟著角度 y", last[5], 105)
    mouseDown = false
    btn.scripts.OnMouseUp(btn, "LeftButton")
    eq("拖完不 onClick", #clicks, 2)
    eq("拖完清旗標", btn.dragging, false)

    -- 微動不算拖
    now = 0; cursor = { 0, 0 }; mouseDown = true
    btn.scripts.OnMouseDown(btn, "LeftButton")
    now = 1; cursor = { 5, 5 }
    btn.scripts.OnUpdate(btn)
    check("微動不算拖", not btn.dragging)
    btn.scripts.OnMouseUp(btn, "LeftButton")
    eq("微動放開算點", #clicks, 3)

    -- 游標移出且鍵已放開：OnUpdate 自己收掉
    now = 0; mouseDown = true
    btn.scripts.OnMouseDown(btn, "LeftButton")
    mouseDown = false
    btn.scripts.OnUpdate(btn)
    eq("鍵放開 OnUpdate 自收", btn.scripts.OnUpdate, nil)

    -- tooltip
    btn.scripts.OnEnter(btn)
    eq("tooltip 加行", env.GameTooltip.last, "on")
    eq("tooltip owner", env.GameTooltip.owner, btn)
    btn.scripts.OnLeave(btn)
    eq("離開收 tooltip", env.GameTooltip.owner, nil)

    -- 被收納袋收走：父層不是 Minimap
    local bag = NewFrame("Frame", "MiliUIMinimapButtonBag")
    btn.parent = bag
    check("不在小地圖上", not h:OnMinimap())
    local n = #btn.points
    h:Apply()
    eq("收走後 Apply 不重新定位", #btn.points, n)
    db.angle = 90
    btn.scripts.OnMouseDown(btn, "LeftButton")
    eq("收走後不拖", btn.scripts.OnUpdate, nil)
    btn.scripts.OnEnter(btn)
    eq("收走後 tooltip 知道", env.GameTooltip.last, "bag")
    btn.parent = env.Minimap

    -- 頭像模式
    local pdb = { angle = 10 }
    local ph = M.Create({ name = "MiliUIPortrait_MinimapButton", icon = "fallback", portrait = "player", db = pdb })
    ph:Apply()
    local pb = ph:Button()
    check("建了頭像貼圖", pb.portrait ~= nil)
    eq("頭像拿不到 → 藏頭像", pb.portrait.shown, false)
    eq("頭像拿不到 → 顯示 icon", pb.icon.shown, true)
    check("頭像事件框只綁 player", ph.events and ph.events.events.UNIT_PORTRAIT_UPDATE == "player")
    portraitOK = true
    ph.events.scripts.OnEvent(ph.events, "PORTRAITS_UPDATED")
    eq("頭像到了 → 顯示頭像", pb.portrait.shown, true)
    eq("頭像到了 → 藏 icon", pb.icon.shown, false)
    eq("db 直接給表也行", ph:Angle(), 10)
end

print(("MiliUIMinimapButton: %d passed, %d failed"):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
