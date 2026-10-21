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
--   4c. 同一件重設的 post-call 當下算 padding 時，自然尺寸用上次對帳量到的（Native.Fit 的 partial）：那一刻內容不完整，
--       照它算會先撐大、行進來後原生總高超標一幀；原生被夾在螢幕上緣時這一幀變成面板往下掉（2026-10-19 實機 log）
--   5. 輪詢（0.1 秒，只在有 tooltip 顯示時存在）：tooltip 沒了 → Restore；alpha 被改回來 → 重壓；
--      行數變了 → 排 Reconcile；尺寸漂了 → Fit；層級被抬 → 跟上
--   6. OnTooltipCleared → Release：先不拆，等下一幀；同一幀裡新的 post-call 會把它認領回去。
--      skin OnHide → OnSkinHide：也延一幀（清單刷新時游標那一列先藏、下一幀才 OnEnter 重設同一件；當場拆會閃）。
--
-- 任何一步出錯都由 Core/Hooks.lua 的 xpcall 接住；錯誤之後 Restore 也會被叫到（見 Hooks）。
--
-- 單位（kind = "unit"，2026-10-20）走同一條：開關、單位 token 的解析在 Panel/ReadUnit.lua 的 Panel.TryUnit，
-- 這裡多三件事——
--   * 指紋多一段「動態簽章」（目標、死亡、暫離…這些不在提示行裡、靠 Unit API 讀的），輪詢比到它變了就排對帳；
--     **只有動態那段變了**（行的指紋一樣）＝立刻重畫，不等 SETTLE（換目標不該慢 0.3 秒）
--   * 面板顯示時把血條／3D 模型改貼到面板（skin 跟著原生 alpha 0 看不見）；退回時貼回 skin
--   * 不在 post-call 裡退回（例如對帳讀到秘密值）時，原生行是暴雪的原樣（面板路徑不改寫行）⇒
--     Panel.UnitFallback 重跑一次舊樣式（Core/Hooks.lua）
--   * 身分受限的單位（state.panelRestricted，2026-10-21）：行的文字是秘密 ⇒ 改用只認型別的收法
--     （Panel.CollectRestrictedLines）；GUID 是秘密 ⇒ Key 是 nil，每次 post-call 都當新的一隻重畫
--     （滑鼠從一隻怪移到另一隻，token 都是 mouseover，分不出是不是同一隻）
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
if T.Unit then KIND[T.Unit] = "unit" end
Panel.KIND = KIND

-- P2／P3 在這裡登記各型別的 reader／view；沒登記的走最簡版
Panel.readers = Panel.readers or {}
Panel.views = Panel.views or {}

local POLL_INTERVAL = 0.1
local SETTLE = 0.3             -- 行數變少／同行數內容變了：連續這麼久才採用
Panel.SETTLE = SETTLE

-- 設定一改就 +1（進指紋：改了外觀要重畫）
Panel.settingsVersion = 0

local function Enabled(kind, state)
    -- 玩家／NPC 各自的開關、明文 token 由 Panel.TryUnit 先判斷過（它設 state.panelUnit）；沒走它進來的單位一律不接
    if kind == "unit" then return state.panelUnit ~= nil end
    local db = ns.db
    return db and db[kind] and db[kind].panel == true
end

-- 內嵌物品框（世界任務獎勵）或底部說明字顯示時，暴雪自己在用 padding ⇒ 不接
local BLIZZ_PADDING_USERS = { "ItemTooltip", "BottomFontString" }
local function ShownRegion(region)
    if type(region) ~= "table" or not region.IsShown then return false end
    local ok, shown = pcall(region.IsShown, region)
    return not ok or S.IsSecret(shown) or shown and true or false
