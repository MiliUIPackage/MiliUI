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

if GetDB() then
    mode = "BugGrabber DB"
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
-- 跨場次累積
--
-- 這個 bug 沒辦法當場複現（2026-09-07 實測：想叫就叫不出來），所以「按十秒 →
-- /cdprobe」那種要即時重現的測法行不通。改成自己在背景累積：每 30 秒取樣一次，
-- 登出時把「本場次數 ＋ 這一場有哪些插件沒載入」寫進 SavedVariables。
-- 你照常玩就好，不用記得下任何指令；之後 /cdprobe report 直接看
-- 「關掉 X 的那幾場有沒有再犯」。
--
-- 記「沒載入的」而不是「載入的」：跑二分法時被停用的永遠是少數，存起來便宜，
-- 而且那正是我們在變動的那個變數。
-- ⚠ LoadOnDemand 的插件（RaiderIO_DB_* 那類）沒被叫到時也會列進「沒載入」，
--   看報表時要略過它們。
----------------------------------------------------------------------
local sessionHits, sessionTotal = 0, 0

local function Accumulate()
    local h, t = Sample(true)
    if h then
        sessionHits, sessionTotal = sessionHits + h, sessionTotal + t
    end
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

local function SaveSession()
    Accumulate()
    if type(CDProbeDB) ~= "table" then CDProbeDB = {} end
    CDProbeDB.sessions = CDProbeDB.sessions or {}
    -- 沒出事的場次也要記 —— 「關掉 X 之後連續三場乾淨」正是我們要的證據
    table.insert(CDProbeDB.sessions, {
        t     = time(),
        hits  = sessionHits,
        total = sessionTotal,
        off   = table.concat(DisabledAddOns(), ","),
    })
    while #CDProbeDB.sessions > 40 do table.remove(CDProbeDB.sessions, 1) end
end

local function Report()
    local s = CDProbeDB and CDProbeDB.sessions
    if type(s) ~= "table" or #s == 0 then
        print("|cff33ff99CDProbe|r 還沒有任何場次記錄（要登出過一次才會寫入）")
        return
    end
    print("|cff33ff99CDProbe|r 場次記錄（最近 12 場，本場尚未寫入）：")
    for i = math.max(1, #s - 11), #s do
        local r = s[i]
        local off = r.off or ""
        if off == "" then off = "（全開）" end
        if #off > 90 then off = off:sub(1, 90) .. "…" end
        print(("  %s  SetCooldown |cffff4411%d|r / 全部 %d　停用：%s")
            :format(date("%m/%d %H:%M", r.t or 0), r.hits or 0, r.total or 0, off))
    end
    print(("  |cffffd200本場進行中|r  SetCooldown |cffff4411%d|r / 全部 %d　停用：%s")
        :format(sessionHits, sessionTotal, table.concat(DisabledAddOns(), ",") ~= ""
            and table.concat(DisabledAddOns(), ",") or "（全開）"))
end

----------------------------------------------------------------------
-- 讓引擎自己點名：ADDON_ACTION_BLOCKED / FORBIDDEN
--
-- SetCooldown 那條錯誤訊息不寫是誰污染的，但同一條路徑再往下走
-- （Update → UpdatePressAndHoldAction → SetAttribute）在戰鬥中會被封鎖，而封鎖事件
-- **帶插件名字**。條件：那顆按鈕當下沒有冷卻在跑（isActive=false → Clear() 不會炸），
-- Update() 才走得到 SetAttribute。戰鬥中總有這種 tick，所以只要污染存在，
-- 這裡遲早會收到「誰、擋了哪個函式」。
-- !BugGrabber 對這兩個事件是註解掉的（BugGrabber.lua:507），BugSack 裡看不到，
-- 所以自己接。
----------------------------------------------------------------------
local blocked = {}          -- "插件:函式" → 次數（本場）

local acc = CreateFrame("Frame")
acc:RegisterEvent("PLAYER_LOGOUT")
acc:RegisterEvent("ADDON_ACTION_BLOCKED")
acc:RegisterEvent("ADDON_ACTION_FORBIDDEN")
acc:SetScript("OnEvent", function(_, event, addon, func)
    if event == "PLAYER_LOGOUT" then
        SaveSession()
        return
    end
    local key = ("%s:%s%s"):format(tostring(addon), tostring(func), event == "ADDON_ACTION_FORBIDDEN" and " [forbidden]" or "")
    blocked[key] = (blocked[key] or 0) + 1
end)
C_Timer.NewTicker(30, Accumulate)

local function PrintBlocked()
    local rows = {}
    for k, n in pairs(blocked) do rows[#rows + 1] = { k = k, n = n } end
    table.sort(rows, function(a, b) return a.n > b.n end)
    if #rows == 0 then
        print("|cff33ff99CDProbe|r 本場沒有收到任何 ADDON_ACTION_BLOCKED/FORBIDDEN")
        return
    end
    print("|cff33ff99CDProbe|r 本場被封鎖的動作（引擎點名）：")
    for i = 1, math.min(#rows, 25) do
        print(("  %4d×  %s"):format(rows[i].n, rows[i].k))
    end
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

    -- 每一顆快捷列按鈕：本體、cooldown 三兄弟、輔助輸出的旋轉框
    local buttons = 0
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
                ScanTable(label .. ".AssistedCombatRotationFrame", b.AssistedCombatRotationFrame, out, seen)
                ScanTable(label .. ".AssistedCombatHighlightFrame", b.AssistedCombatHighlightFrame, out, seen)
                ScanTable(label .. ".SpellActivationAlert", b.SpellActivationAlert, out, seen)
            end
        end
    end

    -- 存進 SV，方便你直接把檔案丟給我看
    if type(CDProbeDB) ~= "table" then CDProbeDB = {} end
    CDProbeDB.lastScan = { t = time(), buttons = buttons, dirty = out }

    print(("|cff33ff99CDProbe|r scan：%d 顆按鈕、%d 個全域，髒的 |cffff4411%d|r 筆")
        :format(buttons, #PATH_GLOBALS, #out))
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
    local hits, total = Sample(true)
    if not hits then
        print("|cff33ff99CDProbe|r |cffff4411數不到|r —— 接法：" .. mode)
        return
    end
    print(("|cff33ff99CDProbe|r  SetCooldown 錯誤 |cffff4411%d|r 次　/　全部錯誤 %d 次　（接法：%s%s，已歸零）")
        :format(hits, total, mode, paused and "，⚠ BugGrabber 目前暫停中" or ""))
    PrintBlocked()
end

print(("|cff33ff99CDProbe|r 已載入，接法：|cffffd200%s|r —— 讓輔助輸出按鈕動起來，然後打 |cffffd200/cdprobe|r")
    :format(mode))
