------------------------------------------------------------
-- 點擊穿透：滑鼠點下去落到視窗後面的東西（怪、地面），不被統計視窗吃掉
--
-- 每視窗三個設定：
--   wdb.clickThrough          "off"（預設）｜"combat"（只在戰鬥中）｜"always"
--   wdb.clickThroughHeader    標題列也穿透（預設 false：拖曳與按鈕照樣能用）
--   wdb.clickThroughModifier  "ALT"（預設）｜"SHIFT"｜"CTRL"｜"NONE"：按住時暫時恢復可點
--
-- 穿透生效時關掉的：內容框本體的滑鼠與滾輪、每一列（含右欄與釘住自己那列）、
-- 捲動區的滾輪；clickThroughHeader 開著再加上標題列與它上面的每一顆按鈕
-- （子框不會跟著父框關，得一顆一顆關）。首頁／展開頁是玩家自己打開的，維持可點。
--
-- ⚠ 只准用 EnableMouse／EnableMouseWheel。SetPassThroughButtons／SetPropagateMouseClicks／
--   SetPropagateMouseMotion 戰鬥中對**任何**框都封鎖（見 wow-hasrestrictions-mouse-apis），
--   「只在戰鬥中穿透」用那三支等於一進戰就壞。EnableMouse 對非保護框戰鬥中照樣能叫，
--   而這裡動的全是內容框那一棵（定位框才會被牽連成保護框，見 Window.lua）。
--
-- 編輯模式或設定視窗開著時一律可點（跟收合、顯示條件同一條規矩）。
-- 值沒變就不重呼叫 setter：W._mouseOn（本體）／W._hdrMouseOn（標題列）記著上次套的值。
------------------------------------------------------------
local _, ns = ...

ns.ClickThrough = {}
local CT = ns.ClickThrough

-- 「只在戰鬥中」看的是 PLAYER_REGEN_* 自己記的旗標，不是 InCombatLockdown()：
-- PLAYER_REGEN_DISABLED 發火時鎖定還沒生效，那一刻 InCombatLockdown() 仍是 false。
-- 也不看 ns.Combat.IsInCombat()（隊伍戰鬥）——玩家自己沒進戰，點怪就是要點得到視窗。
local _inCombat = InCombatLockdown() and true or false

local MOD_DOWN = {
    ALT   = IsAltKeyDown,
    SHIFT = IsShiftKeyDown,
    CTRL  = IsControlKeyDown,
}

local function Forced()
    return ns.Move.IsEditing() or ns._optionsOpen
end

local function ModifierOf(wdb)
    return wdb.clickThroughModifier or "ALT"
end

-- 這個視窗現在要不要穿透
local function Passing(W)
    local wdb = W.wdb
    local mode = wdb.clickThrough
    if mode ~= "always" and not (mode == "combat" and _inCombat) then return false end
    if Forced() then return false end
    local down = MOD_DOWN[ModifierOf(wdb)]
    if down and down() then return false end
    return true
end

------------------------------------------------------------
-- setter
------------------------------------------------------------
local function SetPaneMouse(pane, on)
    if not pane then return end
    pane.viewport:EnableMouseWheel(on)
    for _, bar in ipairs(pane.rowPool) do bar.row:EnableMouse(on) end
    pane.stickyBar.row:EnableMouse(on)
end

local function SetBodyMouse(W, on)
    W.frame:EnableMouse(on)
    W.frame:EnableMouseWheel(on)
    SetPaneMouse(W, on)
    SetPaneMouse(W.split, on)   -- 右欄懶建；建出來時 EnsureSplitPane 會 force 重套一次
end

local function SetHeaderMouse(W, on)
    W.header:EnableMouse(on)
    W.typeBtn:EnableMouse(on)
    W.segBtn:EnableMouse(on)
    for _, btn in ipairs(W.hdrButtons) do btn:EnableMouse(on) end
end

------------------------------------------------------------
-- 按鍵事件：只有「有視窗會穿透、而且設了暫時恢復鍵」時才註冊（閘下在註冊面）
------------------------------------------------------------
local evFrame = CreateFrame("Frame")
evFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
evFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
local _modRegistered = false

local function SyncModifierEvent()
    local any = false
    if ns.Windows then
        ns.Windows.ForEach(function(W) if W._ctWantsMod then any = true end end)
    end
    if any == _modRegistered then return end
    _modRegistered = any
    if any then
        evFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
    else
        evFrame:UnregisterEvent("MODIFIER_STATE_CHANGED")
    end
end

------------------------------------------------------------
-- 套用
------------------------------------------------------------
-- force：不管備忘，整組重設（新建了一批列的時候）
function CT.Apply(W, force)
    if not W or not W.frame or not W.header then return end
    local pass = Passing(W)
    local body = not pass
    local hdr = not (pass and W.wdb.clickThroughHeader)

    if force or W._mouseOn ~= body then
        W._mouseOn = body
        SetBodyMouse(W, body)
        -- 游標正停在某一列上的話，關掉滑鼠之後不保證收得到 OnLeave，預覽自己收
        if not body then ns.Tooltip.HideFor(W) end
    end
    if force or W._hdrMouseOn ~= hdr then
        W._hdrMouseOn = hdr
        SetHeaderMouse(W, hdr)
    end

    local mode = W.wdb.clickThrough
    local wants = (mode == "always" or mode == "combat") and MOD_DOWN[ModifierOf(W.wdb)] ~= nil
    if W._ctWantsMod ~= wants then
        W._ctWantsMod = wants
        SyncModifierEvent()
    end
end

function CT.ApplyAll()
    if not ns.Windows then return end
    ns.Windows.ForEach(function(W) CT.Apply(W) end)
end

evFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        _inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        _inCombat = false
    end
    -- MODIFIER_STATE_CHANGED：按下／放開哪一顆都重問一次（Passing 讀的是當下的按鍵狀態），
    -- 跟這個視窗設的鍵無關的那幾下，備忘會讓它什麼都不做
    CT.ApplyAll()
end)
