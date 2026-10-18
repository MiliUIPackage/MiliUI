------------------------------------------------------------
-- 重繪面板的流程：Try（post-call 進來）／Reconcile（下一幀對帳）／Release（內容被清掉）／Restore（退回原生）
--
--   1. 該型別的開關關 → Restore 後 return（沒畫過就什麼都不碰 ⇒ 開關關掉時跟以前逐位元一樣）
--   2. **同一件的重建**（state.panelKey 相同、panel 顯示中）→ 當幀不解析、不重畫，只重壓 alpha、Fit，
--      排一次 Reconcile。原因：post-call 在暴雪 ProcessInfo 的中間——比價框的「若你更換此裝備…」、
--      別家插件 post-call 加的行，都是**同一幀、我們之後**才補上的。當幀就畫會畫出「少那幾行」的版本，
--      輪詢再畫回完整版；比價重建每秒二十幾次 ⇒ 兩版交替＝閃爍（2026-10-18 實機回報）。
--   3. **新物件**（key 不同、panel 沒顯示）→ 立刻畫（第一次顯示要快），再排一次 Reconcile 補齊同一幀後加的行
--   4. Reconcile（C_Timer.After(0)，每個 state 同時只排一個）：CollectLines 重讀、比指紋，三種情況：
--      * 行數**多於**這件看過的最多 ⇒ 立刻重畫（補齊＝長大；第一次顯示少了法術說明行之類，這是唯一允許的可見變化）
--      * 行數**少於** ⇒ 當成部分版不重畫，連續 SETTLE 秒都比較少才接受（修飾鍵放開、冷卻行消失）
--      * 行數**相同、指紋不同** ⇒ 這個新指紋要連續看到 SETTLE 秒才重畫。背包每 0.2 秒重設一次提示、不同來源的行
--        輪流出現（實機記錄：同一件三種行集合），A／B 交替永遠到不了 SETTLE ⇒ 面板停在第一個完整版不動
--      （設定改了例外：指紋差在設定版本就直接重畫）
--   4b. 幾何只長不縮（同一件）：panel 寬取這件看過的最大寬；原生替身的高取這件看過的最大總高。
--       內容少的版本畫在寬面板裡沒關係；原生看不見，多撐一截沒有視覺代價，錨點就不會動。換一件歸零
--   5. 輪詢（0.1 秒，只在有 tooltip 顯示時存在）：tooltip 沒了 → Restore；alpha 被改回來 → 重壓；
--      行數變了 → 排 Reconcile；尺寸漂了 → Fit；層級被抬 → 跟上
--   6. OnTooltipCleared → Release：先不拆，等下一幀；同一幀裡新的 post-call 會把它認領回去。
--      skin OnHide → OnSkinHide：也延一幀（清單刷新時游標那一列先藏、下一幀才 OnEnter 重設同一件；當場拆會閃）。
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
local SETTLE = 0.3             -- 行數變少／同行數內容變了：連續這麼久才採用
Panel.SETTLE = SETTLE

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
    state.hidePending = nil
    state.reconcileToken = (state.reconcileToken or 0) + 1    -- 排著的 Reconcile 作廢
    state.reconcilePending = nil
    state.panelFingerprint, state.panelKey, state.panelFullLines, state.partialSince = nil, nil, nil, nil
    state.pendingFingerprint, state.pendingSince = nil, nil
    state.panelMaxWidth, state.panelMaxTotalHeight = nil, nil
    state.nativeMaxW, state.nativeMaxH = nil, nil          -- 原生的自然尺寸也只長不縮（Native.Fit）
    state.panelData, state.panelKind, state.panelLines = nil, nil, nil
    if state.panelPolling then
        state.panelPolling = nil
        Skin.Unpoll(state)
    end
    if state.native or (state.panel and state.panel:IsShown()) then
        local gone = state.panel
        -- 跟著這個面板的別家框（外觀預覽）先處理：要在面板還有點的時候讀它的位置才停得住（Panel.ReturnFollowers 的 Park）
        if gone then Panel.ReturnFollowers(gone) end
        Native.Restore(tip, state)
        -- 鏡射在這個面板上的（比價面板）當場改回貼自己的原生，不能錨在一個清掉錨點的框上
        if gone then
            Skin.Each(function(t2, s2)
                local p2 = s2.panel
                if p2 and p2.mirrorOf == gone and s2.native and p2:IsShown() then
                    if not Panel.Align(p2, t2) then Panel.Restore(t2, s2) end
                end
            end)
        end
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

