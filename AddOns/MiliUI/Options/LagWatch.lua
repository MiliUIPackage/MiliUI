------------------------------------------------------------
-- 卡頓記錄器（飛行記錄器）
--
-- 效能監控分頁能回答「誰平常吃最多」，回答不了「剛剛那一下是誰」——
-- 尖峰與超閾值計數都是從登入起累計，登入初始化的尖峰跟剛剛的卡頓
-- 混在同一個數字裡。這裡反過來做：每幀只比較一次「上一幀花了多久」，
-- 超過門檻的瞬間才把每個插件的 LastTime（上一幀的逐插件毫秒數）抄下來
-- —— 那就是卡頓那一幀本身的帳單，事後不用開任何視窗。
--
-- 三種兇手分得開：
--   插件     LastTime 合計佔了該幀的大半 → 直接點名榜首
--   GC       插件合計很小，但 Lua 記憶體在那一幀一口氣掉了幾十 MB
--            （每幀順手記一次 collectgarbage("count")，純讀計數器、免費）
--   引擎     兩者皆無 → 讀圖、串流、shader 編譯，Lua 這側看不到的那類
--
-- 成本紀律（跟 Tab_Perf 的「分頁一關就停擺」不同，這台的意義就是常駐）：
--   沒卡頓的每一幀 = 一次乘法比較 + 一次 gcinfo 讀取，等於零；
--   卡頓的那一幀才掃 ~70 個資料夾各讀一個免費指標 —— 而那幀本來就已經卡了。
--
-- 指令：/miliui lag（看記錄）｜lag on/off｜lag <毫秒>（門檻）｜lag clear
------------------------------------------------------------
local _, ns = ...

local THRESH_DEFAULT = 250          -- 毫秒；低於這個玩家多半感覺不到「大頓」
local SUPPRESS_SEC   = 5            -- 讀取畫面/過場後的靜默期：那些「幀」動輒數秒，不是卡頓
local MAX_EVENTS     = 15
local PRINT_CD       = 30           -- 連環卡頓時聊天視窗只提示一次，記錄照收

local events = {}                   -- 新的在後面
local threshMs = THRESH_DEFAULT     -- DB 的快取：門檻比較在最熱的迴圈裡，不能每幀走 DB()
local suppressUntil = 0
local lastPrint = 0
local prevMemKB = 0
local prevDeltaKB = 0               -- 上一幀的記憶體差值，見事件成立處的註解
local metricLast                    -- Enum 解析結果，登入時定一次

local function DB()
    if not MiliUI_DB then MiliUI_DB = {} end
    local db = MiliUI_DB.perf
    if type(db) ~= "table" then db = {}; MiliUI_DB.perf = db end
    if type(db.lagWatch) ~= "boolean" then db.lagWatch = true end
    if type(db.lagMs) ~= "number" or db.lagMs < 50 or db.lagMs > 5000 then
        db.lagMs = THRESH_DEFAULT
    end
    return db
end

local function Num(ok, v)
    if not ok or type(v) ~= "number" or v ~= v or v == math.huge then return 0 end
    return v
end

-- TOC 標題比資料夾名好認，但帶著色碼與 [兩字標籤]；剝掉色碼就好，標籤留著反而好找
local function Title(folder)
    local t = C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(folder, "Title")
    t = type(t) == "string" and t or folder
    return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
end

