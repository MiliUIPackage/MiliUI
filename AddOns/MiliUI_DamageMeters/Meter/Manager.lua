------------------------------------------------------------
-- 視窗管理：建立、數量調整、統一套用、選單
--
-- ⚠ **視窗建了就不銷毀，只是藏起來。**
--   WoW 的 frame 刪不掉（見 wow-frame-lifecycle-costs）—— 常見的「Destroy」寫法是
--   Hide + SetParent(nil)，玩家把視窗數 3→1→3 來回調就會留下一堆孤兒 frame。
--   這裡改成池化：_pool[idx] 建一次，數量只決定「顯示到第幾個」。
--   代價是關掉的視窗仍佔記憶體（一個約 90 個 frame），但它本來就刪不掉。
------------------------------------------------------------
local _, ns = ...

ns.Windows = {}
local Windows = ns.Windows
local D = ns.Data
local Win = ns.Window

local _pool = {}      -- idx → W（建過就一直在）
local _active = 0     -- 目前顯示到第幾個

------------------------------------------------------------
-- 走訪
------------------------------------------------------------
function Windows.ForEach(fn)
    for i = 1, _active do
        local W = _pool[i]
        if W and W.frame then fn(W) end
    end
end

function Windows.Get(idx) return _pool[idx] end
function Windows.Count() return _active end

------------------------------------------------------------
-- 建立／數量調整
------------------------------------------------------------
local function EnsureWindow(idx)
    if _pool[idx] then
        -- 池裡已經有：重新綁一次 DB（換 profile／還原預設值後 wdb 會是新的表）
        _pool[idx].wdb = ns.DB.Win(idx)
        return _pool[idx]
    end
    local ok, W = xpcall(Win.Create, ns.ReportError, idx)
    if not ok or not W then return nil end
    _pool[idx] = W
    return W
end

function Windows.Rebuild()
    local want = ns.DB.WindowCount()

    for i = 1, want do
        local W = EnsureWindow(i)
        if W then
            W.ApplyStyle()
            ns.Move.ApplyPosition(W)
            Win.UpdateTitle(W)
            Win.UpdateLockIcon(W)
            ns.Move.ApplyLock(W)
        end
    end
    -- 多出來的藏起來（不銷毀）
    for i = want + 1, ns.DB.MAX_WINDOWS do
        local W = _pool[i]
        if W and W.frame then
            ns.Breakdown.Close(W)
            ns.Home.Hide(W)
            ns.Tooltip.HideFor(W)
            W.frame:Hide()
        end
    end

    _active = want
    Windows.ForEach(function(W)
        Win.UpdateVisibility(W)
        W.Refresh()
    end)
    -- 登入／調整視窗數之後把智慧顯示的視圖擺對（脫戰＝總計）。
    -- 非 force：正在看特定分段的視窗不動
    Windows.SmartApply(ns.Combat.IsInCombat())
    ns.Move.UpdateEditState()
end

------------------------------------------------------------
-- 統一套用
------------------------------------------------------------
function Windows.ApplyStyle()
    D.RebuildNumberFormat()
    -- 右鍵選單的引擎在共用層，字型要由宿主餵進去 ——
    -- 它長在遊戲畫面上、貼著統計視窗開，跟著視窗自己的字型才不會突兀
    local s = ns.DB.Style()
    if ns.W and ns.W.SetMenuFont and s then ns.W.SetMenuFont(s.font, 12) end
    Windows.ForEach(function(W)
        W.ApplyStyle()
        ns.Move.ApplyLock(W)
        W.Refresh()
        if W.homeFrame and W.homeFrame:IsShown() then ns.Home.Refresh(W) end
    end)
    ns.Combat.RestartTicker()   -- 刷新率可能改了
end

