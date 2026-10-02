------------------------------------------------------------
-- 群組跟著游標（自訂圖示群組的 bar.cursor = { enabled, x, y }）
--
--   ns.Cursor.Eligible(bar, hasAuraSlot) → ok, reason   純函式：這條能不能跟（reason："kind"｜"aura"｜"click"）
--   ns.Cursor.Configured(key)    開著、而且條件成立。排開／錨定候選剔除它看這個（跟編輯模式無關 ⇒ 穩定）
--   ns.Cursor.Following(key)     現在真的跟著游標：Configured，而且不在編輯模式、設定視窗沒開
--   ns.Cursor.Point(cx, cy, scale, ox, oy) → x, y   純函式：游標（螢幕像素）→ UIParent 座標＋位移
--   ns.Cursor.Place(f, key)      貼到游標旁邊（Core/Bars.lua 的 PlaceContainer 在 ns.Write 裡叫）
--   ns.Cursor.Refresh()          重判要不要掛 OnUpdate（Bars 套完結構、顯示條件變了、進出編輯模式／設定視窗）
--
-- 只收**自訂的圖示群組**，而且上面**沒有光環格、沒勾可點擊**：那兩種會讓容器變成保護框（光環格的持有框、
-- 點擊用的 secure 鈕都錨在容器上，保護沿錨點鏈往上傳），戰鬥中不能移。條件不成立時設定值照存、不生效。
--
-- 做法：一顆共用的 driver 框的 OnUpdate 每幀 GetCursorPosition()／UIParent:GetEffectiveScale()
-- → 容器 ClearAllPoints＋SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)（走 ns.Write）。
-- **只在有這種條、而且那條的 alpha > 0（Visibility 自己記的 Current，不讀框）時才掛 OnUpdate**，否則卸掉。
-- 掛之前（Refresh）與每一幀都先問 ns.IsProtectedFrame(容器)：是的話那條這一輪不動、記一筆 Diag（理論上
-- 不會發生：條件已經排除了會變保護框的兩種東西）。
-- 編輯模式中、設定視窗開著時回到存檔位置（不然拖不了、點擊層也點不到）。
-- 跟著游標的條不參與排開、也不能被別條錨定：Bars 給排開／錨定看的設定表把它當不存在
-- （已經錨著它的條改用自己的位置，錨定候選清單也剔掉它）。
------------------------------------------------------------
local _, ns = ...

ns.Cursor = {}
local Cur = ns.Cursor

Cur.DEFAULT_X, Cur.DEFAULT_Y = 20, -20

local driver                        -- 共用的 OnUpdate 框（第一次要用才建）
local active = {}                   -- key → 容器（這一輪要跟著游標動的）
local lastX, lastY = {}, {}         -- key → 上次貼的位置（沒動就不重貼；兩張表，不每幀配新表）
local noted = {}                    -- key → true：保護框那筆 Diag 記過了
local optionsShown = false
Cur.ticks = 0
Cur.skipped = 0

------------------------------------------------------------
-- 純函式
------------------------------------------------------------
function Cur.Eligible(bar, hasAuraSlot)
    if type(bar) ~= "table" or bar.kind ~= "icons" or bar.source ~= "custom" then return false, "kind" end
    if hasAuraSlot then return false, "aura" end
    if bar.clickable == true then return false, "click" end
    return true
end

-- 位移（沒存／壞值用預設）
function Cur.Offsets(bar)
    local c = type(bar) == "table" and type(bar.cursor) == "table" and bar.cursor or {}
    return tonumber(c.x) or Cur.DEFAULT_X, tonumber(c.y) or Cur.DEFAULT_Y
end

function Cur.Point(cx, cy, scale, ox, oy)
    scale = tonumber(scale) or 1
    if scale <= 0 then scale = 1 end
    return (tonumber(cx) or 0) / scale + (tonumber(ox) or 0), (tonumber(cy) or 0) / scale + (tonumber(oy) or 0)
end

------------------------------------------------------------
-- 判準
------------------------------------------------------------
local function BarTable(key)
    return ns.DB and ns.DB.BarTable and ns.DB.BarTable(key) or nil
end

function Cur.Configured(key)
    local bar = BarTable(key)
    if type(bar) ~= "table" or type(bar.cursor) ~= "table" or bar.cursor.enabled ~= true then return false end
    local hasAura = ns.Catalog and ns.Catalog.BarHasAuraSlot and ns.Catalog.BarHasAuraSlot(key) or false
    return (Cur.Eligible(bar, hasAura)) and true or false
end

-- 設定視窗開著（回呼記的旗標；保險再問一次視窗本身）
local function OptionsOpen()
    if optionsShown then return true end
    local panel = ns.Options and ns.Options.panel
    if panel and panel.IsShown then
        local ok, v = pcall(panel.IsShown, panel)
        return ok and v == true
    end
    return false
end

function Cur.Following(key)
    if ns.released or not Cur.Configured(key) then return false end
    if ns.EditMode and ns.EditMode.active then return false end
    return not OptionsOpen()
end

------------------------------------------------------------
-- 貼位置
------------------------------------------------------------
local moveX, moveY = 0, 0
local function Mover(f)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", moveX, moveY)
end

