-- 臨時診斷插件：數「ActionButton 的 SetCooldown 吃到秘密值」這個錯誤
--
-- ⚠⚠ 前兩版都是錯的，教訓值得記：
--
--   -- !BugGrabber/BugGrabber.lua:526-527
--   real_seterrorhandler(grabError)
--   function seterrorhandler() end        ← 全域被換成空函式
--
-- !BugGrabber 直接把 `seterrorhandler` 變成 no-op，任何插件之後怎麼設都沒有作用。
-- 前兩版都是用 seterrorhandler 接的 ⇒ 計數器永遠 0，而「0」看起來跟「沒有錯誤」
-- 一模一樣。整個插件二分法被這個假陰性帶著跑了三輪。
--
-- 這一版不搶錯誤處理器，改成**讀 BugGrabber 自己的錯誤資料庫算差量**
-- （`BugGrabber:GetDB()` 是公開 API，錯誤物件上的 `counter` 是累計次數）。
-- 讀取不會被任何人擋掉。
--
-- /cdprobe 一定會印出接法與 BugGrabber 是否暫停。看到 mode=none 就是沒接上，
-- 數字不能信 —— 這是這支存在的唯一理由。
--
-- 2026-09-07 起隨套組發佈：這個 bug 太隨機、單機叫不出來，改請玩家幫忙收集。
-- 玩家只要在錯誤跳出來之後打 /cdprobe，把整段輸出貼回來即可；
-- 最下面「本場被封鎖的動作（引擎點名）」那段就是我們要的東西。
-- 抓到並修掉之後就把這支從套組拿掉。

local mode = "none"
local baseline = setmetatable({}, { __mode = "k" })   -- 錯誤物件 → 上次歸零時的 counter

-- 12.1：錯誤訊息本身可能是秘密字串（呼叫堆疊上有秘密值參與時），對它做 :find()
-- 會直接拋錯 —— 一定要先擋。見 .claude/notes/wow-121-secret-values.md
local issecret = issecretvalue

local function IsTarget(msg)
    if type(msg) ~= "string" then return false end
    if issecret and issecret(msg) then return false end
    return msg:find("SetCooldown", 1, true) and msg:find("Secret values", 1, true)
end

local function GetDB()
    if not (BugGrabber and BugGrabber.GetDB) then return nil end
    local ok, db = pcall(BugGrabber.GetDB, BugGrabber)
    if ok and type(db) == "table" then return db end
    return nil
end

-- 走訪錯誤物件：不假設是純陣列，只認「有 message 欄位的 table」
local function Each(db, fn)
    for _, e in pairs(db) do
        if type(e) == "table" and e.message ~= nil then fn(e) end
    end
end

local function Sample(reset)
    local db = GetDB()
    if not db then return nil end
    local hits, total = 0, 0
    Each(db, function(e)
        local c = tonumber(e.counter) or 0
        local delta = c - (baseline[e] or 0)
        if delta > 0 then
            total = total + delta
            if IsTarget(e.message) then hits = hits + delta end
        end
        if reset then baseline[e] = c end
    end)
    return hits, total
end

----------------------------------------------------------------------
-- 拆掉 !BugGrabber 的洗版保護
--
--   -- !BugGrabber/BugGrabber.lua:40, 212-226
--   BUGGRABBER_ERRORS_PER_SEC_BEFORE_THROTTLE = 10
--   function grabError(errorMessage, isSimple)
--       msgsAllowed = msgsAllowed + dt * BUGGRABBER_ERRORS_PER_SEC_BEFORE_THROTTLE
--       if msgsAllowed < 1 then paused=true; return end   ← 超過 10/秒直接丟掉
--
-- SetCooldown 那條是每個 tick 都炸，永遠超過 10/秒 ⇒ BugGrabber 自己暫停、把風暴
-- 整批丟掉、風暴過了再恢復。BugSack 裡看起來「沒幾筆」，這支讀它資料庫算差量的
-- 探針也跟著瞎（2026-09-07 17:04 實測：遊戲洗「太多錯誤」的同時探針印 0 次）。
-- 門檻是全域、grabError 每次即時讀，載入後調高就生效。同一則訊息在資料庫裡只合併成
-- 一筆累加 counter，不會撐爆存檔（它另有 MAX_BUGGRABBER_ERRORS=500 筆上限）。
-- 代價是風暴期間 BugGrabber 每筆都做 debugstack——診斷期間可以接受。
----------------------------------------------------------------------
local THROTTLE_WANT = 200
local throttleNote = ""
if type(BUGGRABBER_ERRORS_PER_SEC_BEFORE_THROTTLE) == "number" then
    local was = BUGGRABBER_ERRORS_PER_SEC_BEFORE_THROTTLE
    if was < THROTTLE_WANT then
        BUGGRABBER_ERRORS_PER_SEC_BEFORE_THROTTLE = THROTTLE_WANT
        throttleNote = ("，洗版門檻 %d→%d/秒"):format(was, THROTTLE_WANT)
    end
