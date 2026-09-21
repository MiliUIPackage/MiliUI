------------------------------------------------------------
-- 診斷報告：/mquest debug
--
-- 針對「追蹤器少了一段（場景進度、開始前倒數），重新登入就好了」這種回報。
-- 看起來一模一樣的畫面，底下有三種完全不同的病因，不先分開就只能亂猜：
--
--   A. 官方 API 沒給資料 —— C_Scenario 說根本不在場景裡。暴雪／伺服器端的問題，
--      插件無能為力，回報給暴雪就好。
--   B. API 有資料，但暴雪的場景模組沒渲染 —— 模組的 state 停在 NoObjectives／Skipped、
--      Update 從來沒被叫到、或 Update 途中拋錯。多半是 taint：某個插件把追蹤器的表
--      弄髒，暴雪的排版在污染的執行下讀到秘密值就炸；而容器的派送迴圈**沒有 pcall**
--      （對照 Blizzard_ObjectiveTrackerContainer.lua 的 Update），一個模組炸掉、
--      後面的全部跳過。「重新登入就好」正是這一型的指紋 —— taint 只有重登會清。
--      同一型還有 widget 那條路：追蹤器的 widget set 是伺服器指派的，跟 C_Scenario 無關，
--      所以「不在場景裡」不代表 widget 就該是空的（開始前倒數那類就是 widget）。
--   C. 模組有渲染，但被我們藏掉 —— 摺疊、alpha、換父層、位置飄到螢幕外。我們的 bug。
--   D. 排不進去 —— 追蹤器的高度放不下任何區塊，容器的 Update 走到最後自己 Hide()。
--      **不報錯**，而且連我們的標題列一起消失（標題列跟著「有沒有內容」走）。場景模組有
--      顯示優先權，它一被截斷、後面所有模組的可用高度就歸零，所以只在場景／探究裡發作。
--
-- 所以報告分成 API 端／容器與模組端／我們這端三段對照，再加 taint 檢查（issecurevariable
-- 會直接點名是哪個插件弄髒的）與錯誤記錄，最後給一句判定。
--
-- 「目標行字型」那段對付的是另一個症狀（同一個任務底下有幾行字級不一樣），
-- 不參與判定，理由寫在 SecLines 上面。
--
-- 全程唯讀。共用 widget pool 的兩支（場景／UI widget）只讀**模組框本身**的欄位，
-- 不進子區塊（Core/Tracker.lua 規矩 3）。每一段都各自 pcall：某段拋錯不能讓整份報告
-- 消失 —— 報告最需要的時候，正是有東西壞掉的時候。
------------------------------------------------------------
local _, ns = ...

ns.Diag = {}
local D = ns.Diag
local T = ns.Tracker
local IsSecret = ns.Secret.IsSecret

local loginAt = GetTime()

------------------------------------------------------------
-- 被動記錄
--
-- 這些在平常就默默記著，不然等玩家看到症狀再開報告時，「模組上次什麼時候被
-- Update 過」這種問題已經沒得問了。全部只是往自己的表寫幾個數字，沒有成本可言。
------------------------------------------------------------
-- 子追蹤器的 Update 被呼叫過幾次、上一次在什麼時候（Modules/Skin.lua 的 hook 會報）
local updateCount = T.Flags()
local updateLast  = T.Flags()

function D.NoteUpdate(tracker)
    if not tracker then return end
    updateCount[tracker] = (updateCount[tracker] or 0) + 1
    updateLast[tracker]  = GetTime()
end

-- 區塊上一次被 SkinBlock 走過是什麼時候。「字級不一致的那行」要分辨是從來沒套到、
-- 還是套過之後被換掉，看的就是這個時間跟行的狀態對不對得起來
local skinLast = T.Flags()

function D.NoteSkin(block)
    skinLast[block] = GetTime()
end

-- 跟場景有關的事件什麼時候來過。「API 事件來了、模組卻沒 Update」跟
-- 「事件根本沒來」是兩種病
local WATCH_EVENTS = {
    "SCENARIO_UPDATE", "SCENARIO_CRITERIA_UPDATE", "SCENARIO_COMPLETED",
    "WORLD_STATE_TIMER_START", "WORLD_STATE_TIMER_STOP",
    "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
}
local eventLast, eventCount = {}, {}

-- **其他**插件被封鎖的動作。共用層的 Errors.lua 只記我們自己的；追蹤器是被別的
-- 插件弄髒時，這裡是報告裡唯一會點到名字的地方。同一組 插件:函式 只留一筆計數
local blocked = {}
local MAX_BLOCKED = 12