-- tooltip 藏起來（skin OnHide）：**也先不拆**，走跟 Release 同一條路。
-- 清單類介面（ScrollBox：拍賣場結果、背包、任務）每次刷新資料都會把列重新配置，游標下那一列先藏（OnLeave →
-- GameTooltip:Hide）、下一幀引擎重新判定滑鼠焦點才 OnEnter 重設同一件 ⇒ 原生提示本來就會閃一幀。以前 OnHide 當場拆面板
-- 再下一幀整個重畫，面板跟著閃（2026-10-19 實機：Auctionator 的購物結果每次更新 `ScrollBox:SetDataProvider`）。
-- 現在延一幀：同一件在下一幀的 post-call 進來就認領（Try 的「同一件的重建」路徑），一個像素都不動；
-- 沒人認領才 Restore。多留一幀的代價：真的收掉提示時面板晚 1 幀消失，看不出來。
-- 開著 /mtip log 時記下是誰藏的（debugstack）——「是不是拍賣場在藏」靠這個看
function Panel.OnSkinHide(tip, state)
    if not state or not (state.native or (state.panel and state.panel:IsShown())) then return end
    if ns.logEnabled then
        ns.Log("面板 OnHide tip=%s key=%s 來源：%s", tostring(S.PlainText((S.SafeCall(tip.GetName, tip))) or "?"),
            tostring(state.panelKey), debugstack and debugstack(3, 5, 0) or "?")
    end
    state.hideToken = (state.hideToken or 0) + 1
    state.hidePending = true
    local token = state.hideToken
    C_Timer.After(0, function()
        if state.hidePending and state.hideToken == token then
            if ns.logEnabled then ns.Log("面板 OnHide 下一幀沒人認領 ⇒ Restore key=%s", tostring(state.panelKey)) end
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
    -- 只長不縮：記下這件看過的最大寬（RenderView 下次取 max）與最大總高（Native.Fit 撐原生用）
    state.panelMaxWidth = math.max(state.panelMaxWidth or 0, panel.width or 0)
    state.panelMaxTotalHeight = math.max(state.panelMaxTotalHeight or 0, panel.totalHeight or panel.height or 0)
    if not Panel.Align(panel, tip) or not Native.Hide(tip, state) then return false end
    if Native.Fit(tip, state) == false then return false end
    panel:Show()
    state.panelFingerprint = fingerprint
    state.panelSettings = Panel.settingsVersion
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
    local function wait()
        if Native.Fit(tip, state) == false then Panel.Restore(tip, state) return end
        ScheduleReconcile(tip, state)        -- 每幀重讀，直到穩定或回到現在畫的版本
    end
    local fingerprint = Panel.Fingerprint({ rows = rows, numLines = n }, state.panelKind .. "|" .. (Panel.CompareHeaderText(tip) or ""))
    local full = state.panelFullLines or 0

    if fingerprint == state.panelFingerprint then
        -- 回到現在畫的版本：任何等待中的變化作廢
        state.partialSince, state.pendingFingerprint, state.pendingSince = nil, nil, nil
        state.panelFullLines, state.panelLines = math.max(full, n), n
        if Native.Fit(tip, state) == false then Panel.Restore(tip, state) end
        return
    end

    if state.panelSettings ~= Panel.settingsVersion then
        -- 設定改了：不是內容在抖，直接照新設定重畫
    elseif n < full then
        -- 部分版不准蓋掉完整版：連續 SETTLE 秒都比較少才接受
        state.partialSince = state.partialSince or Now()
        state.pendingFingerprint, state.pendingSince = nil, nil
        if Now() - state.partialSince < SETTLE then return wait() end
    elseif n == full then
        -- 同行數、內容不同：這個新版本要連續 SETTLE 秒都沒變回去才採用（A／B 輪流的永遠採用不到）
        state.partialSince = nil
        if state.pendingFingerprint ~= fingerprint then
            state.pendingFingerprint, state.pendingSince = fingerprint, Now()
            return wait()
        end
        if Now() - (state.pendingSince or Now()) < SETTLE then return wait() end
    end
    -- 長大（立刻）、或變少／變內容已經穩定夠久：採用
    state.partialSince, state.pendingFingerprint, state.pendingSince = nil, nil, nil
    state.panelFullLines = n
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
        if ns.logEnabled and state.hidePending then ns.Log("面板 認領 key=%s（藏了又回來）", tostring(key)) end
        state.releasePending = nil          -- 認領：上一份被清掉／藏起來時排定的拆除取消
        state.hidePending = nil
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
    state.hidePending = nil
    state.panelData, state.panelKind = data, kind
    -- 換一件：只長不縮的幾何與等待中的變化全部歸零
    state.panelMaxWidth, state.panelMaxTotalHeight = nil, nil
    state.nativeMaxW, state.nativeMaxH = nil, nil          -- 原生的自然尺寸也只長不縮（Native.Fit）
    state.pendingFingerprint, state.pendingSince, state.partialSince = nil, nil, nil
    local fingerprint = Panel.Fingerprint({ rows = rows, numLines = n }, kind .. "|" .. (Panel.CompareHeaderText(tip) or ""))
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

------------------------------------------------------------
-- /mtip panel：面板顯示中的每顆 tooltip 印一段「原生怎麼錨、多高、padding、panel 貼在哪」
-- 位置跳的回報先要這份：看得出是原生哪一邊在動、padding 有沒有被清掉。全部 pcall、秘密值標 <secret>
------------------------------------------------------------
local function D(v)
    if v == nil then return "nil" end
    if S.IsSecret(v) then return "<secret>" end
    local t = type(v)
    if t == "number" then return ("%.1f"):format(v) end
    if t == "string" then return v end
    if t == "table" and v.GetName then
        local ok, name = pcall(v.GetName, v)
        if ok and S.PlainText(name) then return name end
        return "(匿名框)"
    end
    return tostring(v)
end

local function Call(obj, method, ...)
    if not obj or not obj[method] then return end
    return S.SafeCall(obj[method], obj, ...)
end

local function Points(region)
    local out = {}
    local n = S.PlainNumber((Call(region, "GetNumPoints"))) or 0
    for i = 1, n do
        local p, rel, rp, x, y = Call(region, "GetPoint", i)
        out[#out + 1] = ("%s→%s:%s(%s,%s)"):format(D(p), D(rel), D(rp), D(x), D(y))
    end
    return #out > 0 and table.concat(out, " ") or "（沒有點）"
end

function Panel.DebugDump(out)
    out = out or print
    local count = 0
    Skin.Each(function(tip, state)
        local panel = state.panel
        if not panel or not panel:IsShown() then return end
        count = count + 1
        out(("|cff4DD2FF%s|r 原生：%s"):format(D(tip), Points(tip)))
        local r, b, l, t = Call(tip, "GetPadding")
        out(("  top=%s bottom=%s h=%s  padding=%s,%s,%s,%s  我們設的=%s,%s"):format(
            D((Call(tip, "GetTop"))), D((Call(tip, "GetBottom"))), D((Call(tip, "GetHeight"))),
            D(r), D(b), D(l), D(t),
            D(state.paddingSet and state.paddingSet[1]), D(state.paddingSet and state.paddingSet[2])))
        out(("  panel：height=%s total=%s  貼在 %s"):format(D(panel.height), D(panel.totalHeight), Points(panel)))
    end)
    if count == 0 then out("目前沒有顯示中的面板（滑過物品或法術時再下一次指令）") end
    -- 跟著面板鏈的別家框（外觀預覽，Panel.Follow）：我們選的邊、實際貼在哪、它原本要貼哪。
    -- 沒在跟的也印：最近一次掛勾多久前、它當時要貼哪、為什麼放手——「預覽在抖但沒有這一行」就是這裡要看的
    local any = false
    local now = Now()
    for frame, rec in pairs(Panel.followers or {}) do
        any = true
        local okS, shown = pcall(frame.IsShown, frame)
        local ago = rec.hookAt and ("%.1f 秒前"):format(now - rec.hookAt) or "從未"
        if rec.root then
            out(("|cff4DD2FF跟隨框 %s|r：%s側 貼在 %s  （它要的是 %s→%s:%s）  幾何讀不到 %d 次%s，交棒 %d 次，最近掛勾 %s"):format(
                D(frame), rec.side or "?", Points(frame), D(rec[1]), D(rec[2]), D(rec[3]),
                rec.fails or 0, rec.failWhy and ("，最近：" .. rec.failWhy) or "", rec.handoffs or 0, ago))
        elseif rec.parkArgs then
            out(("|cff4DD2FF跟隨框 %s|r：停在原地等根回來（%.1f 秒前停的，停過 %d 次）  貼在 %s  最近掛勾 %s"):format(
                D(frame), now - (rec.parkedAt or now), rec.parks or 0, Points(frame), ago))
        else
            out(("|cff4DD2FF跟隨框 %s|r：|cffff6060目前沒跟|r（%s%s）  顯示中=%s  它貼在 %s  最近掛勾 %s：%s 貼 %s  停過 %d 次"):format(
                D(frame), rec.dropWhy or "還沒掛勾過",
                rec.dropAt and ("，%.1f 秒前放手"):format(now - rec.dropAt) or "",
                tostring(okS and shown), Points(frame), ago, rec.hookPoint or "?", D(rec.hookRel), rec.parks or 0))
        end
    end
    if not any then
        out(_G.AppearanceTooltipTooltip and "外觀預覽框存在，但沒有登記跟隨（Adopt 沒帶 followPanel，或 MiliUI_Skin 沒委派成功）"
            or "沒有登記的跟隨框")
    end
    return count
end

------------------------------------------------------------
-- /mtip panel watch [秒數]：逐幀取樣，結束時只印「有變動的欄位」——哪一個數字在兩個值之間跳，一次就看得出來。
-- 取樣器是自己的框、只在 watch 期間掛 OnUpdate，結束就拆（frame 刪不掉，只能 SetScript(nil)）。
-- 全部 pcall；秘密值標 <secret>、不比大小（比的是格式化之後的字串）
------------------------------------------------------------
local watcher

local function F2(v)
    if v == nil then return "nil" end
    if S.IsSecret(v) then return "<secret>" end
    if type(v) == "number" then return ("%.2f"):format(v) end
    return D(v)
end

function Panel.Watch(seconds, out)
    out = out or print
    seconds = tonumber(seconds) or 1
    if seconds <= 0 then seconds = 1 end
    if seconds > 10 then seconds = 10 end
    watcher = watcher or CreateFrame("Frame")
    Panel.watcher = watcher
    local rec, order, frames, elapsed, sawPanel = {}, {}, 0, 0, false

    local function note(field, value)
        local s = F2(value)
        local r = rec[field]
        if not r then
            rec[field] = { last = s, changes = 0, values = { s }, seen = { [s] = true } }
            order[#order + 1] = field
        elseif r.last ~= s then
            r.changes, r.last = r.changes + 1, s
            if not r.seen[s] then
                r.seen[s] = true
                if #r.values < 6 then r.values[#r.values + 1] = s end
            end
        end
    end

    local function region(prefix, obj)
        for _, m in ipairs({ "GetLeft", "GetRight", "GetTop", "GetBottom", "GetWidth", "GetHeight" }) do
            note(prefix .. "." .. m:sub(4), (Call(obj, m)))
        end
        note(prefix .. ".scale", (Call(obj, "GetEffectiveScale")))
        local n = S.PlainNumber((Call(obj, "GetNumPoints"))) or 0
        note(prefix .. ".點數", n)
        for i = 1, n do
            local p, rel, rp, x, y = Call(obj, "GetPoint", i)
            local tag = ("%s.點%d"):format(prefix, i)
            note(tag, ("%s→%s:%s"):format(D(p), D(rel), D(rp)))
            note(tag .. ".x", x)
            note(tag .. ".y", y)
            if type(rel) == "table" and not S.IsSecret(rel) then
                note(tag .. ".對象.Left", (Call(rel, "GetLeft")))
                note(tag .. ".對象.Top", (Call(rel, "GetTop")))
            end
        end
    end

    local function sample()
        Skin.Each(function(tip, state)
            local panel = state.panel
            if not panel or not panel:IsShown() then return end
            sawPanel = true
            local name = D(tip)
            region(name .. ".原生", tip)
            local r, b, l, t = Call(tip, "GetPadding")
            note(name .. ".原生.padding", ("%s,%s,%s,%s"):format(F2(r), F2(b), F2(l), F2(t)))
            region(name .. ".面板", panel)
            note(name .. ".面板.width(記)", panel.width)
            note(name .. ".面板.height(記)", panel.height)
            note(name .. ".面板.totalHeight", panel.totalHeight)
            local box = panel.extrasBox
            if box and box:IsShown() then
                note(name .. ".附屬框.Left", (Call(box, "GetLeft")))
                note(name .. ".附屬框.Bottom", (Call(box, "GetBottom")))
            end
        end)
        -- 跟著面板鏈的別家框（外觀預覽）：位置、貼在哪一顆、哪一側
        for frame, rec in pairs(Panel.followers or {}) do
            local name = "跟隨框." .. D(frame)
            region(name, frame)
            note(name .. ".顯示中", (Call(frame, "IsShown")))
            note(name .. ".在跟", rec.root ~= nil)
            note(name .. ".側", rec.side)
            note(name .. ".貼在", rec.root and (rec.panel == rec.root and "根" or D(rec.panel)) or "沒跟")
            note(name .. ".交棒", rec.handoffs or 0)
            note(name .. ".停過", rec.parks or 0)
            note(name .. ".讀不到", rec.fails or 0)
            note(name .. ".放手原因", rec.dropWhy)
        end
        frames = frames + 1
    end

    local function report()
        if not sawPanel then
            out(("取樣 %d 幀，期間沒有顯示中的面板（滑過物品或法術時再下一次指令）"):format(frames))
            return
        end
        local changed = 0
        for _, field in ipairs(order) do
            local r = rec[field]
            if r.changes > 0 then
                changed = changed + 1
                out(("%s：%s（變 %d 次）"):format(field, table.concat(r.values, " / "), r.changes))
            end
        end
        if changed == 0 then out(("%d 幀全部穩定"):format(frames)) end
    end

    out(("開始取樣 %.1f 秒"):format(seconds))
    watcher:SetScript("OnUpdate", function(self, dt)
        sample()
        elapsed = elapsed + (dt or 0)
        if elapsed >= seconds then
            self:SetScript("OnUpdate", nil)
            self:Hide()
            report()
        end
    end)
    watcher:Show()
end