------------------------------------------------------------
-- 快取作廢：**資料**與**外觀**要分開，這不是潔癖
--
-- 分段更新（有人死掉、首領被擊殺、伺服器換 session）改變的是**資料**，外觀沒動。
-- 兩個一起清掉的話，`_barCacheKey` 一 nil 就會讓四十條長條整批重排版面 ——
-- 而分段更新事件在戰鬥中是連續打的 —— 整批重排會是這條路徑上最大的一筆成本。
--
--   InvalidateData  資料快取。分段更新、離開戰鬥走這個。
--   InvalidateAll   資料 ＋ 外觀。只有「分段邊界」（開打、重置資料）走這個 ——
--                   一場戰鬥一次，代價可以接受，換到一個乾淨的起點。
------------------------------------------------------------
function Windows.InvalidateData()
    ns.Breakdown.InvalidateCaches()
    Windows.ForEach(function(W)
        W._barSources = nil
        W._cachedTargets = nil
        W._timerSec = nil
        W._segDur = nil
    end)
end

function Windows.InvalidateAll()
    Windows.InvalidateData()
    Windows.ForEach(function(W)
        W._barCacheKey = nil
        W._stickyCacheKey = nil
    end)
end

function Windows.UpdateVisibility()
    Windows.ForEach(function(W) Win.UpdateVisibility(W) end)
end

-- 戰鬥開始：正在看歷史分段的視窗跳回「本場」（每視窗可關）。
-- 看「總計」的不動——那本來就是要跨場累積的。
------------------------------------------------------------
-- 智慧顯示：戰鬥中看「目前」、脫戰看「總計」
--
-- 只在兩個戰鬥邊界動手（BeginSegment / FreezeCombat，見 Meter/Combat.lua），
-- 平時完全不跑。**豁免是無狀態的**：玩家正在看特定的歷史分段
-- （curSessionID ~= nil）就不干預 —— 他自己切回「目前／總計」的那一刻
-- curSessionID 歸 nil，智慧顯示自然恢復，不需要另外記一個「被暫停」旗標。
-- 唯一的例外是「玩家剛把智慧顯示打開」（force）：規格說重新開啟就恢復主動切換，
-- 這時連豁免都拿掉。
--
-- 刻意**不走 Win.SetSegment**：那支會沿 syncSegments 傳播。智慧切換是
-- 每個開了智慧顯示的視窗各自處理 —— 走傳播的話，一個開智慧、一個沒開但有連動
-- 的組合會被拖著走。
------------------------------------------------------------
local function SmartApplyFor(W, inCombat, force)
    if not W.wdb.smartDisplay then return end
    if W.curSessionID ~= nil and not force then return end
    local target = inCombat and D.S.Current or D.S.Overall
    if W.curSessionID == nil and W.curSession == target then return end
    W.curSessionID = nil
    W.curSession = target
    W.wdb.curSession = target
    -- 只清資料相關的備忘，不動 _barCacheKey：換分段改的是資料不是版面，
    -- 智慧切換一場戰鬥跑兩次，nil 掉版面快取等於每場白白整批重排兩回
    W._timerSec = nil
    W._segDur = nil
    W._cachedTargets = nil
    ns.Breakdown.Close(W)
    Win.UpdateTitle(W)
    W.Refresh()
end

function Windows.SmartApply(inCombat)
    Windows.ForEach(function(W) SmartApplyFor(W, inCombat, false) end)
end

-- 開關的唯一入口（右鍵選單與設定頁都走這裡）。
-- 打開的那一刻立刻恢復主動切換 —— 連「正在看特定分段」的豁免都拿掉（規格）。
function Windows.SetSmartDisplay(W, on)
    W.wdb.smartDisplay = on and true or false
    if on then SmartApplyFor(W, ns.Combat.IsInCombat(), true) end
end

------------------------------------------------------------
-- 「這是哪個視窗」的識別覆蓋層
--
-- 「各視窗」分頁一次只設定一個視窗，但畫面上有好幾個長得一模一樣的框 ——
-- 玩家沒辦法知道自己正在調哪一個。開那一頁時就在每個視窗上蓋一層編號，
-- 並且把**正在編輯的那個**用強調色標出來。編輯模式的老套路，不是新發明。
--
-- 名稱走 Windows.Label：跟下拉選單裡的字**必須一字不差**，
-- 兩邊各拼各的日後改一邊就對不起來。
------------------------------------------------------------
function Windows.Label(idx)
    return ns.L["Window"] .. " " .. idx