------------------------------------------------------------
-- 捕捉：只在卡頓幀執行
------------------------------------------------------------
local function Capture(frameMs, gcDeltaKB)
    local top, addonSum = {}, 0
    for i = 1, C_AddOns.GetNumAddOns() do
        if C_AddOns.IsAddOnLoaded(i) then
            local folder = C_AddOns.GetAddOnInfo(i)
            local v = Num(pcall(C_AddOnProfiler.GetAddOnMetric, folder, metricLast))
            if v > 0 then
                addonSum = addonSum + v
                top[#top + 1] = { folder = folder, ms = v }
            end
        end
    end
    table.sort(top, function(a, b) return a.ms > b.ms end)
    while #top > 5 do table.remove(top) end

    -- overall 含暴雪自家模組，跟自己加總的差就是「暴雪側的 Lua」
    local overall = Num(pcall(C_AddOnProfiler.GetOverallMetric, metricLast))
    if overall < addonSum then overall = addonSum end

    local ev = {
        when = date("%H:%M:%S"),
        frameMs = frameMs,
        addonMs = overall,
        gcMB = gcDeltaKB < 0 and (-gcDeltaKB / 1024) or 0,
        top = top,
    }
    events[#events + 1] = ev
    while #events > MAX_EVENTS do table.remove(events, 1) end
    return ev
end

local function Verdict(ev)
    if ev.addonMs >= ev.frameMs * 0.5 and ev.top[1] then
        return ("主嫌 %s（該幀 %.0f 毫秒）"):format(Title(ev.top[1].folder), ev.top[1].ms)
    elseif ev.gcMB >= 10 then
        return ("主因像是 GC 大回收（Lua 記憶體一口氣降了 %.0f MB）"):format(ev.gcMB)
    end
    return "插件只佔少數，多半是引擎（讀圖／串流）"
end

------------------------------------------------------------
-- 守望
------------------------------------------------------------
local watcher = CreateFrame("Frame")

watcher:SetScript("OnUpdate", function(_, elapsed)
    local nowKB = collectgarbage("count")
    local gcDelta = nowKB - prevMemKB
    prevMemKB = nowKB

    local ms = elapsed * 1000
    if ms < threshMs then prevDeltaKB = gcDelta return end
    if GetTime() < suppressUntil then prevDeltaKB = gcDelta return end

    -- 回收可能落在「凍結幀的採樣點之前」，那次下跌會被記進上一幀的差值裡 ——
    -- 實測：手動 collectgarbage 收掉 100MB 的那筆事件沒掛到 GC 標籤（2026-08-29）。
    -- 事件成立時往回多看一幀，取較深的那次下跌；用完歸零，免得 5 秒凍結後的
    -- 餘震幀（連環長幀很常見）把同一筆回收重複記帳。
    if prevDeltaKB < gcDelta then gcDelta = prevDeltaKB end
    prevDeltaKB = 0

    local ev = Capture(ms, gcDelta)
    if GetTime() - lastPrint >= PRINT_CD then
        lastPrint = GetTime()
        ns.Print(("|cffff9900偵測到卡頓 %.0f 毫秒|r：插件合計 %.0f 毫秒，%s。/miliui lag 看記錄")
            :format(ev.frameMs, ev.addonMs, Verdict(ev)))
    end
end)

watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
watcher:RegisterEvent("CINEMATIC_STOP")
watcher:RegisterEvent("STOP_MOVIE")
watcher:SetScript("OnEvent", function(_, event)
    suppressUntil = GetTime() + SUPPRESS_SEC
    if event ~= "PLAYER_LOGIN" then return end
    local E = Enum and Enum.AddOnProfilerMetric
    metricLast = E and E.LastTime
    if not (metricLast and C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric) then
        watcher:Hide()          -- 分析器不在（舊客戶端/被關）：整台停擺，零成本
        return
    end
    ns.LagWatch.SetEnabled(DB().lagWatch)   -- OnUpdate 只在顯示中派送，Hide 即完全停止
end)

------------------------------------------------------------
-- 對外：/miliui lag 與效能監控分頁的勾選框共用同一組開關
------------------------------------------------------------
ns.LagWatch = {}

function ns.LagWatch.SetEnabled(on)
    local db = DB()
    db.lagWatch = on and true or false
    if db.lagWatch and metricLast then
        threshMs = db.lagMs
        prevMemKB = collectgarbage("count")   -- 關著的期間記憶體早就變了，別把那段當 GC
        prevDeltaKB = 0
        watcher:Show()
    else
        watcher:Hide()
    end
end

function ns.LagWatch.IsEnabled()
    return DB().lagWatch
end

function ns.LagWatch.GetThreshold()
    return DB().lagMs
end

function ns.LagWatch.Command(arg)
    arg = strtrim(arg or "")
    local db = DB()
    if arg == "on" then
        ns.LagWatch.SetEnabled(true)
        ns.Print("卡頓記錄器：開")
    elseif arg == "off" then
        ns.LagWatch.SetEnabled(false)
        ns.Print("卡頓記錄器：關")
    elseif arg == "clear" then
        wipe(events)
        ns.Print("卡頓記錄已清空")
    elseif tonumber(arg) then
        db.lagMs = math.max(50, math.min(5000, tonumber(arg)))
        threshMs = db.lagMs
        ns.Print(("卡頓門檻改為 %d 毫秒"):format(db.lagMs))
    else
        ns.Print(("卡頓記錄（門檻 %d 毫秒，記錄器%s）："):format(
            db.lagMs, db.lagWatch and "開啟中" or "|cffff5555已關閉|r"))
        if #events == 0 then
            print("  還沒有記錄。門檻：/miliui lag <毫秒>")
            return
        end
        for i = #events, 1, -1 do
            local ev = events[i]
            local parts = {}
            for _, t in ipairs(ev.top) do
                parts[#parts + 1] = ("%s %.0f"):format(Title(t.folder), t.ms)
            end
            print(("  %s｜%.0f 毫秒｜插件 %.0f（%s）%s"):format(
                ev.when, ev.frameMs, ev.addonMs,
                #parts > 0 and table.concat(parts, "、") or "無",
                ev.gcMB >= 10 and ("｜GC 回收 %.0f MB"):format(ev.gcMB) or ""))
        end
    end
end
