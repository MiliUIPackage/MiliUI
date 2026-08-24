------------------------------------------------------------
-- 視窗管理：建立、數量調整、統一套用、選單
--
-- ⚠ 跟 EUI 的一個實質差異：**視窗建了就不銷毀，只是藏起來。**
--   WoW 的 frame 刪不掉（見 wow-frame-lifecycle-costs），EUI 的 Destroy 是
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
    ns.Move.UpdateEditState()
end

------------------------------------------------------------
-- 統一套用
------------------------------------------------------------
function Windows.ApplyStyle()
    D.RebuildNumberFormat()
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
-- 而分段更新事件在戰鬥中是連續打的。EUI 實測那是它最大的一筆成本
-- （原話：the dominant profiled cost）。
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
function Windows.AutoCurrentOnCombat()
    Windows.ForEach(function(W)
        if not W.wdb.autoCurrentOnCombat then return end
        if not W.curSessionID then return end
        Win.SetSegment(W, D.S.Current, nil)
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
    ns.Menu.Show(SegmentItems(W), btn)
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
            text = L["Lock window"], isActive = wdb.locked, keepOpen = true,
            onClick = function()
                wdb.locked = not wdb.locked
                Win.UpdateLockIcon(W)
                ns.Move.ApplyLock(W)
                Windows.ShowContextMenu(W, btn, true)   -- 原地重畫勾選狀態
            end,
        },
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
        { text = L["Settings"],   onClick = function() ns.OpenOptions() end },
    }

    ns.Menu.Show(items, btn, redraw)
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
    end)

    ------------------------------------------------------------
    -- 分段資料變動
    --
    -- ⚠ 事件名稱一個字都不能猜。第一版寫成 "COMBAT_SESSION_UPDATED"（少了
    --   DAMAGE_METER_ 前綴）並且包在 pcall 裡 —— RegisterEvent 對不存在的事件會拋錯，
    --   被 pcall 吞掉之後就是**靜默失效**：閒置時視窗永遠不會更新，而且沒有任何徵兆。
    --   現在名稱照 EUI 的原始碼抄（它是對著實機寫的），註冊失敗會記進 ns.errors，
    --   /mdm debug 看得到。
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
