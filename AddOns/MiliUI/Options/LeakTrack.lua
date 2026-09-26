------------------------------------------------------------
-- 洩漏追蹤（效能監控 › 記憶體頁的開關）
--
-- HeapTrack 回答「有沒有在長」，這支回答「是誰在長、做什麼的時候長」。
--
-- 核心難題：分插件的數字要在**回收完**的堆上量才有意義，否則浮動垃圾混進來，
-- 誰配置得快誰就像在洩漏。可是手動 collectgarbage("collect") 在 800MB 的堆上
-- 是半秒的凍結，不能定時跑。所以只撿三種「本來就乾淨或本來就看不見」的時機：
--
--   gc     GC 自己跑完一輪：每秒讀一次 count（免費），看到大幅下降後又開始回升
--          ＝那一輪剛收完，當下的堆最接近活資料。只差回收期間新配置的零頭。
--   load   讀取畫面：強制完整回收，凍結藏在讀取畫面裡。
--   afk    暫離旗標亮起：同上，人不在電腦前。
--
-- 每個快照記總量、每個插件資料夾的 KB、兩次快照之間發生過的事（戰鬥、拍賣場、
-- 換區域…）。比對全自動：對每個數列做最小平方斜率（MB／小時），再把成長最多的
-- 區間跟當時的事件對起來。結果畫在記憶體頁，也存在 SavedVariables 讓事後可讀。
--
-- 成本：每秒一次 count 讀取＋比較；快照時一次 UpdateAddOnMemoryUsage（~90ms，
-- 全堆掃描），最短間隔 GAP_GC 秒、戰鬥中不拍。關著時連計時器都不存在。
--
-- ⚠ 不是常駐功能：預設關，開著會讓讀取畫面變長一點（強制回收）。
------------------------------------------------------------
local _, ns = ...

local GAP_GC       = 180        -- 兩次 gc 快照的最短間隔（秒）
local GAP_FORCED   = 60         -- load／afk 快照的最短間隔（傳送連環讀圖）
local DROP_MIN_KB  = 16 * 1024  -- 下降超過這麼多才算「GC 在收」
local DROP_FRAC    = 0.03       -- 或堆的 3%，取大者
local RISE_KB      = 2 * 1024   -- 從谷底回升這麼多＝這一輪收完了
local MIN_SNAPS    = 4          -- 少於這麼多個快照不下結論
local MIN_SPAN_MIN = 15
local MAX_SNAPS    = 240        -- 每次登入最多留幾個（3 分鐘一個＝12 小時）
local MAX_SESSIONS = 4
local LEAK_MBH     = 30         -- 每小時超過這個才叫成長

local LT = {}
ns.LeakTrack = LT

-- 兩次快照之間要記的事件。值是顯示名稱；區域另外記
local MARKS = {
    PLAYER_REGEN_DISABLED  = "戰鬥",
    ENCOUNTER_START        = "首領戰",
    CHALLENGE_MODE_START   = "傳奇鑰石",
    AUCTION_HOUSE_SHOW     = "拍賣場",
    BANKFRAME_OPENED       = "銀行",
    MAIL_SHOW              = "郵件",
    MERCHANT_SHOW          = "商人",
    TRADE_SKILL_SHOW       = "專業",
    LOADING_SCREEN_ENABLED = "讀取畫面",
    GROUP_JOINED           = "加入隊伍",
}

local ticker
local session                   -- 本次登入的記錄（SV 裡那張表的參照）
local folderIdx = {}            -- folder -> session.folders 的索引
local pending = {}              -- 本區間累積的事件 label -> 次數
local peakKB, dropping, valleyKB = 0, false, nil
local lastSnapAt = 0            -- GetTime()
local cache                     -- Analyze 的結果快取，有新快照才重算

local function DB()
    if not MiliUI_DB then MiliUI_DB = {} end
    local perf = MiliUI_DB.perf
    if type(perf) ~= "table" then perf = {}; MiliUI_DB.perf = perf end
    local db = perf.leak
    if type(db) ~= "table" then db = {}; perf.leak = db end
    if type(db.on) ~= "boolean" then db.on = false end
    if type(db.sessions) ~= "table" then db.sessions = {} end
    return db
end

local function Num(ok, v)
    if not ok or type(v) ~= "number" or v ~= v or v == math.huge then return 0 end
    return v
end

function LT.Title(folder)
    local t = C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(folder, "Title")
    t = type(t) == "string" and t or folder
    return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
end

------------------------------------------------------------
-- 快照
------------------------------------------------------------
local function EnsureSession()
    if session then return session end
    local db = DB()
    session = {
        start = time(),
        char = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?"),
        folders = {},           -- 資料夾名稱，快照的 m 陣列照這個順序
        snaps = {},
    }
    table.insert(db.sessions, session)
    while #db.sessions > MAX_SESSIONS do table.remove(db.sessions, 1) end
    wipe(folderIdx)
    return session