end

if GetDB() then
    mode = "BugGrabber DB" .. throttleNote
    Sample(true)          -- 以現在為基準，之前累積的不算
else
    -- 沒有 BugGrabber 才自己接，而且**要驗證真的接到了**
    local hits, total = 0, 0
    local orig = geterrorhandler()
    local mine
    mine = function(err, ...)
        total = total + 1
        if IsTarget(err) then hits = hits + 1 end
        return orig(err, ...)
    end
    seterrorhandler(mine)
    if geterrorhandler() == mine then
        mode = "seterrorhandler"
        Sample = function(reset)
            local h, t = hits, total
            if reset then hits, total = 0, 0 end
            return h, t
        end
    else
        mode = "none（seterrorhandler 被霸佔且沒有 BugGrabber ⇒ 數不到）"
        Sample = function() return nil end
    end
end

----------------------------------------------------------------------
-- 自動開 taintLog
--
-- taintLog 是**不存檔**的除錯 CVar —— Config.wtf 裡根本沒有這一條，每次啟動
-- 客戶端都回到 0。所以要嘛每次登入手動打 /console taintLog 2，要嘛像這裡由
-- 插件在載入時補上。log 寫到 World of Warcraft/_retail_/Logs/taint.log。
--
-- ⚠ 三個會騙人的地方：
--
--   1. **設完一定要讀回來驗證。** SetCVar 對除錯類 CVar 不保證吃，而且失敗是
--      靜默的 —— 跟這支插件前兩版 seterrorhandler 的假陰性同一種病。驗不過就
--      退到 ConsoleExec（等同 /console）再驗一次，兩條都不過就明講「沒開成」。
--   2. **開了不等於抓得到。** taintLog 只從打開的那一刻開始記；插件載入期的污染
--      要等下一次 /reload 那一輪才會進 log。/reload 不重開客戶端，CVar 會留著，
--      所以「登入時自動開 → /reload → 重現問題」才是完整的一輪。
--   3. **執行層級的污染 taintLog 是瞎的**（.claude/notes/wow-121-addon-code-in-secure-stack.md）。
--      log 裡乾乾淨淨不代表沒有污染，12.1 那種「自己的 Lua 跑在暴雪 secure 堆疊裡」
--      不會留下對應的行。
----------------------------------------------------------------------
local TAINT_LEVEL = "2"

local function TaintLevel()
    local v = GetCVar and GetCVar("taintLog")
    return v and tostring(v) or "?"
end

-- 回傳 是否開成, 用哪條路成功（或失敗時現在的值）
local function EnableTaintLog()
    if TaintLevel() == TAINT_LEVEL then return true, "本來就開著" end
    pcall(SetCVar, "taintLog", TAINT_LEVEL)
    if TaintLevel() == TAINT_LEVEL then return true, "SetCVar" end
    -- SetCVar 不吃就走主控台這條（等同玩家自己打 /console taintLog 2）
    pcall(ConsoleExec, "taintLog " .. TAINT_LEVEL)
    if TaintLevel() == TAINT_LEVEL then return true, "ConsoleExec" end
    return false, TaintLevel()
end

-- 載入這一刻的值：已經是 2 就代表這一輪的插件載入期也有記到（/reload 過來的）
local taintWasOn = (TaintLevel() == TAINT_LEVEL)