local function CursorPoint(key)
    local cx, cy = 0, 0
    if GetCursorPosition then cx, cy = GetCursorPosition() end
    local scale = UIParent and UIParent.GetEffectiveScale and UIParent:GetEffectiveScale() or 1
    local ox, oy = Cur.Offsets(BarTable(key))
    return Cur.Point(cx, cy, scale, ox, oy)
end

-- PlaceContainer 叫（已經在 ns.Write 裡）
function Cur.Place(f, key)
    local x, y = CursorPoint(key)
    f:ClearAllPoints()
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
    lastX[key], lastY[key] = x, y
end

local function NoteProtected(key)
    Cur.skipped = Cur.skipped + 1
    if noted[key] then return end
    noted[key] = true
    if ns.Diag and ns.Diag.Note then
        ns.Diag.Note("cursor", ("跟著游標：%s 的容器是保護框，這一輪不動"):format(tostring(key)))
    end
end

local Refresh                        -- 前置宣告

local function Tick()
    Cur.ticks = Cur.ticks + 1
    if ns.released then active = {} end              -- 已還給暴雪（/mcdm release）：停
    local combat = InCombatLockdown()
    for key, c in pairs(active) do
        if combat and ns.IsProtectedFrame(c) then
            -- 不該發生（條件已經排除了會變保護框的東西）：這條停下來、記一筆，下次 Refresh 再判
            active[key] = nil
            NoteProtected(key)
        else
            local x, y = CursorPoint(key)
            if lastX[key] ~= x or lastY[key] ~= y then
                moveX, moveY = x, y
                ns.Write(c, Mover, "cursor")
                lastX[key], lastY[key] = x, y
            end
        end
    end
    if next(active) == nil and driver then driver:SetScript("OnUpdate", nil) end
end

-- 這條現在看不看得到：Visibility 自己記的 alpha（還沒套過＝看得到）；不讀框
local function Visible(key)
    local V = ns.Visibility
    local a = V and V.Current and V.Current(key)
    if a == nil then return true end
    return (tonumber(a) or 1) > 0
end

Refresh = function()
    local p = ns.profile
    local want = {}
    if p and type(p.bars) == "table" and not ns.released then
        for key in pairs(p.bars) do
            if Cur.Following(key) and Visible(key) then
                local c = ns.Bars and ns.Bars.Get and ns.Bars.Get(key)
                if c then
                    if ns.IsProtectedFrame(c) then
                        NoteProtected(key)
                    else
                        noted[key] = nil
                        want[key] = c
                    end
                end
            end
        end
    end
    active = want
    for key in pairs(lastX) do
        if not want[key] then lastX[key], lastY[key] = nil, nil end
    end
    if next(active) then
        if not driver then driver = CreateFrame("Frame") end
        driver:SetScript("OnUpdate", Tick)
    elseif driver then
        driver:SetScript("OnUpdate", nil)
    end
end
Cur.Refresh = Refresh

-- Visibility 套完某一條的 alpha（只理會設了跟著游標的條）
function Cur.OnAlpha(key)
    if Cur.Configured(key) then Refresh() end
end

-- 進出編輯模式、設定視窗開關：設了跟著游標的條重套結構（PlaceContainer 照現況貼游標或存檔位置）
local function Transition()
    local p = ns.profile
    if p and type(p.bars) == "table" and ns.Bars and ns.Bars.ApplyStructure then
        for key in pairs(p.bars) do
            if Cur.Configured(key) and ns.Bars.Get(key) then
                local ok, err = xpcall(ns.Bars.ApplyStructure, ns.ReportError, key)
                if not ok then Cur.lastError = err end
            end
        end
    end
    Refresh()
end
Cur.Transition = Transition

function Cur.IsActive(key) return active[key] ~= nil end
function Cur.ActiveCount()
    local n = 0
    for _ in pairs(active) do n = n + 1 end
    return n
end

-- /mcdm debug（開發用，不進語系檔）
function Cur.DebugLine()
    local list = {}
    local p = ns.profile
    for key in pairs(p and p.bars or {}) do
        if Cur.Configured(key) then
            list[#list + 1] = ("%s%s"):format(key, active[key] and "（跟著）" or (Cur.Following(key) and "（看不到，停）" or "（存檔位置）"))
        end
    end
    if #list == 0 then return nil end
    table.sort(list)
    return ("  跟著游標：%s  OnUpdate %s  跑了 %d 幀  保護框擋下 %d 次")
        :format(table.concat(list, "、"), (driver and driver:GetScript("OnUpdate")) and "掛著" or "卸了", Cur.ticks, Cur.skipped)
end

local initialized = false
function Cur.Init()
    if initialized then return end
    initialized = true
    -- 這幾個訊號可能在暴雪的流程裡同步派送（編輯模式進出）⇒ 延一幀
    ns.RegisterCallback("EditModeChanged", "cursor", function() ns.Defer(Transition) end)
    ns.RegisterCallback("OptionsShown", "cursor", function() optionsShown = true; ns.Defer(Transition) end)
    ns.RegisterCallback("OptionsHidden", "cursor", function() optionsShown = false; ns.Defer(Transition) end)
    Refresh()
end
