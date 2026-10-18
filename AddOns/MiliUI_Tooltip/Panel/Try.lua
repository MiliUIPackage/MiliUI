------------------------------------------------------------
-- 重繪面板的流程：Try（post-call 進來）／Reconcile（下一幀對帳）／Release（內容被清掉）／Restore（退回原生）
--
--   1. 該型別的開關關 → Restore 後 return（沒畫過就什麼都不碰 ⇒ 開關關掉時跟以前逐位元一樣）
--   2. **同一件的重建**（state.panelKey 相同、panel 顯示中）→ 當幀不解析、不重畫，只重壓 alpha、Fit，
--      排一次 Reconcile。原因：post-call 在暴雪 ProcessInfo 的中間——比價框的「若你更換此裝備…」、
--      別家插件 post-call 加的行，都是**同一幀、我們之後**才補上的。當幀就畫會畫出「少那幾行」的版本，
--      輪詢再畫回完整版；比價重建每秒二十幾次 ⇒ 兩版交替＝閃爍（2026-10-18 實機回報）。
--   3. **新物件**（key 不同、panel 沒顯示）→ 立刻畫（第一次顯示要快），再排一次 Reconcile 補齊同一幀後加的行
--   4. Reconcile（C_Timer.After(0)，每個 state 同時只排一個）：CollectLines 重讀 → 指紋相同就不動；
--      不同才 reader → view → RenderView。**行數比這件看過的最多還少 ⇒ 當成部分版不重畫**，下一幀再對；
--      連續 PARTIAL_GRACE 秒都比較少才接受（修飾鍵放開、冷卻行消失這種「真的變少」不能卡死）
--   5. 輪詢（0.1 秒，只在有 tooltip 顯示時存在）：tooltip 沒了 → Restore；alpha 被改回來 → 重壓；
--      行數變了 → 排 Reconcile；尺寸漂了 → Fit；層級被抬 → 跟上
--   6. OnTooltipCleared → Release：先不拆，等下一幀；同一幀裡新的 post-call 會把它認領回去。
--      skin OnHide → Restore 立刻拆。
--
-- 任何一步出錯都由 Core/Hooks.lua 的 xpcall 接住；錯誤之後 Restore 也會被叫到（見 Hooks）。
------------------------------------------------------------
local _, ns = ...

local S = ns.Secret
local Skin = ns.Skin
local Panel = ns.Panel
local Native = Panel.Native

local T = Enum and Enum.TooltipDataType or {}
local KIND = {}
if T.Item then KIND[T.Item] = "item" end
if T.Spell then KIND[T.Spell] = "spell" end
Panel.KIND = KIND

-- P2／P3 在這裡登記各型別的 reader／view；沒登記的走最簡版
Panel.readers = Panel.readers or {}
Panel.views = Panel.views or {}

local POLL_INTERVAL = 0.1
local PARTIAL_GRACE = 0.3      -- 行數比完整版少，連續這麼久才接受為新的完整版
Panel.PARTIAL_GRACE = PARTIAL_GRACE

-- 設定一改就 +1（進指紋：改了外觀要重畫）
Panel.settingsVersion = 0

local function Enabled(kind)
    local db = ns.db
    return db and db[kind] and db[kind].panel == true
end

-- 內嵌物品框（世界任務獎勵）或底部說明字顯示時，暴雪自己在用 padding ⇒ 不接
local function Eligible(tip)
    for _, key in ipairs({ "ItemTooltip", "BottomFontString" }) do
        local region = tip[key]
        if region and region.IsShown then
            local ok, shown = pcall(region.IsShown, region)
            if not ok or S.IsSecret(shown) or shown then return false end
        end
    end
    return true
end

-- 指紋：所有行（文字＋顏色）＋設定版本＋行數。reader 只收明文，這裡串接是安全的
local function ColorKey(c)
    if not c then return "-" end
    return ("%.3f,%.3f,%.3f"):format(c[1], c[2], c[3])
end