end
local function Eligible(tip)
    for _, key in ipairs(BLIZZ_PADDING_USERS) do
        if ShownRegion(tip[key]) then return false end
    end
    -- 暴雪插進提示裡的框（GameTooltip_InsertFrame：UIWidget 組、進度條）：面板畫不出來，原生又在 alpha 0 ⇒ 不接。
    -- 只讀（暴雪自己的欄位，ClearLines 時清成 nil）
    local okF, frames = pcall(function() return tip.insertedFrames end)
    if okF and type(frames) == "table" and not S.IsSecret(frames) then
        for i = 1, #frames do
            if ShownRegion(frames[i]) then return false end
        end
    end
    return true
end
Panel.Eligible = Eligible

-- 指紋：所有行（文字＋顏色）＋設定版本＋行數。reader 只收明文，這裡串接是安全的
local function ColorKey(c)
    if not c then return "-" end
    return ("%.3f,%.3f,%.3f"):format(c[1], c[2], c[3])
end

-- 單位的動態簽章（ReadUnit.lua 定義；其他型別沒有）
local function Dynamic(kind, state)
    if kind ~= "unit" or not Panel.UnitDynamic then return "" end
    return Panel.UnitDynamic(state) or ""
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
    if kind == "unit" then
        local guid = S.PlainText(data.guid)
        return guid and ("unit:" .. guid) or nil
    end
    local id = S.PlainNumber(data.id)
    if id then return kind .. ":" .. id end
    local link = S.PlainText(data.hyperlink)
    if link and link ~= "" then return kind .. ":" .. link end
    return nil
end

-- 回傳 完整指紋、行的指紋、動態簽章
local function Fingerprints(tip, state, kind, rows, n)
    local lineFP = Panel.Fingerprint({ rows = rows, numLines = n }, kind .. "|" .. (Panel.CompareHeaderText(tip) or ""))
    local dyn = Dynamic(kind, state)
    return lineFP .. "\030" .. dyn, lineFP, dyn
end

local function Shown(tip)
    local ok, shown = pcall(tip.IsShown, tip)
    return ok and not S.IsSecret(shown) and shown and true or false
end

-- 讀行：身分受限的單位只認型別（ReadUnit.lua），其他照 CollectLines（任何秘密就整份放棄）
local function Collect(tip, state, kind, data)
    if kind == "unit" and state.panelRestricted and Panel.CollectRestrictedLines then
        return Panel.CollectRestrictedLines(tip, data)
    end
    return Panel.CollectLines(tip, data)
end

-- 身分受限的單位沒有 GUID 可當退回封鎖的 key：同一類共用一把（Core/Hooks.lua 的 UnitFallback、ReadUnit 的 TryUnit）
Panel.UNIT_BLOCK_RESTRICTED = "unit:restricted"

-- 身分受限的單位：名字、類型這些是秘密字串量不出寬，面板照原生排好的寬替它們留位置（Native.ContentWidth）。
-- **post-call 當下不量**：暴雪 InternalProcessInfo 是 ClearLines → 加行 → post-call → Show()，原生的尺寸到 Show 才照新內容重排。
-- 那一刻 GetWidth 還是上一次排的——同一隻刷新時是被我們撐到面板寬的那個（ClearLines 又已把 padding 清掉、扣不掉），
-- 面板寬被當成名字寬 ⇒ 每刷新一次寬 50～90、幾次就頂到 MAX_W；剛顯示時則是上一個提示（例如物品）的寬
-- （2026-10-22 回報「有時候好長、有點隨機」：刷新次數與上一個提示是什麼都是隨機的）。
-- ⇒ post-call 畫的時候用上次量到的 state.secretContentW（同一隻刷新＝同一個數字、不閃；換一隻頂多錯一幀；第一次沒有就只靠 minWidth），
--   對帳／輪詢（下一幀起，原生已照新內容排好）量到不一樣才更新、重畫。每次 post-call 之後的第一次量可以變窄（換了一隻），
--   之後同一輪只長不縮（別家的行晚一幀補上、輪流出現不會讓寬度來回）。
-- 回傳 新的寬（nil＝不用動）、這次有沒有量到。不改 state：輪詢只拿來決定要不要排對帳，採用在對帳裡
local function NewSecretWidth(tip, state)
    if not state.panelRestricted then return nil, false end
    local cw = Native.ContentWidth(tip, state)
    if not cw then return nil, false end
    local old = state.secretContentW
    if old and (math.abs(cw - old) <= 0.5 or (state.secretWidthSettled and cw < old)) then return nil, true end
    return cw, true