local function ReportTaint()
    local ok, how = EnableTaintLog()
    if not ok then
        print(("|cff33ff99CDProbe|r taintLog |cffff4411沒開成|r（現在是 %s）—— 自己打一次 |cffffd200/console taintLog %s|r")
            :format(how, TAINT_LEVEL))
        return
    end
    if taintWasOn then
        print(("|cff33ff99CDProbe|r taintLog=|cffffd200%s|r（%s）—— 這一輪**含插件載入期**都有記，Logs/taint.log")
            :format(TAINT_LEVEL, how))
    else
        print(("|cff33ff99CDProbe|r taintLog=|cffffd200%s|r（%s）—— 從現在開始記；要連載入期一起抓就 |cffffd200/reload|r 再重現一次")
            :format(TAINT_LEVEL, how))
    end
end

-- ⚠ 2026-09-07：**不再自動開**。
-- 對「SetCooldown 吃到秘密值」這條，taintLog 已經證明是瞎的——完整登出 flush 的
-- 一份裡 ActionBar／AssistedCombat／Cooldown 相關 0 筆、被封鎖的動作 0 筆，因為
-- 執行層級的污染沒有變數參與、不會留下行（見
-- .claude/notes/wow-121-addon-code-in-secure-stack.md 的「診斷」那節）。
-- 而代價是每場 20MB 的 log。要追**變數層級**的污染時再自己開：/cdprobe taint on

----------------------------------------------------------------------
-- 跨場次累積 ＋ 場次記錄（SavedVariables）
--
-- 這個 bug 沒辦法當場複現（2026-09-07 實測：想叫就叫不出來），所以「按十秒 →
-- /cdprobe」那種要即時重現的測法行不通。改成自己在背景累積，你照常玩就好。
--
-- 存法（2026-09-07 使用者要求：不小心 /reload 也不能掉資料）：
--   · 每 30 秒把「進行中的這一場」整包寫進 CDProbeDB.current ——
--     計數、被封鎖的動作、最後一次掃描、哪些插件沒載入。遊戲當掉也留得住。
--   · /reload 或登出（都會發 PLAYER_LOGOUT）時把 current 搬進 sessions。
--   · 載入時發現殘留的 current，代表上一場沒正常結束，標成 crashed 收進去。
--   · /cdprobe ui 開視窗把所有場次倒成文字、自動全選，Ctrl+C 就能整段貼回來。
--
-- 記「沒載入的」而不是「載入的」：跑二分法時被停用的永遠是少數，存起來便宜，
-- 而且那正是我們在變動的那個變數。
-- ⚠ LoadOnDemand 的插件（RaiderIO_DB_* 那類）沒被叫到時也會列進「沒載入」，
--   看報表時要略過它們。
----------------------------------------------------------------------
local sessionStart = time()
local sessionHits, sessionTotal = 0, 0
local blocked = {}          -- "插件:框:函式()" → 次數（本場）
local sessionScan = nil     -- 本場最後一次 /cdprobe scan

local MAX_SESSIONS = 40

local function EnsureDB()
    if type(CDProbeDB) ~= "table" then CDProbeDB = {} end
    if type(CDProbeDB.sessions) ~= "table" then CDProbeDB.sessions = {} end
    return CDProbeDB
end