end

local function EnsureIdentify(W)
    if W.identify then return W.identify end
    local f = CreateFrame("Frame", nil, W.frame, "BackdropTemplate")
    f:SetAllPoints(W.frame)
    -- 蓋在展開頁（+30）與首頁（+25）之上；不改 strata，免得跨視窗互相遮住
    f:SetFrameLevel(W.frame:GetFrameLevel() + 60)
    f:EnableMouse(false)          -- 純標示，不能吃掉點擊與拖曳
    f:SetBackdrop({ edgeFile = ns.Media.WHITE8X8, edgeSize = 2 })

    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()

    f.label = f:CreateFontString(nil, "OVERLAY")
    f.label:SetPoint("CENTER")
    f:Hide()
    W.identify = f
    return f
end

-- selectedIdx = 目前在設定頁選中的那個（其餘的畫成次要）
function Windows.ShowIdentify(selectedIdx)
    Windows.ForEach(function(W)
        local f = EnsureIdentify(W)
        local on = (W.idx == selectedIdx)
        -- 兩者都鋪一層暗底：編號要讀得出來，而且「現在處於設定狀態」本身就該有感
        f.bg:SetColorTexture(0, 0, 0, on and 0.35 or 0.6)
        if on then
            f:SetBackdropBorderColor(ns.Media.Accent())
            f.label:SetTextColor(ns.Media.Accent())
        else
            f:SetBackdropBorderColor(0.35, 0.35, 0.35, 1)
            f.label:SetTextColor(0.65, 0.65, 0.65)
        end
        f.label:SetFont(ns.Media.Font(), on and 22 or 18, "OUTLINE")
        f.label:SetText(Windows.Label(W.idx))
        f:Show()
    end)
end

function Windows.HideIdentify()
    Windows.ForEach(function(W)
        if W.identify then W.identify:Hide() end
    end)
end

------------------------------------------------------------
-- 選單
------------------------------------------------------------
local function TypeItems(W)
    local items = { { text = ns.L["Meter type"], isTitle = true } }
    for _, dmType in ipairs(D.TYPE_ORDER) do
        items[#items + 1] = {
            text = D.TYPE_NAMES[dmType] or "?",
            isActive = (dmType == W.curDMType),
            onClick = function() Win.SetDMType(W, dmType) end,
        }
    end
    return items
end