function Panel.Fingerprint(model, extra)
    local parts = { tostring(Panel.settingsVersion), tostring(model.numLines or 0), extra or "" }
    for _, row in ipairs(model.rows or {}) do
        parts[#parts + 1] = row.left or ""
        parts[#parts + 1] = row.right or ""
        parts[#parts + 1] = ColorKey(row.color)
        parts[#parts + 1] = ColorKey(row.rightColor)
        parts[#parts + 1] = row.price and tostring(row.price) or ""
    end
    return table.concat(parts, "\031")
end

-- 「同一件」：型別＋明文 id；沒有 id 就用 hyperlink；兩個都拿不到（秘密）⇒ nil＝每次都當不同件
function Panel.Key(kind, data)
    if type(data) ~= "table" then return nil end
    local id = S.PlainNumber(data.id)
    if id then return kind .. ":" .. id end
    local link = S.PlainText(data.hyperlink)
    if link and link ~= "" then return kind .. ":" .. link end
    return nil
end

local function Shown(tip)
    local ok, shown = pcall(tip.IsShown, tip)
    return ok and not S.IsSecret(shown) and shown and true or false
end

local function Now()
    return GetTime and GetTime() or 0
end

------------------------------------------------------------
-- 退回
------------------------------------------------------------
function Panel.Restore(tip, state)
    if not state then return end
    state.releasePending = nil
    state.reconcileToken = (state.reconcileToken or 0) + 1    -- 排著的 Reconcile 作廢
    state.reconcilePending = nil
    state.panelFingerprint, state.panelKey, state.panelFullLines, state.partialSince = nil, nil, nil, nil
    state.panelData, state.panelKind, state.panelLines = nil, nil, nil
    if state.panelPolling then
        state.panelPolling = nil
        Skin.Unpoll(state)
    end
    if state.native or (state.panel and state.panel:IsShown()) then
        Native.Restore(tip, state)
    end
end

-- 內容被清掉（OnTooltipCleared）：先不拆，下一幀還沒被認領才拆
function Panel.Release(tip, state)
    if not state or not (state.native or (state.panel and state.panel:IsShown())) then return end
    state.releaseToken = (state.releaseToken or 0) + 1
    state.releasePending = true
    local token = state.releaseToken
    C_Timer.After(0, function()
        if state.releasePending and state.releaseToken == token then
            Panel.Restore(tip, state)
        end
    end)
end

function Panel.RestoreAll()
    Skin.Each(function(tip, state) Panel.Restore(tip, state) end)
end

-- skin 的 OnShow（tooltip 從隱藏變顯示）：重申 alpha 0
function Panel.OnSkinShow(tip, state)
    if state and state.native then Native.Repress(tip, state) end
end

------------------------------------------------------------
-- 畫：rows 已經讀好（指紋用的那份）；失敗回 false（呼叫端 Restore）
------------------------------------------------------------
local function Render(tip, state, kind, data, rows, n, fingerprint)
    local reader = Panel.readers[kind] or Panel.ReadFallback
    local model = reader(tip, data, kind, rows, n)
    if not model then return false end
    local panel = Panel.Get(tip, state)
    local view = (Panel.views[kind] or Panel.ViewFallback)(model, state)
    if not view or not Panel.RenderView(panel, tip, view, state) then return false end
    if not Panel.Align(panel, tip) or not Native.Hide(tip, state) then return false end
    if Native.Fit(tip, state) == false then return false end
    panel:Show()
    state.panelFingerprint = fingerprint
    state.panelLines = n
    return true
end

------------------------------------------------------------
-- 下一幀對帳
------------------------------------------------------------
local Reconcile

local function ScheduleReconcile(tip, state)
    if state.reconcilePending then return end      -- 每個 state 同時只排一個
    state.reconcilePending = true
    state.reconcileToken = state.reconcileToken or 0
    local token = state.reconcileToken
    C_Timer.After(0, function()
        if state.reconcileToken ~= token then return end    -- 中間 Restore 過
        state.reconcilePending = nil
        Reconcile(tip, state)
    end)
end

function Reconcile(tip, state)
    if not state.native or not state.panelData then return end
    -- post-call 在暴雪 Show 之前：tooltip 若根本沒顯示出來（被別的流程藏掉）就退回，panel 不能孤零零留著
    if S.IsForbiddenObject(tip) or not Shown(tip) then
        Panel.Restore(tip, state)
        return
    end
    Native.Repress(tip, state)
    if state.panel then Panel.SyncLevel(state.panel, tip) end

    local rows, n = Panel.CollectLines(tip, state.panelData)
    if not rows then
        Panel.Restore(tip, state)
        return
    end
    -- 部分版不准蓋掉完整版：比這件看過的最多還少 ⇒ 先等；連續 PARTIAL_GRACE 秒才接受
    local full = state.panelFullLines or 0
    if n < full then
        state.partialSince = state.partialSince or Now()
        if Now() - state.partialSince < PARTIAL_GRACE then
            if Native.Fit(tip, state) == false then Panel.Restore(tip, state) return end
            ScheduleReconcile(tip, state)
            return
        end
    end
    -- 到這裡 n 不是更多、就是「少了夠久、接受了」：都成為這件的新完整行數
    state.partialSince = nil
    state.panelFullLines = n

    local fingerprint = Panel.Fingerprint({ rows = rows, numLines = n }, state.panelKind)
    if fingerprint == state.panelFingerprint then
        state.panelLines = n
        if Native.Fit(tip, state) == false then Panel.Restore(tip, state) end
        return
    end
    if not Render(tip, state, state.panelKind, state.panelData, rows, n, fingerprint) then
        Panel.Restore(tip, state)
    end
end
Panel.Reconcile = Reconcile

------------------------------------------------------------
-- 輪詢
------------------------------------------------------------
local function Tick(tip, state)
    if not state.native then
        state.panelPolling = nil
        Skin.Unpoll(state)
        return
    end
    if S.IsForbiddenObject(tip) or not Shown(tip) then
        Panel.Restore(tip, state)
        return
    end
    Native.Repress(tip, state)
    if state.panel then Panel.SyncLevel(state.panel, tip) end
    local okN, n = pcall(tip.NumLines, tip)
    n = okN and S.PlainNumber(n)
    if n and n ~= state.panelLines and state.panelData then
        ScheduleReconcile(tip, state)
    end
    if Native.Fit(tip, state) == false then Panel.Restore(tip, state) end
end

local function StartPoll(tip, state)
    if state.panelPolling then return end
    state.panelPolling = true
    Skin.Poll(state, POLL_INTERVAL, function() Tick(tip, state) end)
end

------------------------------------------------------------
-- 主流程（post-call 進來）
------------------------------------------------------------
-- dataType 是 Enum.TooltipDataType 的值，或直接給 "item"／"spell"
function Panel.Try(tip, state, dataType, data)
    if not state or not ns.db then return end
    local kind = KIND[dataType] or dataType
    if (kind ~= "item" and kind ~= "spell") or not Enabled(kind) then
        Panel.Restore(tip, state)
        return
    end
    if S.IsForbiddenObject(tip) or not Eligible(tip) then
        Panel.Restore(tip, state)
        return
    end

    local key = Panel.Key(kind, data)
    local panel = state.panel

    -- 同一件的重建：當幀不畫，下一幀 Reconcile 拿完整版
    if key and key == state.panelKey and panel and panel:IsShown() and state.native then
        state.releasePending = nil          -- 認領：上一份被清掉時排定的拆除取消
        state.panelData, state.panelKind = data, kind
        Panel.PaintEdges(panel, state)      -- 邊框色在 ClearTransient 時被重設過，補回來
        if not Native.Hide(tip, state) or Native.Fit(tip, state) == false then
            Panel.Restore(tip, state)
            return
        end
        ScheduleReconcile(tip, state)
        return
    end

    -- 新物件：立刻畫
    local rows, n = Panel.CollectLines(tip, data)
    if not rows then
        Panel.Restore(tip, state)
        return
    end
    state.releasePending = nil
    state.panelData, state.panelKind = data, kind
    local fingerprint = Panel.Fingerprint({ rows = rows, numLines = n }, kind)
    if not Render(tip, state, kind, data, rows, n, fingerprint) then
        Panel.Restore(tip, state)
        return
    end
    state.panelKey = key
    state.panelFullLines = n
    state.partialSince = nil
    ScheduleReconcile(tip, state)
    StartPoll(tip, state)
end

-- Hooks 的 xpcall 失敗時叫：畫到一半出錯也不能留著 alpha 0 的原生
function Panel.Fail(tip, state)
    pcall(Panel.Restore, tip, state)
end