local function DisabledAddOns()
    local off = {}
    local n = (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns()) or 0
    for i = 1, n do
        local name = C_AddOns.GetAddOnInfo(i)
        if name and name ~= "_CDProbe" and not C_AddOns.IsAddOnLoaded(name) then
            off[#off + 1] = name
        end
    end
    table.sort(off)
    return off
end

-- 被封鎖的動作，多的排前面，輸出成 "次數× 插件:框:函式()" 的字串陣列
local function BlockedRows(limit)
    local rows = {}
    for k, n in pairs(blocked) do rows[#rows + 1] = { k = k, n = n } end
    table.sort(rows, function(a, b) return a.n > b.n end)
    local out = {}
    for i = 1, math.min(#rows, limit or 40) do
        out[i] = ("%d× %s"):format(rows[i].n, rows[i].k)
    end
    return out
end

local function Snapshot(ended)
    return {
        t = sessionStart, tEnd = time(), ended = ended or nil,
        hits = sessionHits, total = sessionTotal,
        off = table.concat(DisabledAddOns(), ","),
        blocked = BlockedRows(40),
        scan = sessionScan,
    }
end

local function Accumulate()
    local h, t = Sample(true)
    if h then
        sessionHits, sessionTotal = sessionHits + h, sessionTotal + t
    end
    EnsureDB().current = Snapshot()      -- 進行中的這一場：當掉也留得住
end

local function TrimSessions(db)
    while #db.sessions > MAX_SESSIONS do table.remove(db.sessions, 1) end
end

local function SaveSession()
    Accumulate()
    local db = EnsureDB()
    -- 沒出事的場次也要記 —— 「關掉 X 之後連續三場乾淨」正是我們要的證據
    table.insert(db.sessions, Snapshot(true))
    db.current = nil
    TrimSessions(db)
end

-- 上一場沒正常結束（當掉／強制關閉）：殘留的 current 收進 sessions。
-- 要等 SavedVariables 載進來（ADDON_LOADED）才看得到，檔案執行期 CDProbeDB 還是 nil。
local function RecoverCrashed()
    local db = EnsureDB()
    if type(db.current) == "table" then
        db.current.crashed = true
        table.insert(db.sessions, db.current)
        db.current = nil
        TrimSessions(db)
    end
end

----------------------------------------------------------------------
-- 報表文字：視窗與 /cdprobe report 共用
----------------------------------------------------------------------
-- 掃描結果裡暴雪不會讀的插件私有欄位，報表裡濾掉（原始清單還在 SV）
local SCAN_NOISE = { "%._MSQ_", "_MasqueBlizzBarsSkinned", "cdmViewerNameChecked" }

local function IsScanNoise(s)
    for _, p in ipairs(SCAN_NOISE) do
        if s:find(p) then return true end
    end
    return false
end

local function FormatSession(r, label)
    local L = {}
    local when = date("%m/%d %H:%M", r.t or 0)
    if r.tEnd then when = when .. "–" .. date("%H:%M", r.tEnd) end
    L[#L + 1] = ("== %s %s%s"):format(label or "場次", when, r.crashed and "（未正常結束）" or "")
    L[#L + 1] = ("SetCooldown %d 次 / 全部錯誤 %d 次"):format(r.hits or 0, r.total or 0)
    local off = r.off or ""
    L[#L + 1] = "停用的插件：" .. (off ~= "" and off or "（全開）")
    if type(r.blocked) == "table" and #r.blocked > 0 then
        L[#L + 1] = "被封鎖的動作（引擎點名）："
        for _, s in ipairs(r.blocked) do L[#L + 1] = "  " .. s end
    else
        L[#L + 1] = "被封鎖的動作：無"
    end
    local sc = r.scan
    if type(sc) == "table" then
        local dirty = sc.dirty or {}
        L[#L + 1] = ("scan %s：%d 顆按鈕、旋轉框 %d 個、髒 %d 筆（下面已濾掉插件私有欄位）")
            :format(date("%H:%M", sc.t or 0), sc.buttons or 0, sc.rotationFrames or 0, #dirty)
        local shown = 0
        for _, s in ipairs(dirty) do
            if not IsScanNoise(s) then
                L[#L + 1] = "  " .. s
                shown = shown + 1
                if shown >= 60 then L[#L + 1] = "  …"; break end
            end
        end
        if shown == 0 then L[#L + 1] = "  （濾掉私有欄位後沒有髒的）" end
    end
    return table.concat(L, "\n")
end

local function BuildReportText()
    local db = EnsureDB()
    local parts = { ("CDProbe 記錄　接法：%s　taintLog=%s"):format(mode, TaintLevel()) }
    parts[#parts + 1] = FormatSession(Snapshot(), "本場進行中")
    for i = #db.sessions, math.max(1, #db.sessions - 11), -1 do
        parts[#parts + 1] = FormatSession(db.sessions[i])
    end
    if #db.sessions == 0 then parts[#parts + 1] = "（還沒有已結束的場次）" end
    return table.concat(parts, "\n\n")
end

local function Report()
    local db = EnsureDB()
    print("|cff33ff99CDProbe|r 場次記錄（最近 12 場；完整內容用 /cdprobe ui）：")
    for i = math.max(1, #db.sessions - 11), #db.sessions do
        local r = db.sessions[i]
        local off = r.off or ""
        if off == "" then off = "（全開）" end
        if #off > 90 then off = off:sub(1, 90) .. "…" end
        print(("  %s  SetCooldown |cffff4411%d|r / 全部 %d　封鎖 %d 種　停用：%s")
            :format(date("%m/%d %H:%M", r.t or 0), r.hits or 0, r.total or 0,
                type(r.blocked) == "table" and #r.blocked or 0, off))
    end
    local cur = Snapshot()
    print(("  |cffffd200本場進行中|r  SetCooldown |cffff4411%d|r / 全部 %d　封鎖 %d 種")
        :format(cur.hits, cur.total, #cur.blocked))
end

----------------------------------------------------------------------
-- 讓引擎自己點名：ADDON_ACTION_BLOCKED / FORBIDDEN
--
-- SetCooldown 那條錯誤訊息不寫是誰污染的，但同一條路徑再往下走
-- （Update → UpdatePressAndHoldAction → SetAttribute、UpdateAction →
-- UpdateShownButtons → SetShown）在戰鬥中會被封鎖，而封鎖事件**帶插件名字**。
-- 2026-09-07 就是靠這個點到 MiliUI_InfoBar 的。
-- !BugGrabber 對這兩個事件是註解掉的（BugGrabber.lua:507），BugSack 裡看不到，
-- 所以自己接。
----------------------------------------------------------------------
local acc = CreateFrame("Frame")
acc:RegisterEvent("ADDON_LOADED")
acc:RegisterEvent("PLAYER_LOGOUT")
acc:RegisterEvent("ADDON_ACTION_BLOCKED")
acc:RegisterEvent("ADDON_ACTION_FORBIDDEN")
acc:SetScript("OnEvent", function(self, event, addon, func)
    if event == "ADDON_LOADED" then
        if addon == "_CDProbe" then
            self:UnregisterEvent("ADDON_LOADED")
            RecoverCrashed()
        end
        return
    elseif event == "PLAYER_LOGOUT" then
        SaveSession()
        return
    end
    local key = ("%s:%s%s"):format(tostring(addon), tostring(func),
        event == "ADDON_ACTION_FORBIDDEN" and " [forbidden]" or "")
    blocked[key] = (blocked[key] or 0) + 1
end)
C_Timer.NewTicker(30, Accumulate)

local function PrintBlocked()
    local rows = BlockedRows(25)
    if #rows == 0 then
        print("|cff33ff99CDProbe|r 本場沒有收到任何 ADDON_ACTION_BLOCKED/FORBIDDEN")
        return
    end
    print("|cff33ff99CDProbe|r 本場被封鎖的動作（引擎點名）：")
    for _, s in ipairs(rows) do print("  " .. s) end
end

----------------------------------------------------------------------
-- /cdprobe ui：把記錄倒成文字的視窗，開啟時自動全選
----------------------------------------------------------------------
local win

local function ShowUI()
    if not win then
        win = CreateFrame("Frame", "CDProbeWindow", UIParent, "BasicFrameTemplateWithInset")
        win:SetSize(720, 540)
        win:SetPoint("CENTER")
        win:SetFrameStrata("DIALOG")
        win:SetMovable(true)
        win:EnableMouse(true)
        win:RegisterForDrag("LeftButton")
        win:SetScript("OnDragStart", win.StartMoving)
        win:SetScript("OnDragStop", win.StopMovingOrSizing)
        local title = win.TitleText or (win.TitleContainer and win.TitleContainer.TitleText)
        if title then title:SetText("CDProbe 記錄 —— 已全選，Ctrl+C 複製後整段貼給米利") end
        tinsert(UISpecialFrames, "CDProbeWindow")     -- Esc 關閉

        local scroll = CreateFrame("ScrollFrame", nil, win, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", win.Inset or win, "TOPLEFT", 8, -8)
        scroll:SetPoint("BOTTOMRIGHT", win.Inset or win, "BOTTOMRIGHT", -28, 34)

        local box = CreateFrame("EditBox", nil, scroll)
        box:SetMultiLine(true)
        box:SetAutoFocus(false)
        box:SetFontObject(ChatFontNormal)
        box:SetWidth(660)
        box:SetScript("OnEscapePressed", function() win:Hide() end)
        scroll:SetScrollChild(box)
        win.box = box

        local refresh = CreateFrame("Button", nil, win, "UIPanelButtonTemplate")
        refresh:SetSize(100, 22)
        refresh:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -10, 8)
        refresh:SetText("重新整理")
        refresh:SetScript("OnClick", function() win:Refresh() end)

        local hint = win:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        hint:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 12, 12)
        hint:SetText("本場的記錄每 30 秒自動存檔；/reload 與登出會結算成一場")

        function win:Refresh()
            Accumulate()
            box:SetText(BuildReportText())
            box:SetCursorPosition(0)
            box:HighlightText()
            box:SetFocus()
        end
    end
    win:Show()
    win:Refresh()
end

----------------------------------------------------------------------
-- /cdprobe scan —— 用 issecurevariable 掃「這次那條堆疊」在 SetCooldown 之前
-- 會讀到的每一張表的每一個 key
--
-- 路徑（2026-09-07 的堆疊）：
--   ActionBarButtonAssistedCombatRotationFrame:OnUpdate
--   → button:OnActionBarSlotChanged → ClearNewActionHighlight（ACTION_HIGHLIGHT_MARKS）
--   → UpdateAction（Range/UsableWatcher 兩顆管理框的 .actions、AssistedCombatManager）
--   → Update（ActionBarActionEventsFrame.frames、UpdateState/UpdateUsable/…）
--   → ActionButton_UpdateCooldown → SetCooldown ✗
--
-- 為什麼掃「每個 key」而不是挑欄位：8/30 我只挑了七個欄位掃，結果漏掉。
-- 變數污染是**永久的**，所以不需要 bug 當下發作，隨時掃都有效；掃到髒的就直接
-- 印出「表.key ← 插件」，一次點名。過度涵蓋沒關係——`_MSQ_*` 這類插件私有欄位
-- 暴雪不會讀，看到了用名字濾掉即可。**全部乾淨**才代表是執行層級的污染。
----------------------------------------------------------------------
local function ScanTable(label, t, out, seen)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    for k in pairs(t) do
        local ok, secure, who = pcall(issecurevariable, t, k)
        if ok and not secure then
            local ks = type(k) == "table" and (k.GetDebugName and k:GetDebugName() or tostring(k)) or tostring(k)
            out[#out + 1] = ("%s.%s ← %s"):format(label, ks, tostring(who))
        end
    end
end

local function ScanGlobal(name, out)
    local ok, secure, who = pcall(issecurevariable, name)
    if ok and not secure then
        out[#out + 1] = ("_G.%s ← %s"):format(name, tostring(who))
    end
end

local BAR_PREFIXES = {
    "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
    "MultiBarLeftButton", "MultiBarRightButton", "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
}

local PATH_GLOBALS = {
    -- OnActionBarSlotChanged / UpdateAction / Update 沿路直接讀的全域
    "ClearNewActionHighlight", "ACTION_HIGHLIGHT_MARKS", "ON_BAR_HIGHLIGHT_MARKS", "GetActionInfo",
    "ActionBarButtonRangeCheckFrame", "ActionBarButtonUsableWatcherFrame", "ActionBarActionEventsFrame",
    "ActionBarButtonEventsFrame", "ActionBarButtonUpdateFrame",
    "AssistedCombatManager", "ActionButtonSpellAlertManager",
    "ActionButton_UpdateCooldown", "ActionButton_ApplyCooldown", "ClearActionButtonCooldowns",
    "C_ActionBar", "C_Spell", "C_LevelLink", "GameRulesUtil", "TextureKitConstants", "Enum",
    "EventRegistry", "CVarCallbackRegistry", "GameTooltip",
    "pairs", "ipairs", "tonumber", "select", "assertsafe", "CreateFrame", "Mixin",
    -- mixin 表本體（按鈕上的方法是從這裡複製的；改到這裡等於改到每顆按鈕）
    "ActionBarActionButtonMixin", "ActionBarButtonAssistedCombatRotationFrameMixin",
    "ActionBarButtonEventsFrameMixin", "ActionBarActionEventsFrameMixin",
    -- 2026-09-07 18:42 taint.log 抓到 ON_BAR_HIGHLIGHT_MARKS 被 MiliUI_InfoBar 寫髒，
    -- 寫它的是天賦／法術書視窗（滑過天賦按鈕 → ShowActionBarHighlights）。
    -- 天賦 UI 是隨需載入的 Blizzard_PlayerSpells；在插件的執行流程裡被載入的話，
    -- 整個模組的 closure 都帶那支插件的 taint。下面這幾個能直接點名是誰載的。
    "PlayerSpellsFrame", "PlayerSpellsUtil", "PlayerSpellsFrame_LoadUI", "ClassTalentFrame",
    "SpellBookFrame", "PlayerSpellsMicroButton",
    "ActionBarController_UpdateAllSpellHighlights",
    "UpdateOnBarHighlightMarksBySpell", "UpdateOnBarHighlightMarksByFlyout", "ClearOnBarHighlightMarks",
    "MarkNewActionHighlight", "ActionButton_ShowOverlayGlow",
}

local function Scan()
    local out, seen = {}, {}
    for _, g in ipairs(PATH_GLOBALS) do ScanGlobal(g, out) end

    ScanTable("ACTION_HIGHLIGHT_MARKS", ACTION_HIGHLIGHT_MARKS, out, seen)
    ScanTable("ON_BAR_HIGHLIGHT_MARKS", ON_BAR_HIGHLIGHT_MARKS, out, seen)
    ScanTable("AssistedCombatManager", AssistedCombatManager, out, seen)
    if AssistedCombatManager then
        ScanTable("AssistedCombatManager.assistedHighlightCandidateActionButtons",
            AssistedCombatManager.assistedHighlightCandidateActionButtons, out, seen)
    end
    ScanTable("ActionButtonSpellAlertManager", ActionButtonSpellAlertManager, out, seen)
    if ActionButtonSpellAlertManager then
        ScanTable("ActionButtonSpellAlertManager.activeAlerts", ActionButtonSpellAlertManager.activeAlerts, out, seen)
    end
    for _, name in ipairs({ "ActionBarButtonRangeCheckFrame", "ActionBarButtonUsableWatcherFrame",
                            "ActionBarActionEventsFrame", "ActionBarButtonEventsFrame", "ActionBarButtonUpdateFrame" }) do
        local f = _G[name]
        ScanTable(name, f, out, seen)
        if type(f) == "table" then
            ScanTable(name .. ".actions", f.actions, out, seen)
            -- .actions 是兩層：actions[action][frame] = frame。被污染的 key 通常在第二層
            -- （某支插件在 tainted 執行裡讓一顆按鈕走了 RegisterActionBarButtonCheckFrames）
            if type(f.actions) == "table" then
                for action, sub in pairs(f.actions) do
                    ScanTable(("%s.actions[%s]"):format(name, tostring(action)), sub, out, seen)
                end
            end
            ScanTable(name .. ".frames", f.frames, out, seen)
        end
    end
    ScanTable("ActionBarActionButtonMixin", ActionBarActionButtonMixin, out, seen)
    ScanTable("ActionBarButtonAssistedCombatRotationFrameMixin", ActionBarButtonAssistedCombatRotationFrameMixin, out, seen)

    -- 編輯模式的登記表：每次套版面都會 pairs() 走一遍，裡面有一筆髒的就整趟髒
    -- （包含所有快捷列的 UpdateShownButtons）。這張表比 UIParent 內縮更早就存在。
    ScanTable("EditModeManagerFrame", EditModeManagerFrame, out, seen)
    if type(EditModeManagerFrame) == "table" then
        ScanTable("EditModeManagerFrame.registeredSystemFrames", EditModeManagerFrame.registeredSystemFrames, out, seen)
        ScanTable("EditModeManagerFrame.layoutInfo", EditModeManagerFrame.layoutInfo, out, seen)
        ScanTable("EditModeManagerFrame.layoutApplyInProgress", EditModeManagerFrame.layoutApplyInProgress, out, seen)
    end

    -- 每一顆快捷列按鈕：本體、cooldown 三兄弟、輔助輸出的旋轉框
    --
    -- ⚠ 旋轉框是「輔助輸出技能在快捷列上」時才由 UpdateAssistedCombatRotationFrame
    -- 用 CreateFrame 建出來的。如果建它的那次 UpdateAction 跑在被污染的執行流程裡，
    -- 框連同 mixin 方法都帶 taint、之後每個 tick 都髒——這正是「隨機出現、出現後
    -- 就一直在、其他掃描全乾淨」的形狀。所以要在技能在快捷列上的時候掃，
    -- 而且下面會印出到底掃到幾個旋轉框；0 個代表這次掃描證明不了這件事。
    local buttons, rotationFrames = 0, 0
    for _, prefix in ipairs(BAR_PREFIXES) do
        for i = 1, 12 do
            local b = _G[prefix .. i]
            if type(b) == "table" then
                buttons = buttons + 1
                local label = prefix .. i
                ScanTable(label, b, out, seen)
                ScanTable(label .. ".cooldown", b.cooldown, out, seen)
                ScanTable(label .. ".chargeCooldown", b.chargeCooldown, out, seen)
                ScanTable(label .. ".lossOfControlCooldown", b.lossOfControlCooldown, out, seen)
                local rf = b.AssistedCombatRotationFrame
                if type(rf) == "table" then
                    rotationFrames = rotationFrames + 1
                    ScanTable(label .. ".AssistedCombatRotationFrame", rf, out, seen)
                    ScanTable(label .. ".AssistedCombatRotationFrame.SpellActivationAlert", rf.SpellActivationAlert, out, seen)
                end
                ScanTable(label .. ".AssistedCombatHighlightFrame", b.AssistedCombatHighlightFrame, out, seen)
                ScanTable(label .. ".SpellActivationAlert", b.SpellActivationAlert, out, seen)
            end
        end
    end

    -- 記進本場記錄（Accumulate 會立刻寫進 SV 的 current），也留一份 lastScan
    sessionScan = { t = time(), buttons = buttons, rotationFrames = rotationFrames, dirty = out }
    EnsureDB().lastScan = sessionScan
    Accumulate()

    print(("|cff33ff99CDProbe|r scan：%d 顆按鈕、%d 個全域、旋轉框 |cffffd200%d|r 個，髒的 |cffff4411%d|r 筆")
        :format(buttons, #PATH_GLOBALS, rotationFrames, #out))
    if rotationFrames == 0 then
        print("  ⚠ 沒掃到任何輔助輸出的旋轉框——把輔助輸出技能放上快捷列再掃一次，否則這次掃描對 SetCooldown 那條沒有證明力")
    end
    for i = 1, math.min(#out, 40) do print("  " .. out[i]) end
    if #out > 40 then print(("  …還有 %d 筆，完整清單在 SavedVariables 的 CDProbeDB.lastScan"):format(#out - 40)) end
    if #out == 0 then
        print("  全部乾淨 ⇒ 不是變數層級的污染，是執行層級的（有人的 Lua 直接跑在那條 OnUpdate 鏈裡）")
    end
end

SLASH_CDPROBE1 = "/cdprobe"
SlashCmdList.CDPROBE = function(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "scan" then
        Scan()
        return
    elseif msg == "ui" then
        ShowUI()
        return
    elseif msg == "report" then
        Report()
        return
    elseif msg == "taint" then
        print("|cff33ff99CDProbe|r taintLog=" .. TaintLevel() .. "（on / off 切換）")
        return
    elseif msg == "taint on" then
        ReportTaint()
        return
    elseif msg == "taint off" then
        pcall(SetCVar, "taintLog", "0")
        if TaintLevel() ~= "0" then pcall(ConsoleExec, "taintLog 0") end
        print("|cff33ff99CDProbe|r taintLog=" .. TaintLevel())
        return
    end
    local paused = BugGrabber and BugGrabber.IsPaused and select(2, pcall(BugGrabber.IsPaused, BugGrabber))
    if not Sample(false) then
        print("|cff33ff99CDProbe|r |cffff4411數不到|r —— 接法：" .. mode)
        return
    end
    -- 本場累計，不歸零：手動查看不該影響背景累積，也才跟存檔裡的數字一致
    Accumulate()
    print(("|cff33ff99CDProbe|r  本場 SetCooldown 錯誤 |cffff4411%d|r 次　/　全部錯誤 %d 次　（接法：%s%s）")
        :format(sessionHits, sessionTotal, mode,
            paused and "，⚠ BugGrabber 洗版保護觸發中：這段時間的錯誤被它丟掉了，上面的數字偏低" or ""))
    PrintBlocked()
    print("|cff33ff99CDProbe|r 要貼給米利的話打 |cffffd200/cdprobe ui|r，開視窗會自動全選")
end

print(("|cff33ff99CDProbe|r 已載入，接法：|cffffd200%s|r —— 錯誤跳出來之後打 |cffffd200/cdprobe ui|r，複製整段貼給米利")
    :format(mode))