end

local function Now()
    return GetTime and GetTime() or 0
end

------------------------------------------------------------
-- 退回
------------------------------------------------------------
local restoringAll = false      -- Panel.RestoreAll 進行中（設定改了）：單位退回時不封鎖重接

function Panel.Restore(tip, state)
    if not state then return end
    local wasUnit = state.panelKind == "unit" and (state.native or (state.panel and state.panel:IsShown()))
    local unitKey = wasUnit and (state.panelKey or (state.panelRestricted and Panel.UNIT_BLOCK_RESTRICTED))
    state.releasePending = nil
    state.hidePending = nil
    state.reconcileToken = (state.reconcileToken or 0) + 1    -- 排著的 Reconcile 作廢
    state.reconcilePending = nil
    state.panelFingerprint, state.panelKey, state.panelFullLines, state.partialSince = nil, nil, nil, nil
    state.pendingFingerprint, state.pendingSince = nil, nil
    state.panelMaxWidth, state.panelMaxTotalHeight = nil, nil
    state.nativeMaxW, state.nativeMaxH = nil, nil          -- 原生的自然尺寸也只長不縮（Native.Fit）
    state.nativeSettledW, state.nativeSettledH = nil, nil
    state.panelData, state.panelKind, state.panelLines = nil, nil, nil
    state.panelLineFingerprint, state.panelDyn, state.panelUnit, state.panelGuid = nil, nil, nil, nil
    state.panelRestricted = nil
    state.secretContentW, state.secretWidthSettled = nil, nil
    state.panelBorder, state.panelTargetFS = nil, nil
    if state.panelPolling then
        state.panelPolling = nil
        Skin.Unpoll(state)
    end
    if state.native or (state.panel and state.panel:IsShown()) then
        local gone = state.panel
        -- 貼在這個面板上的別家框（外觀預覽）先貼回原生，再拆面板
        if gone then Panel.ReturnFollowers(gone) end
        Native.Restore(tip, state)
        -- 錨在這個面板上的（比價面板）當場改回貼自己的原生，不能錨在一個清掉錨點的框上
        if gone then
            Skin.Each(function(t2, s2)
                local p2 = s2.panel
                if p2 and s2.native and p2:IsShown() and Panel.AnchoredOn(p2, gone) then
                    if not Panel.Align(p2, t2) then Panel.Restore(t2, s2) end
                end
            end)
        end
    end
    if wasUnit then
        Panel.HostAccents(tip, state, nil)      -- 血條／模型貼回 skin
        -- 不在 post-call 裡（對帳／輪詢／設定改了）、提示還顯示著同一個單位 ⇒ 原生行是暴雪的原樣，重跑舊樣式
        if not state.inUnitPostCall and state.isUnitTip and Shown(tip) and Panel.UnitFallback then
            Panel.UnitFallback(tip, state, unitKey, not restoringAll)
        end
    end
end

-- 血條與 3D 模型改貼到哪（nil＝貼回 skin）。兩個模組在離線測試裡不存在
function Panel.HostAccents(tip, state, host)
    if ns.Bar and ns.Bar.SetHost then ns.Bar.SetHost(tip, host) end
    if ns.Model and ns.Model.SetHost then ns.Model.SetHost(tip, host) end
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

-- 設定改了：全部退回。顯示中的單位面板退回後讓暴雪重跑內容（UnitFallback 不封鎖）⇒ 開著就照新設定重畫、關了就走舊樣式
function Panel.RestoreAll()
    restoringAll = true
    Skin.Each(function(tip, state) pcall(Panel.Restore, tip, state) end)
    restoringAll = false
end

