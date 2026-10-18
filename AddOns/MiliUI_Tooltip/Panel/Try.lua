------------------------------------------------------------
-- 重繪面板的流程：Try（post-call 進來）／Release（內容被清掉）／Restore（退回原生）
--
--   1. 該型別的開關關 → Restore 後 return（沒畫過就什麼都不碰 ⇒ 開關關掉時跟以前逐位元一樣）
--   2. reader(tip, data) → model；nil（秘密值、讀不到、沒名字）→ Restore
--   3. 指紋跟上次相同、panel 還顯示著 → 只重壓 alpha、Fit，不重畫（比價框每秒重建二十幾次）
--   4. view(model) → RenderView → Align → Native.Hide → Fit → Show；下一幀再 Fit 一次；登記輪詢
--   5. 輪詢（0.1 秒，只在有 tooltip 顯示時存在）：tooltip 沒了 → Restore；alpha 被改回來 → 重壓；
--      行數變了（別人後加行、修飾鍵補 ID 行）→ 重跑 Try；尺寸漂了 → Fit
--   6. OnTooltipCleared → Release：先不拆，等下一幀；同一幀裡新的 post-call 會把它認領回去
--      （比價重建＝清空再填同一件，拆了重畫就白費指紋）。skin OnHide → Restore 立刻拆。
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

------------------------------------------------------------
-- 退回
------------------------------------------------------------
function Panel.Restore(tip, state)
    if not state then return end
    state.releasePending = nil
    state.panelFingerprint = nil
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
-- 輪詢
------------------------------------------------------------
local function Tick(tip, state)
    if not state.native then
        state.panelPolling = nil
        Skin.Unpoll(state)
        return
    end
    local okS, shown = pcall(tip.IsShown, tip)
    if S.IsForbiddenObject(tip) or not okS or S.IsSecret(shown) or not shown then
        Panel.Restore(tip, state)
        return
    end
    Native.Repress(tip, state)
    if state.panel then Panel.SyncLevel(state.panel, tip) end
    local okN, n = pcall(tip.NumLines, tip)
    n = okN and S.PlainNumber(n)
    if n and n ~= state.panelLines and state.panelData then
        Panel.Try(tip, state, state.panelKind, state.panelData)
        return
    end
    if Native.Fit(tip, state) == false then Panel.Restore(tip, state) end
end

local function StartPoll(tip, state)
    if state.panelPolling then return end
    state.panelPolling = true
    Skin.Poll(state, POLL_INTERVAL, function() Tick(tip, state) end)
end

------------------------------------------------------------
-- 主流程
------------------------------------------------------------
-- dataType 是 Enum.TooltipDataType 的值，或直接給 "item"／"spell"（輪詢重跑時）
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

    -- 先讀行、比指紋，相同就不解析不重畫（比價框每秒重建二十幾次，pattern 比對只在內容變了才跑）
    local rows, n = Panel.CollectLines(tip, data)
    if not rows then
        Panel.Restore(tip, state)
        return
    end
    local fingerprint = Panel.Fingerprint({ rows = rows, numLines = n }, kind)
    local panel = state.panel
    if fingerprint == state.panelFingerprint and panel and panel:IsShown() and state.native then
        state.releasePending = nil         -- 認領：上一份被清掉時排定的拆除取消
        state.panelData, state.panelKind, state.panelLines = data, kind, n
        Panel.PaintEdges(panel, state)     -- 邊框色在 ClearTransient 時被重設過，補回來
        if not Native.Hide(tip, state) or Native.Fit(tip, state) == false then
            Panel.Restore(tip, state)
        end
        return
    end

    local reader = Panel.readers[kind] or Panel.ReadFallback
    local model = reader(tip, data, kind, rows, n)
    if not model then
        Panel.Restore(tip, state)
        return
    end
    state.releasePending = nil
    state.panelData, state.panelKind, state.panelLines = data, kind, n
    panel = Panel.Get(tip, state)

    local view = (Panel.views[kind] or Panel.ViewFallback)(model, state)
    if not view or not Panel.RenderView(panel, tip, view, state) then
        Panel.Restore(tip, state)
        return
    end
    if not Panel.Align(panel, tip) or not Native.Hide(tip, state) then
        Panel.Restore(tip, state)
        return
    end
    if Native.Fit(tip, state) == false then
        Panel.Restore(tip, state)
        return
    end
    panel:Show()
    state.panelFingerprint = fingerprint

    -- post-call 在暴雪 Show 之前：第一次顯示時 OnShow 會清掉 padding，下一幀補；
    -- 那時 tooltip 若根本沒顯示出來（被別的流程藏掉）就退回，panel 不能孤零零留著
    C_Timer.After(0, function()
        if state.panelFingerprint ~= fingerprint or not state.native then return end
        local okS, shown = pcall(tip.IsShown, tip)
        if not okS or S.IsSecret(shown) or not shown then
            Panel.Restore(tip, state)
            return
        end
        Native.Repress(tip, state)
        if Native.Fit(tip, state) == false then Panel.Restore(tip, state) end
    end)
    StartPoll(tip, state)
end

-- Hooks 的 xpcall 失敗時叫：畫到一半出錯也不能留著 alpha 0 的原生
function Panel.Fail(tip, state)
    pcall(Panel.Restore, tip, state)
end