local function SegmentItems(W)
    local L = ns.L
    local items = { { text = L["Segments"], isTitle = true } }

    items[#items + 1] = {
        text = L["Current"],
        isActive = (not W.curSessionID and W.curSession == D.S.Current),
        onClick = function() Win.SetSegment(W, D.S.Current, nil) end,
    }
    items[#items + 1] = {
        text = L["Overall"],
        isActive = (not W.curSessionID and W.curSession == D.S.Overall),
        onClick = function() Win.SetSegment(W, D.S.Overall, nil) end,
    }

    local list = D.GetAvailableSessions()
    if list and #list > 0 then
        items[#items + 1] = { isSeparator = true }
        for i, sess in ipairs(list) do
            local id = sess.sessionID
            -- 分段名稱可能是秘密字串：不要串接，交給 format（C 端吃得下）
            local label = sess.name
            local dur = sess.durationSeconds
            local text
            if label and not D.IsSecret(label) then
                text = format("%s  (%s)", label, D.FormatTimer(dur))
            else
                text = format("%s %d  (%s)", L["Segment"], i, D.FormatTimer(dur))
            end
            items[#items + 1] = {
                text = text,
                isActive = (W.curSessionID == id),
                onClick = function() Win.SetSegment(W, nil, id) end,
            }
        end
    end

    return items
end

------------------------------------------------------------
-- 主選單右側的「目前值」讀數
--
-- 讓玩家不用展開子選單就知道現在是什麼狀態 —— 「要先點開才知道自己選了什麼」
-- 是階層式選單最常見的不直覺來源。
------------------------------------------------------------
local function CurrentTypeLabel(W)
    return D.TYPE_NAMES[W.curDMType] or "?"
end

local function CurrentSegmentLabel(W)
    local L = ns.L
    if not W.curSessionID then
        return (W.curSession == D.S.Overall) and L["Overall"] or L["Current"]
    end
    local list = D.GetAvailableSessions()
    if list then
        for i, sess in ipairs(list) do
            if sess.sessionID == W.curSessionID then
                -- 分段名稱可能是秘密字串：不能串接，只能整個拿去顯示或退回編號
                local label = sess.name
                if label and not D.IsSecret(label) then return label end
                return L["Segment"] .. " " .. i
            end
        end
    end
    return L["Segment"]
end

function Windows.ShowSegmentMenu(W, btn)
    ns.W.Menu.Show(SegmentItems(W), btn)
end

-- redraw = true：從選單裡的開關項目回頭重畫（原地更新勾選狀態，不要當成再按一次）
function Windows.ShowContextMenu(W, btn, redraw)
    local L = ns.L
    local wdb = W.wdb
    local s = ns.DB.Style()

    local items = {
        { text = L["MiliUI Damage Meters"] .. " " .. W.idx, isTitle = true },
        { text = L["Meter type"], value = CurrentTypeLabel(W),    submenu = TypeItems(W) },
        { text = L["Segments"],   value = CurrentSegmentLabel(W), submenu = SegmentItems(W) },
        { isSeparator = true },
        {
            text = L["Hide the timer"], isActive = wdb.hideTimer, keepOpen = true,
            onClick = function()
                wdb.hideTimer = not wdb.hideTimer
                W.timerText:SetShown(not wdb.hideTimer)
                W._timerSec = nil
                Win.UpdateTimerText(W)
                Windows.ShowContextMenu(W, btn, true)
            end,
        },
        {
            text = L["Sync segments with other windows"], isActive = wdb.syncSegments, keepOpen = true,
            onClick = function()
                wdb.syncSegments = not wdb.syncSegments
                Windows.ShowContextMenu(W, btn, true)
            end,
        },
        {
            text = L["Smart display"],
            isActive = wdb.smartDisplay, keepOpen = true,
            onClick = function()
                Windows.SetSmartDisplay(W, not wdb.smartDisplay)
                Windows.ShowContextMenu(W, btn, true)
            end,
        },
        {
            -- 全域磁吸關著的時候這一項沒有意義，標示出來
            text = s.snapEnabled and L["Don't snap this window"] or L["Snapping is off in the settings"],
            isActive = wdb.snapDisabled, keepOpen = true,
            onClick = function()
                if not s.snapEnabled then return end
                wdb.snapDisabled = not wdb.snapDisabled
                Windows.ShowContextMenu(W, btn, true)
            end,
        },
        { isSeparator = true },
        { text = L["Reset data"], onClick = function() ns.Combat.ResetData() end },
        -- 鎖定放在這裡而不是上面那組開關：標題列的鎖頭預設是藏起來的
        -- （style.hideLockButton），所以這裡是玩家實際會用的那個入口，
        -- 擺在動作區比夾在一排視窗行為開關裡好找。
        {
            text = L["Lock window"], isActive = wdb.locked, keepOpen = true,
            onClick = function()
                wdb.locked = not wdb.locked
                Win.UpdateLockIcon(W)
                ns.Move.ApplyLock(W)
                Windows.ShowContextMenu(W, btn, true)   -- 原地重畫勾選狀態
            end,
        },
        { text = L["Settings"],   onClick = function() ns.OpenOptions() end },
    }

    ns.W.Menu.Show(items, btn, redraw)
end

------------------------------------------------------------
-- 事件：顯示條件要跟著場景變
------------------------------------------------------------
local visFrame = CreateFrame("Frame")

ns.RegisterCallback("Init", "windows", function()
    Windows.Rebuild()

    -- 沒有任何視窗還在等著接手內建統計的位置，就不必等下面那 3 秒 —— 直接關。
    -- （autoPlaced 只有在「還沒接到位置」時才會是 true，見 Meter/Move.lua）
    local waiting = false
    Windows.ForEach(function(W) if W.wdb.autoPlaced then waiting = true end end)
    if not waiting then ns.Builtin.Enforce() end

    visFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    visFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    visFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    visFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    visFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    visFrame:SetScript("OnEvent", function()
        Windows.UpdateVisibility()
        -- ⚠ 再算一次。**離開探究的那一瞬間 IsPartyWalkIn() 還是 true**
        -- （見 Meter/Data.lua 的 D.IsInDelve），只在事件當下判斷會讓視窗
        -- 多藏一段時間。1 秒是抄 Plumber 那 0.5 秒再放寬一點。
        C_Timer.After(1, Windows.UpdateVisibility)
    end)

    ------------------------------------------------------------
    -- 分段資料變動
    --
    -- ⚠ 事件名稱一個字都不能猜。第一版寫成 "COMBAT_SESSION_UPDATED"（少了
    --   DAMAGE_METER_ 前綴）並且包在 pcall 裡 —— RegisterEvent 對不存在的事件會拋錯，
    --   被 pcall 吞掉之後就是**靜默失效**：閒置時視窗永遠不會更新，而且沒有任何徵兆。
    --   註冊失敗現在會記進 ns.errors（/mdm debug 看得到），不會再無聲無息。
    ------------------------------------------------------------
    local DM_EVENTS = {
        "DAMAGE_METER_RESET",
        "DAMAGE_METER_COMBAT_SESSION_UPDATED",
        "DAMAGE_METER_CURRENT_SESSION_UPDATED",
    }
    local SESSION_DEBOUNCE = 0.1

    local dmFrame = CreateFrame("Frame")
    local sessionPending = false

    for _, ev in ipairs(DM_EVENTS) do
        local ok, err = pcall(dmFrame.RegisterEvent, dmFrame, ev)
        if not ok then
            ns.ReportError("RegisterEvent failed: " .. ev .. " (" .. tostring(err) .. ")")
        end
    end

    dmFrame:SetScript("OnEvent", function(_, event)
        if event == "DAMAGE_METER_RESET" then
            Windows.InvalidateAll()
            Windows.ForEach(function(W) W.Refresh() end)
            return
        end
        -- 這兩個 SESSION_UPDATED 在戰鬥中是**連續**打的（每次有人死、每次伺服器
        -- 換 session），所以整批合併成一次。沒有去抖的話等於在 ticker 之外
        -- 又多開了一條不受刷新率控制的重畫路徑。
        if sessionPending then return end
        sessionPending = true
        C_Timer.After(SESSION_DEBOUNCE, function()
            sessionPending = false
            Windows.InvalidateData()
            if ns.Combat.IsInCombat() then
                -- 戰鬥中有 ticker 在跑，不必再重畫。但 ticker 有可能因為收尾的
                -- 競態而死掉（延後停止剛好在新一波開打前落地）—— 伺服器送來新分段
                -- 就是「還在打」的鐵證，趁機把它救回來。
                ns.Combat.ReviveTicker()
            else
                Windows.ForEach(function(W) W.Refresh() end)
            end
        end)
    end)

    -- 自訂職業色插件晚一點才改 CUSTOM_CLASS_COLORS
    C_Timer.After(2, function() ns.Media.RefreshAccent() end)

    -- 暴雪內建統計視窗（DamageMeterSessionWindow1..3）可能比我們晚建好。
    -- 第一次擺放沒接到它的位置的視窗，這裡再試一次。刻意不去猜
    -- Blizzard_DamageMeter 這個插件名（猜錯是靜默失效）—— 直接等一下再看 _G。
    --
    -- ⚠ 順序是硬的：**先接手位置、再關掉內建統計**。關掉之後那三個視窗就不存在了，
    -- 位置也就永遠讀不到（新角色第一次登入時最明顯）。
    C_Timer.After(3, function()
        ns.Move.RetryAdoptBlizzardPosition()
        ns.Builtin.Enforce()
    end)
end)

ns.RegisterCallback("ColorsChanged", "windows", function()
    Windows.ApplyStyle()
end)