end

local function Snapshot(kind, forceCollect)
    if InCombatLockdown() then return end
    if type(UpdateAddOnMemoryUsage) ~= "function" then return end
    local s = EnsureSession()

    -- 強制回收與全堆掃描都是看得見的一頓，別讓卡頓記錄器把它當嫌犯廣播
    if ns.LagWatch and ns.LagWatch.Suppress then ns.LagWatch.Suppress(3) end
    if forceCollect then collectgarbage("collect") end
    UpdateAddOnMemoryUsage()

    local m = {}
    for i = 1, C_AddOns.GetNumAddOns() do
        local folder = C_AddOns.GetAddOnInfo(i)
        if folder and C_AddOns.IsAddOnLoaded(i) and not folder:match("^Blizzard_") then
            local kb = Num(pcall(GetAddOnMemoryUsage, folder))
            if kb > 0 then
                local idx = folderIdx[folder]
                if not idx then
                    s.folders[#s.folders + 1] = folder
                    idx = #s.folders
                    folderIdx[folder] = idx
                end
                m[idx] = math.floor(kb + 0.5)
            end
        end
    end

    local ev = {}
    for label, n in pairs(pending) do ev[label] = n end
    wipe(pending)

    local _, instType = IsInInstance()
    s.snaps[#s.snaps + 1] = {
        t = time() - s.start,
        k = kind,
        tot = math.floor(collectgarbage("count") + 0.5),
        m = m,
        ev = ev,
        z = GetRealZoneText() or "",
        inst = instType ~= "none" and instType or nil,
    }
    while #s.snaps > MAX_SNAPS do table.remove(s.snaps, 1) end

    lastSnapAt = GetTime()
    peakKB, dropping, valleyKB = collectgarbage("count"), false, nil
    cache = nil
    if LT.onSnapshot then LT.onSnapshot() end
end

-- 每秒一次：找「GC 剛收完一輪」的谷底
local function Tick()
    local kb = collectgarbage("count")
    if not dropping then
        if kb > peakKB then peakKB = kb end
        if kb < peakKB - math.max(DROP_MIN_KB, peakKB * DROP_FRAC) then
            dropping, valleyKB = true, kb
        end
        return
    end
    if kb < valleyKB then valleyKB = kb return end
    if kb < valleyKB + RISE_KB then return end
    -- 收完了。不管拍不拍，都從這裡重新找下一輪
    dropping, peakKB = false, kb
    if GetTime() - lastSnapAt >= GAP_GC then Snapshot("gc") end
end

local function Forced(kind)
    if GetTime() - lastSnapAt < GAP_FORCED then return end
    Snapshot(kind, true)
end

------------------------------------------------------------
-- 開關
------------------------------------------------------------
local ev = CreateFrame("Frame")

local function Start()
    if ticker then return end
    peakKB, dropping, valleyKB = collectgarbage("count"), false, nil
    ticker = C_Timer.NewTicker(1, Tick)
    for e in pairs(MARKS) do ev:RegisterEvent(e) end
    ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ev:RegisterEvent("PLAYER_FLAGS_CHANGED")
end

local function Stop()
    if ticker then ticker:Cancel() ticker = nil end
    ev:UnregisterAllEvents()
    ev:RegisterEvent("PLAYER_ENTERING_WORLD")
end

ev:RegisterEvent("PLAYER_ENTERING_WORLD")
ev:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_ENTERING_WORLD" then
        -- 登入／reload 的第一個快照就是基準點，這時讀取畫面還在，凍結看不見
        if (arg1 or arg2) and DB().on then
            Start()
            Snapshot("load", true)
        end
        return
    end
    if event == "ZONE_CHANGED_NEW_AREA" then
        local z = GetRealZoneText()
        if z and z ~= "" then pending["@" .. z] = (pending["@" .. z] or 0) + 1 end
        return
    end
    if event == "PLAYER_FLAGS_CHANGED" then
        if arg1 == "player" and UnitIsAFK("player") then Forced("afk") end
        return
    end
    local label = MARKS[event]
    if label then pending[label] = (pending[label] or 0) + 1 end
    if event == "LOADING_SCREEN_ENABLED" then Forced("load") end
end)

function LT.IsEnabled() return DB().on end

function LT.SetEnabled(on)
    local db = DB()
    db.on = on and true or false
    if db.on then
        Start()
        -- 打勾當下拍第一張當起點。這一下要強制回收（會頓半秒），
        -- 但玩家剛按下開關、預期會有反應，比在路上突然卡一下好
        Forced("start")
    else
        Stop()
    end
    cache = nil
end

function LT.SnapCount()
    return session and #session.snaps or 0
end