-- skin 的 OnShow（tooltip 從隱藏變顯示）：重申 alpha 0
function Panel.OnSkinShow(tip, state)
    if state and state.native then Native.Repress(tip, state) end
end

------------------------------------------------------------
-- 畫：rows 已經讀好（指紋用的那份）；失敗回 false（呼叫端 Restore）
------------------------------------------------------------
local function Render(tip, state, kind, data, rows, n, fingerprint, lineFP, dyn)
    local reader = Panel.readers[kind] or Panel.ReadFallback
    local model = reader(tip, data, kind, rows, n, state)
    if not model then return false end
    local panel = Panel.Get(tip, state)
    local view = (Panel.views[kind] or Panel.ViewFallback)(model, state)
    if not view or not Panel.RenderView(panel, tip, view, state) then return false end
    -- 只長不縮：記下這件看過的最大寬（RenderView 下次取 max）與最大總高（Native.Fit 撐原生用）
    state.panelMaxWidth = math.max(state.panelMaxWidth or 0, panel.width or 0)
    state.panelMaxTotalHeight = math.max(state.panelMaxTotalHeight or 0, panel.totalHeight or panel.height or 0)
    if not Panel.Align(panel, tip) or not Native.Hide(tip, state) then return false end
    if Native.Fit(tip, state) == false then return false end
    Panel.Unfade(panel)
    panel:Show()
    Panel.HostAccents(tip, state, kind == "unit" and panel or nil)
    if ns.logEnabled then ns.Log("重畫 key=%s 行數 %d 面板 %sx%s 總高 %s%s", tostring(state.panelKey), n,
        tostring(panel.width), tostring(panel.height), tostring(panel.totalHeight),
        state.panelRestricted and (" 受限 秘密字寬 " .. tostring(state.secretContentW)) or "") end
    state.panelFingerprint = fingerprint
    state.panelLineFingerprint, state.panelDyn = lineFP, dyn
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
    -- 顯示途中暴雪才插進框（進度條、UIWidget）：讓回原生
    if not Eligible(tip) then
        Panel.Restore(tip, state)
        return
    end
    Native.Repress(tip, state)
    if state.panel then Panel.SyncLevel(state.panel, tip) end
    -- 單位已經不在（滑鼠離開、提示淡出中）：維持最後的畫面，不重讀
    if state.panelKind == "unit" and Panel.UnitGone and Panel.UnitGone(state) then return end

    local rows, n = Collect(tip, state, state.panelKind, state.panelData)
    if not rows then
        Panel.Restore(tip, state)
        return
    end
    -- 身分受限：秘密字串的寬在這裡才量得準（NewSecretWidth）
    local secretW, measured = NewSecretWidth(tip, state)
    if measured then state.secretWidthSettled = true end
    local function wait()
        if Native.Fit(tip, state) == false then Panel.Restore(tip, state) return end
        ScheduleReconcile(tip, state)        -- 每幀重讀，直到穩定或回到現在畫的版本
    end
    local fingerprint, lineFP, dyn = Fingerprints(tip, state, state.panelKind, rows, n)
    local full = state.panelFullLines or 0
    if ns.logEnabled then
        ns.Log("對帳 key=%s 行數 %d（完整 %d）指紋%s", tostring(state.panelKey), n, full,
            fingerprint == state.panelFingerprint and "相同" or "不同")
    end

    if fingerprint == state.panelFingerprint and not secretW then
        -- 回到現在畫的版本：任何等待中的變化作廢
        state.partialSince, state.pendingFingerprint, state.pendingSince = nil, nil, nil
        state.panelFullLines, state.panelLines = math.max(full, n), n
        if Native.Fit(tip, state) == false then Panel.Restore(tip, state) end
        return
    end

    if state.panelSettings ~= Panel.settingsVersion then
        -- 設定改了：不是內容在抖，直接照新設定重畫
    elseif secretW then
        -- 秘密字串的寬量到新值（post-call 時用的是上一隻的、或還沒有）：立刻照真的寬重畫
    elseif lineFP == state.panelLineFingerprint then
        -- 行沒變、只有動態簽章變了（單位換目標、死了、暫離）：不是重建在抖，立刻重畫
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
    if secretW then
        if ns.logEnabled then ns.Log("受限單位 秘密字寬 %s → %.1f", tostring(state.secretContentW), secretW) end
        -- post-call 時照猜的寬畫過、記成了這輪的最大寬 ⇒ 放掉，才能變窄
        state.secretContentW, state.panelMaxWidth = secretW, nil
    end
    if not Render(tip, state, state.panelKind, state.panelData, rows, n, fingerprint, lineFP, dyn) then
        Panel.Restore(tip, state)
    end