local watcher = CreateFrame("Frame")
for _, e in ipairs(WATCH_EVENTS) do watcher:RegisterEvent(e) end
watcher:RegisterEvent("ADDON_ACTION_BLOCKED")
watcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watcher:SetScript("OnEvent", function(_, event, addonName, funcName)
    if event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
        if addonName == ns.ADDON_NAME then return end   -- 自己的走 Errors.lua
        local key = tostring(addonName) .. ":" .. tostring(funcName)
        for _, b in ipairs(blocked) do
            if b.key == key then
                b.count, b.last = b.count + 1, GetTime()
                return
            end
        end
        blocked[#blocked + 1] = { key = key, count = 1, last = GetTime() }
        while #blocked > MAX_BLOCKED do table.remove(blocked, 1) end
        return
    end
    eventLast[event]  = GetTime()
    eventCount[event] = (eventCount[event] or 0) + 1
end)

------------------------------------------------------------
-- 印值的工具：秘密值一律印成 <secret>，不讀它
------------------------------------------------------------
local function Str(v)
    if v == nil then return "nil" end
    if IsSecret(v) then return "<secret>" end
    local t = type(v)
    if t == "string" then return v end
    if t == "number" then
        if v == math.floor(v) then return ("%d"):format(v) end
        return ("%.2f"):format(v)
    end
    if t == "boolean" then return v and "true" or "false" end
    return t
end

local function Trunc(s, n)
    if type(s) ~= "string" or IsSecret(s) then return Str(s) end
    if #s <= n then return s end
    -- 位元組截斷會把中文字切成半個，剩下的殘缺位元組在編輯框裡顯示成亂碼。
    -- 切點落在延續位元組（10xxxxxx）上就往前退到那個字的開頭
    local cut = n
    while cut > 0 do
        local byte = s:byte(cut + 1)
        if not byte or byte < 0x80 or byte >= 0xC0 then break end
        cut = cut - 1
    end
    return s:sub(1, cut) .. "…"
end

local function Ago(t)
    if not t then return "never" end
    return ("%.1fs ago"):format(GetTime() - t)
end

local function EnumName(tbl, value)
    if type(tbl) ~= "table" or value == nil or IsSecret(value) then return Str(value) end
    for k, v in pairs(tbl) do
        if v == value then return k end
    end
    return Str(value)
end

local function ShortName(frame)
    local name = frame and frame.GetName and frame:GetName()
    if type(name) ~= "string" then return "?" end
    return (name:gsub("ObjectiveTracker", ""))
end

-- 每一段各自隔離：某段拋錯只損失那一段，而且錯誤本身就是線索，要印出來
local function Section(out, title, fn, ctx)
    out[#out + 1] = "== " .. title
    local ok, err = pcall(fn, function(fmt, ...)
        out[#out + 1] = "  " .. (select("#", ...) > 0 and fmt:format(...) or fmt)
    end, ctx)
    if not ok then
        out[#out + 1] = "  !! section failed: " .. (IsSecret(err) and "<secret>" or tostring(err))
    end
end

------------------------------------------------------------
-- 各段
------------------------------------------------------------
local function SecEnv(add)
    local name, itype, diff, diffName, _, _, _, mapID = GetInstanceInfo()
    add("v%s  uptime=%.0fs  combat=%s", ns.VERSION, GetTime() - loginAt,
        tostring(InCombatLockdown() and true or false))
    add("instance: %s  type=%s  difficulty=%s (%s)  instanceMapID=%s",
        Str(name), Str(itype), Str(diff), Str(diffName), Str(mapID))
    add("zone: %s / %s", Str(GetZoneText()), Str(GetSubZoneText()))
    add("scriptErrors=%s  BugGrabber=%s", Str(GetCVar("scriptErrors")), tostring(_G.BugGrabber ~= nil))
end

-- widget 的 shownState 不在 GetAllWidgetsBySetID 回的輕量結構裡，要走各型別自己的
-- visualization info getter。名字有兩種拼法（TextureAndText →
-- GetTextureAndTextWidgetVisualizationInfo，SpellDisplay → GetSpellDisplayVisualizationInfo），
-- 所以不要手寫清單，照 Enum 名字兩種都試一次，配不到的印 shown=?
local visGetter
local function VisGetter(widgetType)
    if not visGetter then
        visGetter = {}
        local e = Enum and Enum.UIWidgetVisualizationType
        if type(e) == "table" and C_UIWidgetManager then
            for name, value in pairs(e) do
                visGetter[value] = C_UIWidgetManager["Get" .. name .. "VisualizationInfo"]
                    or C_UIWidgetManager["Get" .. name .. "WidgetVisualizationInfo"]
            end
        end
    end
    return visGetter[widgetType]
end

-- 四態，因為它們代表四件不同的事：
--   shown/hidden  widget 有 visualization info，其中的 shownState 說了算
--   noinfo        getter 有，但這個 widget 現在問不到資料 —— 等於畫不出來
--   ?             這個型別沒有對得上的 getter，我們不知道（不能當成「沒顯示」）
local function WidgetState(w)
    local getter = VisGetter(w.widgetType)
    if not getter then return "?" end
    local ok, info = pcall(getter, w.widgetID)
    if not ok or type(info) ~= "table" then return "noinfo" end
    local state = info.shownState
    if state == nil or IsSecret(state) then return "?" end
    if state == (Enum and Enum.WidgetShownState and Enum.WidgetShownState.Shown or 1) then
        return "shown"
    end
    return "hidden"
end

-- ⚠ GetAllWidgetsBySetID **連隱藏的 widget 也一起回**（2026-09-08 的基準報告裡
-- 「top-center widget set: setID=1 widgets=33」就是證據 —— 螢幕上從來不會同時掛 33 個）。
-- 所以「set 裡有幾個」不等於「畫得出來幾個」，只印總數的話這一行沒有證據能力 ——
-- 而症狀正好就是「widget 該出來卻沒出來」。要印的是 shown 的數量。
local function WidgetSetLine(add, label, setID)
    if setID == nil then
        add("%s: nil", label)
        return 0
    end
    if IsSecret(setID) then
        add("%s: <secret>", label)
        return nil
    end
    local widgets = C_UIWidgetManager and C_UIWidgetManager.GetAllWidgetsBySetID
        and C_UIWidgetManager.GetAllWidgetsBySetID(setID)
    local n = type(widgets) == "table" and #widgets or 0
    local state, count = {}, { shown = 0, hidden = 0, noinfo = 0, ["?"] = 0 }
    for i = 1, n do
        state[i] = WidgetState(widgets[i])
        count[state[i]] = count[state[i]] + 1
    end
    -- 只列 8 個，但**顯示中的先排**：隱藏的 widget 在 set 裡通常佔多數，
    -- 照順序截前 8 個很容易 8 個全是隱藏的，真正有用的那幾個反而不見
    local kinds = {}
    for _, want in ipairs({ "shown", "?", "noinfo", "hidden" }) do
        for i = 1, n do
            if #kinds >= 8 then break end
            if state[i] == want then
                kinds[#kinds + 1] = ("%s:%s(%s)"):format(Str(widgets[i].widgetID),
                    EnumName(Enum and Enum.UIWidgetVisualizationType, widgets[i].widgetType), want)
            end
        end
    end
    local extra = ""
    if count.noinfo > 0 then extra = extra .. (" noinfo=%d"):format(count.noinfo) end
    if count["?"] > 0 then extra = extra .. (" unknown=%d"):format(count["?"]) end
    add("%s: setID=%s widgets=%d shown=%d hidden=%d%s %s", label, Str(setID), n,
        count.shown, count.hidden, extra, table.concat(kinds, " "))
    return count.shown
end

local function SecApi(add, ctx)
    local inScenario = C_Scenario and C_Scenario.IsInScenario and C_Scenario.IsInScenario()
    add("C_Scenario.IsInScenario=%s", Str(inScenario))
    ctx.apiScenario = (inScenario == true)

    local info = C_ScenarioInfo and C_ScenarioInfo.GetScenarioInfo and C_ScenarioInfo.GetScenarioInfo()
    if info then
        add("scenario: %s  scenarioID=%s type=%s stage=%s/%s complete=%s",
            Trunc(info.name, 40), Str(info.scenarioID),
            EnumName(Enum and Enum.ScenarioType, info.type),
            Str(info.currentStage), Str(info.numStages), Str(info.isComplete))
        -- 暴雪自己的判準是 numStages > 0（ScenarioObjectiveTrackerMixin:LayoutContents）
        local stages = ns.Secret.PlainNumber(info.numStages)
        if stages then ctx.apiScenario = stages > 0 end
    else
        add("GetScenarioInfo → nil")
    end

    local step = C_ScenarioInfo and C_ScenarioInfo.GetScenarioStepInfo and C_ScenarioInfo.GetScenarioStepInfo()
    if step then
        add("step: %s  stepID=%s numCriteria=%s widgetSetID=%s weighted=%s failed=%s",
            Trunc(step.title, 40), Str(step.stepID), Str(step.numCriteria),
            Str(step.widgetSetID), Str(step.weightedProgress), Str(step.stepFailed))
        local n = ns.Secret.PlainNumber(step.numCriteria) or 0
        for i = 1, math.min(n, 12) do
            local c = C_ScenarioInfo.GetCriteriaInfo and C_ScenarioInfo.GetCriteriaInfo(i)
            if c then
                add("  [%d] %s  done=%s  %s/%s (%s)", i, Trunc(c.description, 40),
                    Str(c.completed), Str(c.quantity), Str(c.totalQuantity), Str(c.quantityString))
            else
                add("  [%d] GetCriteriaInfo → nil", i)
            end
        end
        ctx.stepWidgetSetID = step.widgetSetID
    else
        add("GetScenarioStepInfo → nil")
    end

    if C_UIWidgetManager then
        ctx.trackerWidgetsShown = WidgetSetLine(add, "tracker widget set",
            C_UIWidgetManager.GetObjectiveTrackerWidgetSetID and C_UIWidgetManager.GetObjectiveTrackerWidgetSetID())
        if ctx.stepWidgetSetID ~= nil then
            WidgetSetLine(add, "step widget set", ctx.stepWidgetSetID)
        end
        WidgetSetLine(add, "top-center widget set",
            C_UIWidgetManager.GetTopCenterWidgetSetID and C_UIWidgetManager.GetTopCenterWidgetSetID())
    end

    -- 開始前的倒數／限時是 world timer。GetWorldElapsedTimers 回的是**多回傳值**
    -- （對照 ScenarioTimerMixin:CheckTimers 的 select("#", ...) 寫法），沒有計時器時
    -- 會回一個空的佔位值 —— 2026-09-06 的基準報告印出 "world timer : elapsed=0 type=0"
    -- 就是它 —— 所以只認正整數的 ID
    local shown = 0
    local timers = { GetWorldElapsedTimers() }
    for i = 1, #timers do
        local timerID = timers[i]
        if type(timerID) == "number" and not IsSecret(timerID) and timerID > 0 then
            local id, elapsed, ttype = GetWorldElapsedTime(timerID)
            shown = shown + 1
            add("world timer %s: elapsed=%s type=%s", Str(id), Str(elapsed),
                EnumName(Enum and Enum.WorldElapsedTimerTypes, ttype))
        end
    end
    if shown == 0 then add("world timers: none") end
end

local function SecContainer(add, ctx)
    local otf = T.OTF()
    if not otf then
        add("ObjectiveTrackerFrame is nil!")
        return
    end
    local parent = otf:GetParent()
    local pname = parent and parent.GetName and parent:GetName() or "?"
    local collapsed = otf.IsCollapsed and otf:IsCollapsed()
    add("OTF shown=%s visible=%s alpha=%.2f parent=%s protected=%s collapsed=%s size=%.0fx%.0f scale=%.2f",
        tostring(otf:IsShown()), tostring(otf:IsVisible()), otf:GetAlpha() or -1, Str(pname),
        tostring(otf:IsProtected()), Str(collapsed), otf:GetWidth() or -1, otf:GetHeight() or -1,
        otf:GetEffectiveScale() or -1)
    ctx.otfVisible = otf:IsVisible() and (otf:GetAlpha() or 0) > 0
    ctx.otfShown   = otf:IsShown() and true or false
    ctx.otfHeight  = otf:GetHeight()

    -- 追蹤器的高度是算出來的：預設位置時 ＝ 父層高度 ＋ 第一個錨點的 y 位移（最低 20），
    -- 見 ObjectiveTrackerContainerMixin:UpdateHeight。高度不夠 ⇒ 模組排不進去 ⇒ 容器
    -- 自己 Hide()，整份清單**不報錯地**消失。所以把算式的三個輸入都印出來
    local point, rel, relPoint, ox, oy = otf:GetPoint(1)
    add("OTF height inputs: parentHeight=%s point1=%s>%s.%s(%s, %s) numPoints=%s topPadding=%s defaultPosition=%s editModeHeight=%s",
        Str(parent and parent.GetHeight and parent:GetHeight()), Str(point),
        Str(rel and rel.GetName and rel:GetName() or (rel and "unnamed")), Str(relPoint), Str(ox), Str(oy),
        Str(otf:GetNumPoints()), Str(otf.topModulePadding),
        Str(otf.IsInDefaultPosition and otf:IsInDefaultPosition()), Str(otf.editModeHeight))

    -- 位置換算成 UIParent 座標再跟螢幕比，才看得出是不是飄到外面去了
    local s, us = otf:GetEffectiveScale() or 1, UIParent:GetEffectiveScale() or 1
    local l, t = otf:GetLeft(), otf:GetTop()
    if l and t then
        local ul, ut = l * s / us, t * s / us
        local sw, sh = GetScreenWidth(), GetScreenHeight()
        add("OTF topleft=(%.0f, %.0f) of screen %.0fx%.0f", ul, ut, sw, sh)
        ctx.offscreen = ul > sw or ul < -otf:GetWidth() or ut < 0 or ut > sh + otf:GetHeight()
    else
        add("OTF has no rect yet")
    end

    local names = {}
    for _, m in ipairs(otf.modules or {}) do names[#names + 1] = ShortName(m) end
    add("modules(%d): %s", #names, table.concat(names, " "))
end

local MODULE_FIELDS = {
    "usedBlocks", "hasContents", "contentsHeight", "state", "isCollapsed",
    "hasSkippedBlocks", "isDirty", "availableHeight",
}

local function SecModules(add, ctx)
    local otf = T.OTF()
    local StateEnum = _G.ObjectiveTrackerModuleState
    T.EachTracker(function(m)
        local inList = false
        for _, x in ipairs(otf and otf.modules or {}) do
            if x == m then inList = true end
        end
        -- 只數、不碰：pairs 走我們自己拿到的表參照，不對區塊呼叫任何方法
        local blocks = 0
        if type(m.usedBlocks) == "table" then
            for _, byTemplate in pairs(m.usedBlocks) do
                if type(byTemplate) == "table" then
                    for _ in pairs(byTemplate) do blocks = blocks + 1 end
                end
            end
        end
        local shown = m.IsShown and m:IsShown()
        add("%s: shown=%s alpha=%s inList=%s state=%s hasContents=%s h=%s avail=%s collapsed=%s skipped=%s blocks=%d updates=%d last=%s",
            ShortName(m), tostring(shown), Str(m.GetAlpha and m:GetAlpha()), tostring(inList),
            EnumName(StateEnum, m.state), Str(m.hasContents), Str(m.contentsHeight), Str(m.availableHeight),
            Str(m.isCollapsed), Str(m.hasSkippedBlocks), blocks,
            updateCount[m] or 0, Ago(updateLast[m]))
        -- 「排不進去」的兩個指紋：NotShown ＝ 試過區塊、一個都放不下；ShownPartially ＝ 放了一部分。
        -- 場景模組有顯示優先權，它一被截斷，後面所有模組的可用高度就歸零（容器 Update 的第一圈）
        if inList and StateEnum and not IsSecret(m.state) then
            if m.state == StateEnum.NotShown then
                ctx.notShown = ctx.notShown or {}
                ctx.notShown[#ctx.notShown + 1] = ShortName(m)
            elseif m.state == StateEnum.ShownPartially or m.state == StateEnum.ShownFully then
                ctx.anyDisplayable = true
            end
        end
        if m == _G.ScenarioObjectiveTracker then
            add("  scenario module: scenarioID=%s currentStage=%s shouldShowCriteria=%s priority=%s",
                Str(m.scenarioID), Str(m.currentStage), Str(m.shouldShowCriteria), Str(m.hasDisplayPriority))
            ctx.scenarioShown   = shown and (m.hasContents == true)
            ctx.scenarioState   = EnumName(StateEnum, m.state)
            ctx.scenarioContent = Str(m.hasContents)
            ctx.scenarioUpdates = updateCount[m] or 0
        end
        if m == _G.UIWidgetObjectiveTracker then
            ctx.widgetShown   = shown and (m.hasContents == true)
            ctx.widgetState   = EnumName(StateEnum, m.state)
            ctx.widgetContent = Str(m.hasContents)
        end
    end)
end

local function SecTaint(add, ctx)
    if type(issecurevariable) ~= "function" then
        add("issecurevariable unavailable")
        return
    end
    local checked, tainted = 0, 0
    local function Check(tbl, key, label)
        if type(tbl) ~= "table" or tbl[key] == nil then return end
        checked = checked + 1
        local secure, source = issecurevariable(tbl, key)
        if not secure then
            tainted = tainted + 1
            add("TAINTED %s.%s ← %s", label, key, Str(source))
        end
    end
    for _, g in ipairs({ "ObjectiveTrackerFrame", "ScenarioObjectiveTracker",
                         "UIWidgetObjectiveTracker", "UIWidgetManager" }) do
        Check(_G, g, "_G")
    end
    local otf = T.OTF()
    for _, k in ipairs({ "modules", "isCollapsed", "needsSorting" }) do Check(otf, k, "OTF") end
    T.EachTracker(function(m)
        local label = ShortName(m)
        for _, k in ipairs(MODULE_FIELDS) do Check(m, k, label) end
    end)
    local uwm = _G.UIWidgetManager
    for _, k in ipairs({ "registeredWidgetSetContainers", "widgetVisTypeInfo", "widgetPools" }) do
        Check(uwm, k, "UIWidgetManager")
    end
    add("checked %d fields, %d tainted", checked, tainted)
    ctx.tainted = tainted
end

local function SecOurs(add, ctx)
    local st = T.DiagState()
    add("folded=%s wantHidden=%s parentedAway=%s mouseBlocker=%s trackerVisible=%s canReposition=%s",
        tostring(ns.Visibility and ns.Visibility.IsFolded()), tostring(st.wantHidden),
        tostring(st.parentedAway), tostring(st.blockerShown), tostring(T.IsVisible()),
        tostring(T.CanReposition()))
    -- 暴雪在我們摺著的時候把 parent 拿回去的次數（編輯模式套用版面就會），見 Core/Tracker.lua
    add("parentReclaimed=%d last=%s", st.reclaimCount or 0, Ago(st.reclaimLast))
    -- 「要藏」卻三條路都沒落地 ＝ 標題列說摺著、清單卻開著。收斂是下一幀的事，
    -- 所以這行出現在報告裡就代表沒收斂到
    local otf = T.OTF()
    if st.wantHidden and not st.parentedAway and not st.blockerShown
       and otf and otf:IsVisible() and (otf:GetAlpha() or 0) > 0 then
        ctx.hideMismatch = true
        add("!! wantHidden=true but the tracker is on screen (parent=%s)",
            Str(otf:GetParent() and otf:GetParent().GetName and otf:GetParent():GetName() or "?"))
    end
    -- 標題列是玩家唯一能把清單點回來的把手，它在哪裡要印出來：2026-09-22 的回報就是
    -- 它跟著被抽離版面的追蹤器飛到螢幕頂端、被小地圖蓋住，報告裡卻只看得到 bar=true/true。
    -- 摺著的時候它該待在存檔的那個位置（Modules/Chrome.lua 的 RememberTrackerRect），
    -- 跟上面 OTF topleft 對不上是正常的
    local bar = ns.Chrome and ns.Chrome.GetBar and ns.Chrome.GetBar()
    if bar then
        local us = UIParent:GetEffectiveScale() or 1
        local bs = bar:GetEffectiveScale() or 1
        local l, t = bar:GetLeft(), bar:GetTop()
        if l and t then
            local ul, ut = l * bs / us, t * bs / us
            add("title bar topleft=(%.0f, %.0f) size=%.0fx%.0f", ul, ut, bar:GetWidth() or -1, bar:GetHeight() or -1)
            if ul < 0 or ul > GetScreenWidth() or ut < 0 or ut > GetScreenHeight() then
                ctx.barOffscreen = true
                add("!! title bar is off-screen")
            end
        else
            ctx.barOffscreen = bar:IsShown()
            add("title bar has no rect")
        end
    end
    local emm = _G.EditModeManagerFrame
    add("mythicPlus.inChallenge=%s positionOverridden=%s editMode=%s",
        tostring(ns.MythicPlus and ns.MythicPlus.IsInChallenge()),
        tostring(ns.Position and ns.Position.IsOverridden()),
        tostring(emm and emm:IsShown() or false))
    if ns.Chrome and ns.Chrome.Diagnose then
        for _, line in ipairs(ns.Chrome.Diagnose()) do add("%s", line) end
    end
end

------------------------------------------------------------
-- 目標行的字型
--
-- 針對「同一個任務底下，有幾行字級／描邊跟別行不一樣」。暴雪的目標行都繼承
-- ObjectiveTrackerLineFont（編輯模式的「文字大小」改的就是那個字型物件；繁中的 12
-- 實際是 15），SetFont 過的行才是我們的字級 —— 所以對不上的那行，就是 SkinLine 在
-- 某個時間點沒碰到的行。每行對照四樣：
--   字級/描邊  GetFont 的實際值 vs 設定頁要的值，對不上的行標 !!
--   role       StyleFS 有沒有碰過這個 FontString（"-" ＝從來沒有）
--   state      暴雪的動畫狀態（目標完成那行走 Completing → Completed）
--   c          文字顏色。暴雪的一般色 0.80、完成色 0.60（SetStringText 只在色系換掉時
--              才重設），我們的目標行預設 0.72 —— 完成那行印 0.60 就是那之後 SkinLine
--              沒再跑過
-- 另外列「顯示中、卻不在 usedLines 裡」的行：SkinLine 只走 usedLines，那之外的行
-- 我們永遠套不到。
--
-- 共用 widget pool 的兩支只列場景目標行那一組（規矩 3 的例外，走 T.EachScenarioLine），
-- 區塊與 widget 不碰。全程只讀。
------------------------------------------------------------
local function Basename(path)
    if type(path) ~= "string" or IsSecret(path) then return nil end
    return (path:match("([^\\/]+)$") or path):lower()
end

local function FontInfo(fs)
    local path, size, flags = fs:GetFont()
    local plainFlags = type(flags) == "string" and not IsSecret(flags) and flags or ""
    return size, plainFlags, Basename(path) or Str(path)
end

local function FontDesc(fs, role)
    local size, flags, file = FontInfo(fs)
    local sizeText = (type(size) == "number" and not IsSecret(size))
        and ("%g"):format(math.floor(size * 10 + 0.5) / 10) or Str(size)
    local color = "?"
    if fs.GetTextColor then
        local r, g, b = fs:GetTextColor()
        if type(r) == "number" and type(g) == "number" and type(b) == "number"
           and not (IsSecret(r) or IsSecret(g) or IsSecret(b)) then
            local rs, gs, bs = ("%.2f"):format(r), ("%.2f"):format(g), ("%.2f"):format(b)
            color = (rs == gs and gs == bs) and rs or (rs .. "/" .. gs .. "/" .. bs)
        end
    end
    return ("%s/%s %s role=%s c=%s"):format(sizeText, flags ~= "" and flags or "-", file,
        role or "-", color)
end

-- 對不上的項目（"size+outline"），一致回 nil
local function FontMismatch(fs, want)
    local size, flags, file = FontInfo(fs)
    local why = {}
    if type(size) ~= "number" or IsSecret(size) or math.abs(size - want.size) > 0.5 then
        why[#why + 1] = "size"
    end
    if (flags:find("OUTLINE", 1, true) ~= nil) ~= want.outline then
        why[#why + 1] = "outline"
    end
    if want.file and file ~= want.file then why[#why + 1] = "font" end
    return #why > 0 and table.concat(why, "+") or nil
end

-- 照螢幕上的順序排：先走暴雪排版串起來的 firstBlock → nextBlock，
-- 再補 usedBlocks 裡沒排上去的。兩邊對不起來本身就是線索，所以各自標出來
local function BlocksInOrder(tracker)
    local inPool = {}
    T.EachBlock(tracker, function(block) inPool[block] = true end)
    local list, seen = {}, {}
    local block = tracker.firstBlock
    while type(block) == "table" and not seen[block] do
        seen[block] = true
        list[#list + 1] = { block = block, note = inPool[block] and "" or "  (not in usedBlocks)" }
        block = block.nextBlock
    end
    for b in pairs(inPool) do
        if not seen[b] then list[#list + 1] = { block = b, note = "  (not laid out)" } end
    end
    return list
end

-- 數字鍵（第幾個目標）照順序在前，字串鍵（QuestComplete、Waypoint…）在後。
-- 傳區塊就走它的 usedLines；傳陣列（場景那組）就直接排
local function SortedLines(source)
    local list = {}
    if source.usedLines or source.lines then
        T.EachLine(source, function(line) list[#list + 1] = line end)
    else
        for i = 1, #source do list[i] = source[i] end
    end
    table.sort(list, function(x, y)
        local a, b = x.objectiveKey, y.objectiveKey
        local na, nb = type(a) == "number", type(b) == "number"
        if na ~= nb then return na end
        if na then return a < b end
        return tostring(a) < tostring(b)
    end)
    return list
end

local function SecLines(add, ctx)
    local a = ns.db and ns.db.appearance
    if not a then
        add("no saved settings yet")
        return
    end
    local want = {
        size    = a.objectiveSize,
        outline = a.outline and true or false,
        file    = Basename(ns.Media.OptionalFont(a.font)),
    }
    local wantTitle = { size = a.titleSize, outline = want.outline, file = want.file }
    local base = _G.ObjectiveTrackerLineFont
    add("want objective=%s title=%s outline=%s font=%s | Blizzard ObjectiveTrackerLineFont=%s",
        Str(a.objectiveSize), Str(a.titleSize), tostring(want.outline), want.file or "keep",
        (base and base.GetFont) and FontDesc(base) or "nil")

    local Role = ns.Skin and ns.Skin.FontRole or function() return nil end
    local StateEnum = _G.ObjectiveTrackerAnimLineState
    local total, bad, never, orphans = 0, 0, 0, 0

    -- 一組行逐行比對，回傳明細與這組有幾行對不上
    local function Describe(lines)
        local details, groupBad = {}, 0
        for _, line in ipairs(lines) do
            local fs = line.Text
            if fs and fs.GetFont then
                total = total + 1
                local role = Role(fs)
                local why = FontMismatch(fs, want)
                if why then bad, groupBad = bad + 1, groupBad + 1 end
                if not role then never = never + 1 end
                details[#details + 1] = ("  %s [%s] %s state=%s  %s"):format(
                    why and ("!! " .. why) or "ok", Str(line.objectiveKey), FontDesc(fs, role),
                    EnumName(StateEnum, line.state), Trunc(fs:GetText(), 40))
            end
        end
        return details, groupBad
    end

    -- 場景的目標行（規矩 3 的例外，見 T.EachScenarioLine）。區塊本身不碰，
    -- 所以沒有標題、也不掃孤兒行（那要對區塊呼叫 GetChildren）；秘密文字的行本來就不套，這裡也不列
    local sLines = {}
    T.EachScenarioLine(function(line) sLines[#sLines + 1] = line end)
    if #sLines > 0 then
        local details, groupBad = Describe(SortedLines(sLines))
        add("%sScenario objectives  lines=%d bad=%d  skinned %s", groupBad > 0 and "!! " or "",
            #sLines, groupBad, Ago(skinLast[_G.ScenarioObjectiveTracker]))
        if groupBad > 0 then
            for _, d in ipairs(details) do add("%s", d) end
        end
    end

    T.EachTracker(function(tracker)
        if T.SharesWidgetPool(tracker) then return end
        for _, entry in ipairs(BlocksInOrder(tracker)) do
            local block = entry.block
            local lines = SortedLines(block)
            local details, blockBad = Describe(lines)
            local used = {}
            for _, line in ipairs(lines) do used[line] = true end

            if block.GetChildren then
                for _, child in ipairs({ block:GetChildren() }) do
                    if not used[child] and child.objectiveKey ~= nil and child.Text
                       and child.Text.GetFont and child:IsShown() then
                        orphans, blockBad = orphans + 1, blockBad + 1
                        details[#details + 1] = ("  !! orphan [%s] %s state=%s  %s"):format(
                            Str(child.objectiveKey), FontDesc(child.Text, Role(child.Text)),
                            EnumName(StateEnum, child.state), Trunc(child.Text:GetText(), 40))
                    end
                end
            end

            local title = (ns.Skin and ns.Skin.TitleFS and ns.Skin.TitleFS(block)) or block.HeaderText
            local titleDesc, titleWhy = "-", nil
            if title and title.GetFont then
                titleDesc = FontDesc(title, Role(title))
                titleWhy = FontMismatch(title, wantTitle)
            end
            local note = entry.note
            if block.HeaderText and title ~= block.HeaderText then
                note = note .. "  (styled title is not HeaderText)"
            end
            add("%s%s #%s %s  title=%s  lines=%d bad=%d  skinned %s%s",
                (blockBad > 0 or titleWhy) and "!! " or "", ShortName(tracker), Str(block.id),
                Trunc(title and title.GetText and title:GetText(), 40), titleDesc,
                #lines, blockBad, Ago(skinLast[block]), note)
            -- 全部對得上的區塊只留上面那一行，免得幾十行的「ok」把要看的那幾行淹掉
            if blockBad > 0 then
                for _, d in ipairs(details) do add("%s", d) end
            end
        end
    end)
    add("lines=%d  mismatched=%d  neverStyled=%d  orphans=%d", total, bad, never, orphans)
    ctx.lineMismatch = bad + orphans
end

local function SecEvents(add)
    for _, e in ipairs(WATCH_EVENTS) do
        add("%s: %d×  last %s", e, eventCount[e] or 0, Ago(eventLast[e]))
    end
end

local TRACKER_WORDS = { "ObjectiveTracker", "Scenario", "UIWidget", "WorldState" }

local function Mentions(s)
    if type(s) ~= "string" or IsSecret(s) then return false end
    for _, w in ipairs(TRACKER_WORDS) do
        if s:find(w, 1, true) then return true end
    end
    return false
end

local function SecErrors(add, ctx)
    if #ns.errors == 0 then
        add("own errors: none")
    else
        for i, e in ipairs(ns.errors) do add("own %d. %s", i, Trunc(e, 300)) end
    end

    if #blocked == 0 then
        add("other addons blocked: none")
    else
        for _, b in ipairs(blocked) do
            add("blocked %s ×%d  last %s", b.key, b.count, Ago(b.last))
        end
    end

    local BG = _G.BugGrabber
    if BG and BG.GetDB and BG.GetSessionId then
        local db, sid = BG:GetDB(), BG:GetSessionId()
        local total, hits = 0, {}
        for _, e in ipairs(type(db) == "table" and db or {}) do
            if type(e) == "table" and e.session == sid then
                total = total + 1
                if Mentions(e.message) or Mentions(e.stack) then hits[#hits + 1] = e end
            end
        end
        add("BugGrabber session %s: %d errors, %d mention the tracker/scenario/widgets", Str(sid), total, #hits)
        for i = math.max(1, #hits - 4), #hits do
            local e = hits[i]
            if e then
                add("  ×%s %s", Str(e.counter),
                    (type(e.message) == "string" and not IsSecret(e.message)) and Trunc(e.message, 300) or "<secret message>")
            end
        end
        ctx.errorHits = #hits
    else
        local cvar = GetCVar("scriptErrors")
        add("BugGrabber not loaded; scriptErrors=%s%s", Str(cvar),
            cvar ~= "1" and "  (Blizzard-side errors are invisible — /console scriptErrors 1)" or "")
    end
end

------------------------------------------------------------
-- 判定：三段對照之後給一句話。給玩家看的，所以走語系
------------------------------------------------------------
local function Verdict(ctx)
    local L = ns.L
    -- 場景與 widget 是**兩條獨立的路**：不在場景裡不代表 widget 那條也該是空的
    -- （追蹤器的 widget set 由伺服器指派，跟 C_Scenario 無關）。少了這一段的話，
    -- 「widget 該出來卻沒出來」會被前面的 apiScenario 閘一律判成 A
    local widgetBroken = (ctx.trackerWidgetsShown or 0) > 0 and not ctx.widgetShown
    local function WidgetVerdict()
        return "B", L["Verdict B: the game reports %d objective-tracker widget(s) shown, but Blizzard's UIWidget module is empty (state=%s, hasContents=%s). Look at the taint list and errors — re-login clearing it fits taint."]
            :format(ctx.trackerWidgetsShown or 0, tostring(ctx.widgetState), tostring(ctx.widgetContent))
    end

    -- 容器自己把自己藏掉：有模組試過、一個區塊都放不下，而且沒有任何模組排得進去。
    -- 這條路**不報錯**，而且跟場景 API 有沒有資料無關，所以排在最前面 ——
    -- 不然「整份清單消失」會被下面判成 A（不在場景）或 B（taint），兩個都是錯的方向
    if ctx.notShown and not ctx.anyDisplayable and not ctx.otfShown then
        return "D", L["Verdict D: nothing fits — %s tried to lay out but no block fit in the tracker's height (%s), so Blizzard's tracker hid itself. No error is raised on this path. The height is computed from the parent frame — see \"OTF height inputs\" in the report."]
            :format(table.concat(ctx.notShown, ", "), Str(ctx.otfHeight))
    end

    if not ctx.apiScenario then
        if widgetBroken then return WidgetVerdict() end
        -- 「人在事件裡卻判 A」要能再往下分，不然玩家只會得到一句「暴雪的問題」。
        -- 決定性的證據是**上一次收到場景事件是什麼時候** —— 用戶端連通知都沒收到，
        -- 就不可能是排版或 taint 的問題（那兩種是「資料有、畫不出來」）。
        -- 分辨方式交給玩家做一次 /reload：Lua 端的髒東西 /reload 就清掉，
        -- 用戶端資料庫的同步問題非得重登不可 —— 這一步以前一直被「重新登入就好
        -- ＝taint 指紋」的假設跳過了，其實兩者都是重登才好，分不出來
        local last = nil
        for _, e in ipairs({ "SCENARIO_UPDATE", "SCENARIO_CRITERIA_UPDATE", "SCENARIO_COMPLETED" }) do
            local t = eventLast[e]
            if t and (not last or t > last) then last = t end
        end
        return "A", L["Verdict A: the game API reports no scenario (IsInScenario=false, GetScenarioInfo=nil, %d tracker widgets shown); last scenario event %s. If you are not in the event this is expected — run /mquest debug again while the problem is on screen. If you are in the event, the client was never told: try /reload — if that fixes it the problem is Lua-side (tell us), if only a full re-login does it is a client/server sync problem (tell Blizzard)."]
            :format(ctx.trackerWidgetsShown or 0, Ago(last))
    end
    if not ctx.scenarioShown then
        if (ctx.scenarioUpdates or 0) == 0 then
            return "B", L["Verdict B: the scenario module never received an Update — the tracker's dispatch loop is broken. Look at the taint list and errors."]
        end
        return "B", L["Verdict B: the API has scenario data but Blizzard's scenario module is not displayed (state=%s, hasContents=%s). Look at the taint list and errors — re-login clearing it fits taint."]
            :format(tostring(ctx.scenarioState), tostring(ctx.scenarioContent))
    end
    if not ctx.otfVisible then
        return "C", L["Verdict C: the scenario module rendered but the tracker is hidden by this addon (folded / alpha / parent). This is our bug."]
    end
    if ctx.offscreen then
        return "C", L["Verdict C: the tracker rendered but sits off-screen. This is our position override."]
    end
    if widgetBroken then return WidgetVerdict() end
    return "OK", L["Verdict: API, module and tracker all agree it is visible. If the screen still looks wrong, take a screenshot."]
end

------------------------------------------------------------
-- 組報告
------------------------------------------------------------
function D.Report()
    local out, ctx = {}, {}
    out[#out + 1] = ("MiliUI_QuestTracker diagnostic  %s  %s"):format(ns.VERSION, date("%Y-%m-%d %H:%M:%S"))
    Section(out, "environment", SecEnv, ctx)
    Section(out, "scenario API", SecApi, ctx)
    Section(out, "tracker container", SecContainer, ctx)
    Section(out, "tracker modules", SecModules, ctx)
    Section(out, "taint", SecTaint, ctx)
    Section(out, "this addon", SecOurs, ctx)
    Section(out, "objective line fonts", SecLines, ctx)
    Section(out, "events", SecEvents, ctx)
    Section(out, "errors", SecErrors, ctx)
    local code, text = Verdict(ctx)
    out[#out + 1] = "== verdict " .. code
    out[#out + 1] = "  " .. text
    -- 判定只管「追蹤器少了一段」那三型；字型對不上是另一回事，不併進判定，
    -- 但要在這裡點出來，不然讀報告的人只看判定會以為這份跟症狀無關
    if ctx.hideMismatch then
        out[#out + 1] = "  also: the list is folded but still on screen — see \"this addon\""
    end
    if ctx.barOffscreen then
        out[#out + 1] = "  also: the title bar is shown but cannot be seen — see \"this addon\""
    end
    if (ctx.lineMismatch or 0) > 0 then
        out[#out + 1] = ("  also: %d objective line(s) don't match the font settings — see \"objective line fonts\"")
            :format(ctx.lineMismatch)
    end
    return out, code, text
end

------------------------------------------------------------
-- 報告視窗：一個可以整段選起來 Ctrl+C 的框
--
-- 印到聊天視窗的東西選不起來，玩家要一行一行截圖 —— 回報就會只剩前三行。
-- 內容是程式產生的，玩家改了沒有意義，所以一被輸入就還原（跟共用層的 CopyBox 同一招），
-- 但保留捲軸：報告有幾十行。
------------------------------------------------------------
local win
local WIN_W, WIN_H = 640, 460

local function EnsureWindow()
    if win then return win end
    local W, L = ns.W, ns.L
    if not W then return nil end

    win = W.CreateFrame("MiliUIQuestTrackerDiag", UIParent, WIN_W, WIN_H)
    win:SetFrameStrata("DIALOG")
    win:SetPoint("CENTER")
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    W.MakeDragHandle(win, win)
    W.CloseOnEscape(win)

    local title = win:CreateFontString(nil, "OVERLAY")
    title:SetFontObject(W.fontTitle)
    title:SetPoint("TOPLEFT", 12, -11)
    title:SetText(L["Diagnostic report"])

    local hint = win:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("LEFT", title, "RIGHT", 10, 0)
    hint:SetText(L["Select all, copy (Ctrl+C), and paste the whole thing to the author."])

    local box = W.CreateScrollEditBox(win, WIN_W - 24, WIN_H - 78)
    box:SetPoint("TOPLEFT", 12, -34)
    win.box = box
    box.editBox:SetScript("OnTextChanged", function(_, userInput)
        if userInput then D.RefreshWindow() end
    end)

    local selectAll = W.CreateButton(win, L["Select all"], "normal", 80, 22)
    selectAll:SetPoint("BOTTOMLEFT", 12, 12)
    selectAll:SetScript("OnClick", function()
        D.RefreshWindow()
        box.editBox:SetFocus()
        box.editBox:HighlightText()
    end)

    local close = W.CreateButton(win, L["Okay"], "normal", 80, 22)
    close:SetPoint("BOTTOMRIGHT", -12, 12)
    close:SetScript("OnClick", function() win:Hide() end)

    return win
end

function D.RefreshWindow()
    if not win then return end
    win.box.editBox:SetText(win.text or "")
    win.box.editBox:SetCursorPosition(0)
end

-- 回傳 true 表示視窗開了；沒有共用層（理論上不會）就回 false，呼叫端改印聊天
function D.ShowWindow(lines)
    local w = EnsureWindow()
    if not w then return false end
    w.text = table.concat(lines, "\n")
    D.RefreshWindow()
    w:Show()
    return true
end