------------------------------------------------------------
-- 比對
------------------------------------------------------------
-- 最小平方斜率，x 是秒、y 是 KB，回傳 MB／小時
local function Slope(xs, ys)
    local n = #xs
    if n < 2 then return 0 end
    local sx, sy = 0, 0
    for i = 1, n do sx, sy = sx + xs[i], sy + ys[i] end
    local mx, my = sx / n, sy / n
    local num, den = 0, 0
    for i = 1, n do
        local dx = xs[i] - mx
        num = num + dx * (ys[i] - my)
        den = den + dx * dx
    end
    if den == 0 then return 0 end
    return num / den * 3600 / 1024
end

local function SnapAddonSum(snap)
    local s = 0
    for _, kb in pairs(snap.m) do s = s + kb end
    return s
end

local function EventText(evt, limit)
    local parts = {}
    for label, n in pairs(evt) do
        parts[#parts + 1] = { label = label, n = n }
    end
    -- 區域排前面（「在哪」比「做了什麼」先讀），同類照次數
    table.sort(parts, function(a, b)
        local az, bz = a.label:sub(1, 1) == "@", b.label:sub(1, 1) == "@"
        if az ~= bz then return az end
        if a.n ~= b.n then return a.n > b.n end
        return a.label < b.label
    end)
    local out = {}
    for i = 1, math.min(#parts, limit or 4) do
        local p = parts[i]
        local name = p.label:gsub("^@", "")
        out[#out + 1] = (p.n > 1 and p.label:sub(1, 1) ~= "@") and (name .. "×" .. p.n) or name
    end
    return table.concat(out, "、")
end

local function Analyze(s)
    local snaps = s.snaps
    local n = #snaps
    local res = { session = s, n = n, span = n > 0 and (snaps[n].t - snaps[1].t) / 60 or 0 }
    if n < MIN_SNAPS or res.span < MIN_SPAN_MIN then return res end
    res.ready = true

    local xs, tot, addon, other = {}, {}, {}, {}
    for i, sn in ipairs(snaps) do
        local a = SnapAddonSum(sn)
        xs[i], tot[i], addon[i], other[i] = sn.t, sn.tot, a, sn.tot - a
    end
    res.total = Slope(xs, tot)
    res.addon = Slope(xs, addon)
    res.other = Slope(xs, other)
    res.fromMB, res.toMB = tot[1] / 1024, tot[n] / 1024

    -- 每個資料夾的斜率：只用它有值的那些快照（隨選載入的插件中途才出現）
    res.rates = {}
    for idx, folder in ipairs(s.folders) do
        local fx, fy = {}, {}
        for i, sn in ipairs(snaps) do
            local kb = sn.m[idx]
            if kb then fx[#fx + 1], fy[#fy + 1] = xs[i], kb end
        end
        if #fx >= 3 then res.rates[folder] = Slope(fx, fy) end
    end
    local top = {}
    for folder, r in pairs(res.rates) do
        if r >= 1 then top[#top + 1] = { folder = folder, r = r } end
    end
    table.sort(top, function(a, b) return a.r > b.r end)
    res.top = top

    -- 區間：成長最多的那幾段，以及事件跟成長的關聯
    local intervals = {}
    local totalGrow, totalSec = 0, 0
    for i = 2, n do
        local dt = snaps[i].t - snaps[i - 1].t
        if dt > 0 then
            local d = (snaps[i].tot - snaps[i - 1].tot) / 1024
            intervals[#intervals + 1] = {
                from = s.start + snaps[i - 1].t, to = s.start + snaps[i].t,
                d = d, dt = dt, ev = snaps[i].ev or {}, z = snaps[i].z,
            }
            totalGrow, totalSec = totalGrow + d, totalSec + dt
        end
    end
    table.sort(intervals, function(a, b) return a.d > b.d end)
    res.worst = {}
    for i = 1, math.min(2, #intervals) do
        if intervals[i].d >= 10 then res.worst[#res.worst + 1] = intervals[i] end
    end

    -- 有某事件的區間平均成長速度 ÷ 整體平均。至少出現在兩個區間才算數，
    -- 單一區間的巧合不值得點名
    local base = totalSec > 0 and totalGrow / totalSec or 0
    local byLabel = {}
    for _, iv in ipairs(intervals) do
        for label in pairs(iv.ev) do
            local b = byLabel[label]
            if not b then b = { g = 0, sec = 0, k = 0 }; byLabel[label] = b end
            b.g, b.sec, b.k = b.g + iv.d, b.sec + iv.dt, b.k + 1
        end
    end
    res.links = {}
    if base > 0 then
        for label, b in pairs(byLabel) do
            if b.k >= 2 and b.sec > 0 then
                local ratio = (b.g / b.sec) / base
                if ratio >= 1.8 then
                    res.links[#res.links + 1] = { label = label:gsub("^@", ""), ratio = ratio }
                end
            end
        end
        table.sort(res.links, function(a, b) return a.ratio > b.ratio end)
    end
    return res
end

-- 給記憶體頁：本次登入有結論就用本次，否則退回最近一次有結論的登入
function LT.GetReport()
    if cache then return cache end
    local db = DB()
    local cur
    if session then
        cur = Analyze(session)
        if cur.ready then cache = cur return cur end
    end
    for i = #db.sessions, 1, -1 do
        local s = db.sessions[i]
        if s ~= session then
            local r = Analyze(s)
            if r.ready then
                r.previous = true
                r.pending = cur
                cache = r
                return r
            end
        end
    end
    cache = cur or { n = 0, span = 0 }
    return cache
end

-- 本次登入各資料夾的斜率（MB／小時）；沒結論回 nil
function LT.GetRates()
    local r = LT.GetReport()
    if r and r.ready and not r.previous then return r.rates end
end

------------------------------------------------------------
-- 結論文字（記憶體頁的結論區直接貼這三行）
------------------------------------------------------------
local function Signed(v) return ("%+.0f"):format(v) end

function LT.ReportLines()
    local r = LT.GetReport()
    if not DB().on and not r.ready then
        return "|cff888888勾選「洩漏追蹤」後自動記錄：GC 收完一輪、讀取畫面、暫離時各拍一次乾淨的快照。|r",
            "|cff666666不用打指令，正常玩就好；玩滿 15 分鐘、拍到 4 張以上就會在這裡寫出結論。|r", ""
    end
    if not r.ready then
        return ("|cff888888記錄中：已拍 %d 張乾淨快照、跨 %d 分鐘（需要 %d 張、%d 分鐘才下結論）|r")
                :format(r.n, math.floor(r.span + 0.5), MIN_SNAPS, MIN_SPAN_MIN),
            "|cff666666快照在 GC 收完一輪、讀取畫面、暫離時自動拍，戰鬥中不拍。|r", ""
    end

    local head = ""
    if r.previous then
        head = ("|cff888888[上次登入 %s] |r"):format(date("%m-%d %H:%M", r.session.start))
    end
    local line1
    if r.total >= LEAK_MBH * 3 then
        line1 = ("|cffff5555回收後仍每小時 %s MB —— 確定在洩漏|r"):format(Signed(r.total))
    elseif r.total >= LEAK_MBH then
        line1 = ("|cffff9900回收後每小時 %s MB —— 偏高|r"):format(Signed(r.total))
    else
        line1 = ("|cff33ff66回收後每小時 %s MB —— 穩定，沒有洩漏|r"):format(Signed(r.total))
    end
    line1 = head .. line1 .. ("|cff888888（%.0f → %.0f MB，%d 張快照、%d 分鐘）|r")
        :format(r.fromMB, r.toMB, r.n, math.floor(r.span + 0.5))

    -- 第二行：長在哪一邊、哪幾支
    local who
    if r.total < LEAK_MBH then
        who = "|cff999999"
    elseif r.other >= r.total * 0.6 then
        who = "|cffffcc66主要長在暴雪與未歸戶那塊|r|cff999999（插件在暴雪函式裡建的東西也算在這邊）"
    elseif r.addon >= r.total * 0.6 then
        who = "|cffffcc66主要長在插件|r|cff999999"
    else
        who = "|cffffcc66插件與暴雪兩邊都在長|r|cff999999"
    end
    local parts = {}
    for i = 1, math.min(3, #r.top) do
        parts[i] = ("%s %s"):format(LT.Title(r.top[i].folder), Signed(r.top[i].r))
    end
    local line2 = who .. ("：暴雪與未歸戶 %s／插件 %s"):format(Signed(r.other), Signed(r.addon))
        .. (#parts > 0 and ("；最快 " .. table.concat(parts, "、")) or "") .. "|r"

    -- 第三行：什麼時候長的
    local clues = {}
    for _, iv in ipairs(r.worst) do
        local evt = EventText(iv.ev, 3)
        clues[#clues + 1] = ("%s–%s +%.0f MB%s"):format(date("%H:%M", iv.from), date("%H:%M", iv.to),
            iv.d, evt ~= "" and ("（" .. evt .. "）") or "")
    end
    local line3 = ""
    if #clues > 0 then line3 = "漲最多：" .. table.concat(clues, "；") end
    if r.links[1] then
        local l = {}
        for i = 1, math.min(3, #r.links) do
            l[i] = ("%s（%.1f 倍）"):format(r.links[i].label, r.links[i].ratio)
        end
        line3 = line3 .. (line3 ~= "" and "｜" or "") .. "一起出現就長得快：" .. table.concat(l, "、")
    end
    if r.total < LEAK_MBH then line3 = "" end
    return line1, line2, line3 ~= "" and ("|cff999999" .. line3 .. "|r") or ""
end