end
Panel.Reconcile = Reconcile

-- 外部資料到貨（觀察裝等、成就點數）：當作動態簽章變了，下一幀重畫
function Panel.Poke(tip, state)
    if not state or not state.native or not state.panelData then return end
    state.panelFingerprint = nil
    ScheduleReconcile(tip, state)
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
    elseif state.panelKind == "unit" and state.panelData then
        -- 單位：目標、死亡、暫離這些不在行裡，比動態簽章（單位不在了回 nil，不動）
        local dyn = Panel.UnitDynamic and Panel.UnitDynamic(state)
        if dyn and dyn ~= state.panelDyn then ScheduleReconcile(tip, state) end
        -- 受限：原生排好的寬變了（行數沒變、內容變長），或上次對帳還量不到
        if NewSecretWidth(tip, state) then ScheduleReconcile(tip, state) end
        if Panel.UnitTick then Panel.UnitTick(state) end
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
-- dataType 是 Enum.TooltipDataType 的值，或直接給 "item"／"spell"／"unit"
-- 回傳 true＝面板顯示中（這份內容由面板接手）
function Panel.Try(tip, state, dataType, data)
    if not state or not ns.db then return false end
    local kind = KIND[dataType] or dataType
    if (kind ~= "item" and kind ~= "spell" and kind ~= "unit") or not Enabled(kind, state) then
        Panel.Restore(tip, state)
        return false
    end
    if S.IsForbiddenObject(tip) or not Eligible(tip) then
        Panel.Restore(tip, state)
        return false
    end

    local key = Panel.Key(kind, data)
    local panel = state.panel

    -- 同一件的重建：當幀不畫，下一幀 Reconcile 拿完整版
    if key and key == state.panelKey and panel and panel:IsShown() and state.native then
        if ns.logEnabled then ns.Log("Try 同一件 key=%s%s", tostring(key), state.hidePending and "（藏了又回來，認領）" or "") end
        state.releasePending = nil          -- 認領：上一份被清掉／藏起來時排定的拆除取消
        state.hidePending = nil
        state.panelData, state.panelKind = data, kind
        -- 邊框色在 ClearTransient 時被重設過，補回來（單位的邊色是 reader 算的，不重跑 reader，用記下的）
        local bc = kind == "unit" and state.panelBorder
        if bc and Skin.SetBorderColor then Skin.SetBorderColor(tip, bc[1], bc[2], bc[3], bc[4]) end
        Panel.PaintEdges(panel, state)
        Panel.Unfade(panel)
        -- Fit 的 partial：這一刻內容不完整，自然尺寸用上次對帳量到的（Native.lua）
        if not Native.Hide(tip, state) or Native.Fit(tip, state, true) == false then
            Panel.Restore(tip, state)
            return false
        end
        ScheduleReconcile(tip, state)
        return true
    end

    -- 新物件：立刻畫
    local rows, n = Collect(tip, state, kind, data)
    if not rows then
        Panel.Restore(tip, state)
        return false
    end
    state.releasePending = nil
    state.hidePending = nil
    state.panelData, state.panelKind = data, kind
    if ns.logEnabled then ns.Log("Try 新件 key=%s（之前 %s）", tostring(key), tostring(state.panelKey)) end
    -- 換一件：只長不縮的幾何與等待中的變化全部歸零
    state.panelMaxWidth, state.panelMaxTotalHeight = nil, nil
    state.nativeMaxW, state.nativeMaxH = nil, nil          -- 原生的自然尺寸也只長不縮（Native.Fit）
    state.nativeSettledW, state.nativeSettledH = nil, nil
    state.pendingFingerprint, state.pendingSince, state.partialSince = nil, nil, nil
    state.secretWidthSettled = nil       -- 秘密字串的寬：這次畫用上次量的，對帳第一次量到的可以變窄（NewSecretWidth）
    local fingerprint, lineFP, dyn = Fingerprints(tip, state, kind, rows, n)
    if not Render(tip, state, kind, data, rows, n, fingerprint, lineFP, dyn) then
        Panel.Restore(tip, state)
        return false
    end
    state.panelKey = key
    state.panelFullLines = n
    state.partialSince = nil
    ScheduleReconcile(tip, state)
    StartPoll(tip, state)
    return true
end

-- 不經過提示資料、直接拿現成的 model 畫（設定視窗的 NPC 預覽：沒有能 SetUnit 的 NPC，餵假資料）。
-- 沒有 panelData ⇒ 輪詢不對帳、只維持 alpha／尺寸；下一次 post-call（換預覽模式）照常接手或退回
function Panel.ShowModel(tip, state, kind, model)
    if not state or S.IsForbiddenObject(tip) or not Eligible(tip) then return false end
    local panel = Panel.Get(tip, state)
    state.releasePending, state.hidePending = nil, nil
    state.panelMaxWidth, state.panelMaxTotalHeight = nil, nil
    state.nativeMaxW, state.nativeMaxH, state.nativeSettledW, state.nativeSettledH = nil, nil, nil, nil
    local view = (Panel.views[kind] or Panel.ViewFallback)(model, state)
    if not view or not Panel.RenderView(panel, tip, view, state)
        or not Panel.Align(panel, tip) or not Native.Hide(tip, state) or Native.Fit(tip, state) == false then
        Panel.Restore(tip, state)
        return false
    end
    state.panelMaxWidth = panel.width
    state.panelMaxTotalHeight = panel.totalHeight or panel.height
    Panel.Unfade(panel)
    panel:Show()
    Panel.HostAccents(tip, state, kind == "unit" and panel or nil)
    state.panelKey, state.panelKind, state.panelData = "static:" .. kind, kind, nil
    state.panelFingerprint, state.panelLineFingerprint, state.panelDyn = nil, nil, nil
    StartPoll(tip, state)
    return true
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
        local cl, cr, ct, cb = Call(tip, "GetClampRectInsets")
        out(("  panel：height=%s total=%s  貼在 %s  原生夾邊=%s 範圍=%s,%s,%s,%s"):format(
            D(panel.height), D(panel.totalHeight), Points(panel), D((Call(tip, "IsClampedToScreen"))), D(cl), D(cr), D(ct), D(cb)))
        if state.panelRestricted then
            out(("  受限單位：面板寬=%s  秘密字寬=%s（現在量=%s）"):format(
                D(panel.width), D(state.secretContentW), D(Native.ContentWidth(tip, state))))
        end
    end)
    if count == 0 then out("目前沒有顯示中的面板（滑過物品或法術時再下一次指令）") end
    -- 貼在面板旁的別家框（外觀預覽，Panel.Follow）：只印貼在面板的——貼在哪、它原本要貼哪
    local any = false
    for frame, rec in pairs(Panel.followers or {}) do
        any = true
        if rec.panel then
            out(("|cff4DD2FF跟隨框 %s|r：貼在面板 %s  （它要的是 %s→%s:%s）"):format(
                D(frame), Points(frame), D(rec[1]), D(rec[2]), D(rec[3])))
        end
    end
    if not any then
        out(_G.AppearanceTooltipTooltip and "外觀預覽框存在，但沒有登記跟隨（Adopt 沒帶 followPanel，或 MiliUI_Skin 沒委派成功）"
            or "沒有登記的跟隨框")
    end
    return count
end
