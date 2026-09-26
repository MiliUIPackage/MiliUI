------------------------------------------------------------
-- 「效能監控」分頁：插件的 CPU 與記憶體儀表板
--
-- 數據一律取自官方 API，這一頁自己**不取樣、不存歷史、不開計時器**：
--
--   CPU     C_AddOnProfiler.*。引擎本來就一直在量（不需要 scriptProfile
--           CVar，也不會因為多開這一頁而變慢），讀值只是查表。
--           GetAddOnMetric 取單一資料夾、GetOverallMetric 取插件總和、
--           GetApplicationMetric 取整個遊戲 —— 後兩者相除就是「插件佔幾成」。
--   記憶體  總量走 collectgarbage("count")，那是純讀計數器、免費。
--           ⚠ 分插件的歸戶要 UpdateAddOnMemoryUsage()，那一下是整個 Lua 堆
--           的掃描，是這一頁唯一真的會花錢的動作（Cell 的原始碼裡把它註解掉，
--           旁邊寫 "stuck like hell"）—— 所以只在開啟分頁時量一次，之後要嘛
--           按「重新測量」，要嘛勾「洩漏追蹤」（LeakTrack.lua）讓它挑乾淨的
--           時機自己量（預設關，戰鬥中不量）。
--
-- 分頁一關就完全停擺：OnUpdate 掛在分頁 frame 上，Hide 之後引擎不會派送，
-- 不必自己記得拆。分頁沒被打開過連 frame 都不會建。
--
-- 條目的合併與名稱沿用「插件總覽」那份名冊（ns.AddonInfo，見 Tab_Addons.lua）：
-- RaiderIO 的七個資料夾算成一列，玩家看到的才是「一個插件吃我多少」。
--
-- ⚠ 幾何單位：欄位的 SetPoint 位移是**原始單位**，所以欄寬也一律用原始單位
--   （SetWidth / SetSize）。P.Scale 只用在 1px 細線與圖示這種不參與橫向排版的
--   東西 —— 兩種單位混在同一排會在非像素完美的縮放下互相疊到。
------------------------------------------------------------
local _, ns = ...

local W, P = ns.W, ns.P

local SIDE       = 16

-- 這一頁分成 CPU／記憶體兩個子分頁。CPU 講「時間花在哪」（幀時間、逐插件毫秒），
-- 記憶體講「空間用在哪、往哪個方向走」（總量構成、趨勢、逐插件 MB 與變化）——
-- 兩個主題本來就沒有互相解釋的關係，硬擠在同一屏才是之前「資訊零散」的來源。
local SUB_Y      = -40          -- 子分頁鈕列
local SUB_H      = 22
local PAGE_TOP   = -70          -- 子頁內容起點

-- 子頁最上面那塊主題面板：標題（右上角放前提）／大數字／圖形／註腳 四列
local PANEL_H    = 84
local ROW_CAP    = -7
local ROW_VALUE  = -22
local ROW_GRAPH  = -48
local ROW_FOOT   = -68
local GRAPH_H    = 17           -- 面板內圖形（佔比條／構成條）的高度

-- CPU 子頁（Y 都相對子頁框）
local CPU_CTRL_Y   = -(PANEL_H + 12)
local CPU_HEAD_Y   = CPU_CTRL_Y - 30
local CPU_LIST_TOP = CPU_HEAD_Y - 22

-- 記憶體子頁：面板下面是放大的趨勢圖（有自己的標籤列），再來控制列與清單
local RAM_TRENDLBL_Y = -(PANEL_H + 12)
local RAM_PLOT_Y     = RAM_TRENDLBL_Y - 18
local RAM_PLOT_H     = 56
local RAM_CTRL_Y     = RAM_PLOT_Y - RAM_PLOT_H - 12
local RAM_REPORT_Y   = RAM_CTRL_Y - 30  -- 洩漏追蹤的結論區（三行）
local RAM_REPORT_H   = 56
local RAM_HEAD_Y     = RAM_REPORT_Y - RAM_REPORT_H - 10
local RAM_LIST_TOP   = RAM_HEAD_Y - 22

local FOOT_Y     = 8            -- 頁尾離分頁底部
local LIST_BOT   = FOOT_Y + 20  -- 頁尾一行，剩下的全給清單
local ROW_H      = 22
local BAR_H      = 10           -- 長條圖高度（列高 22，上下各留 6）
local CPUBAR_MIN_PCT = 0        -- 佔比條的下限（0 = 不夾，插件真的沒吃就畫不出來）
-- 走勢圖 Y 軸的最小跨距。沒有下限的話自動縮放會把幾 MB 的正常呼吸畫成劇烈
-- 震盪 —— 穩定的堆就該看起來是平的，這是誠實不是美化。
local GRAPH_MIN_SPAN_MB = 60
local GRAPH_MIN_POINTS  = 3
local SCROLL_W   = 20           -- CreateScrollFrame 固定讓出的捲軸寬，表頭要跟著讓

local VALUE_TICK = 1            -- 數字重讀間隔（免費，只在分頁開著時跑）
local SORT_TICK  = 5            -- 重新排序間隔：每秒重排會讓列一直上下跳，根本讀不到

-- 平均型指標超過這個 ms/幀就上色。60 FPS 一幀 16.7 ms，單一插件吃掉 1 ms 就是 6%，
-- 那確實該讓玩家看見；尖峰型指標不套色（偶爾一次 50 ms 的尖峰是正常的）。
local WARN_MS, HEAVY_MS = 0.3, 1.0

-- 欄位幾何：右側各欄用 RIGHT 錨點由右往左疊，名稱欄吃剩下的寬度。
-- 表頭與資料列讀同一份，要調欄寬只改這裡。
local COL = {
    NAME_L   = 28,
    NAME_R   = -402,
    CPU_R    = -334, CPU_W    = 62,
    CPUBAR_R = -238, CPUBAR_W = 90,
    PCT_R    = -186, PCT_W    = 44,
    MEM_R    = -104, MEM_W    = 70,
    MEMBAR_R = -8,   MEMBAR_W = 90,
}

-- 記憶體子頁的欄位幾何
-- （MB／長條／與上次測量的差／洩漏追蹤算出的每小時成長／佔插件合計）
-- 「每小時」那一欄的空間是跟長條借的（148 → 92），不是跟名稱借的：
-- 名稱被截斷比長條短一截難用得多。
local COL2 = {
    NAME_L   = 28,
    NAME_R   = -368,
    MEM_R    = -304, MEM_W    = 60,
    MEMBAR_R = -204, MEMBAR_W = 92,
    DELTA_R  = -138, DELTA_W  = 58,
    GROWTH_R = -64,  GROWTH_W = 66,
    SHARE_R  = -8,   SHARE_W  = 48,
}

-- value 直接就是 Enum.AddOnProfilerMetric 的鍵名，不另外做一層對照表
local METRICS = {
    { value = "RecentAverageTime",    text = "近期平均（最近 60 幀）", avg = true },
    { value = "SessionAverageTime",   text = "本次登入平均",           avg = true },
    { value = "EncounterAverageTime", text = "首領戰平均",             avg = true },
    { value = "PeakTime",             text = "單幀尖峰" },
}

local SORTS = { cpu = true, mem = true, name = true }

local tab, list, warnBox, lagCB, graph, folderFS
local cpuPage, ramPage
-- 子分頁鈕與它的高亮函式。收成一張表同樣是為了省 upvalue（見下面 leak 的註解）
local subTab = { buttons = {} } -- buttons[id] / Highlight
local memList                   -- 記憶體子頁的清單
-- 洩漏追蹤的控件與它的重繪函式收在一張表裡。
-- ⚠ 不是為了整齊：Init 那支函式的 upvalue 已經頂到 Lua 的 60 上限，
--    每多一個 file-scope local 就多吃一格。同一組東西一律用一張表帶走。
local leak = {}                 -- cb / statusFS / lines / head / Build / Refresh
local trend = {}                -- rangeFS / verdictFS
local cards = {}
local headerCells = {}
local valueFont

local entries = {}              -- 攤平後的條目（一列一個插件，可含多個資料夾）
local memKB = {}                -- folder -> KB，測量過才有值
local memPrevKB = {}            -- 上一次測量的快照，「變化」欄跟它比
local memHasPrev = false
local memEntries = {}           -- 記憶體子頁的排序副本（固定 MB 由大到小）
local memTotalKB = 0
local memStamp                  -- 上次測量的 GetTime()，nil = 這次開窗還沒量過
-- ⚠ 前置宣告：MeasureMemory 在上面就會呼叫它們。local 宣告在讀取點下面的話，
--    讀取點那個名字會靜默解析成全域 nil（本檔已經踩過一次，見 SetBar）
local RebuildMemEntries, RefreshMemPanel, RefreshMemList
local maxCPU, maxMem = 0, 0
local folderCount = { total = 0, loaded = 0 }
local hasProfiler = false
local rendered = 0              -- 上次真的重排過的列數（見 Refresh）
local valueAcc, sortAcc = 0, 0
local graphRev = -1             -- 上次畫圖時的 HeapTrack 版號

-- DB() 的快取。DB() 每次都要走訪 METRICS 驗證欄位，而這個值每列讀（MsColor）
-- —— 直接查 DB 等於把驗證邏輯塞進最熱的迴圈裡。
local metricIsAvg = true

------------------------------------------------------------
-- 設定值
------------------------------------------------------------
local function DB()
    if not MiliUI_DB then MiliUI_DB = {} end
    local db = MiliUI_DB.perf
    if type(db) ~= "table" then
        db = {}
        MiliUI_DB.perf = db
    end
    -- 每次都自己補、不假設結構存在：舊 DB 沒有這一格，而且指標鍵名有可能被改版拿掉
    local valid = false
    for _, m in ipairs(METRICS) do
        if m.value == db.metric then valid = true break end
    end
    if not valid then db.metric = METRICS[1].value end
    if not SORTS[db.sort] then db.sort = "cpu" end
    if type(db.desc) ~= "boolean" then db.desc = true end
    if db.page ~= "cpu" and db.page ~= "ram" then db.page = "cpu" end
    -- 舊的「每 5 秒自動測量＋累計成長」（2026-09-26 由洩漏追蹤取代）：它量的是
    -- 沒回收的堆，垃圾製造機跟洩漏混在一起分不開。欄位直接清掉
    db.autoMem, db.growth = nil, nil
    return db
end

------------------------------------------------------------
-- 洩漏追蹤的狀態列與結論區（資料與比對全在 LeakTrack.lua，這裡只貼字）
------------------------------------------------------------
function leak.Refresh()
    local LT = ns.LeakTrack
    if not (leak.statusFS and LT) then return end
    leak.cb:SetChecked(LT.IsEnabled())
    if leak.censusCB and ns.HeapCensus then leak.censusCB:SetChecked(ns.HeapCensus.IsArmed()) end
    if LT.IsEnabled() then
        leak.statusFS:SetText(("|cff999999本次登入已拍 %d 張乾淨快照|r"):format(LT.SnapCount()))
    else
        leak.statusFS:SetText("")
    end
    local l1, l2, l3 = LT.ReportLines()
    leak.lines[1]:SetText(l1)
    leak.lines[2]:SetText(l2)
    leak.lines[3]:SetText(l3)
    -- 表頭染色＝「清單現在照這一欄排」
    if leak.head then
        if LT.GetRates() then
            leak.head:SetTextColor(W.Accent())
        else
            leak.head:SetTextColor(0.6, 0.6, 0.6)
        end
    end
end

local function CurrentMetric()
    local key = DB().metric
    for _, m in ipairs(METRICS) do
        if m.value == key then return m end
    end
    return METRICS[1]
end

------------------------------------------------------------
-- 官方數據的讀取層
--
-- 全部經過 pcall ＋值域檢查：分析器可能整組不存在（舊客戶端）或被關掉，
-- 而 nan／inf 混進來會讓後面的排序比較行為變得無法預測。
------------------------------------------------------------
local function ProfilerAvailable()
    if type(C_AddOnProfiler) ~= "table"
            or type(C_AddOnProfiler.GetAddOnMetric) ~= "function"
            or type(Enum) ~= "table" or type(Enum.AddOnProfilerMetric) ~= "table" then
        return false
    end
    if type(C_AddOnProfiler.IsEnabled) == "function" then
        local ok, on = pcall(C_AddOnProfiler.IsEnabled)
        if ok and on == false then return false end
    end
    return true
end

local function Num(ok, v)
    if not ok then return 0 end
    v = tonumber(v)
    -- v ~= v 是 nan 的判法（nan 不等於自己）
    if not v or v ~= v or v < 0 or v == math.huge then return 0 end
    return v
end

local function MetricEnum(key)
    if not hasProfiler then return nil end
    return Enum.AddOnProfilerMetric[key]
end

local function FolderMetric(folder, metric)
    if not (hasProfiler and metric) then return 0 end
    return Num(pcall(C_AddOnProfiler.GetAddOnMetric, folder, metric))
end

local function GlobalMetric(fnName, metric)
    if not (hasProfiler and metric and type(C_AddOnProfiler[fnName]) == "function") then return 0 end
    return Num(pcall(C_AddOnProfiler[fnName], metric))
end

-- 多資料夾條目的合計。時間與次數可以相加；尖峰不行（各自發生在不同幀），取最大值
local function ItemMetric(item, key, useMax)
    local metric = MetricEnum(key)
    if not metric then return 0 end
    local total = 0
    for _, f in ipairs(item.folders) do
        local v = FolderMetric(f, metric)
        if useMax then
            if v > total then total = v end
        else
            total = total + v
        end
    end
    return total
end

------------------------------------------------------------
-- 記憶體
--
-- UpdateAddOnMemoryUsage 是這一頁唯一昂貴的呼叫，只有這個函式會叫它。
-- GetAddOnMemoryUsage 從 10.1.0 起對暴雪內部插件會直接報錯，所以逐筆 pcall。
------------------------------------------------------------
-- fresh = 剛剛別人（洩漏追蹤）才掃過堆，直接讀結果，不再掃一次
local function MeasureMemory(fresh)
    if type(UpdateAddOnMemoryUsage) ~= "function"
            or type(GetAddOnMemoryUsage) ~= "function" then
        return
    end
    if not fresh then UpdateAddOnMemoryUsage() end
    -- 「變化」欄跟上一次測量比。快照要在覆寫前抄走 —— 存參照的話新舊是同一張表，
    -- 差值永遠是 0（同一個坑見 Cell 筆記的 sig 快照）
    if memStamp then
        wipe(memPrevKB)
        for f, kb in pairs(memKB) do memPrevKB[f] = kb end
        memHasPrev = true
    end
    wipe(memKB)
    for _, item in ipairs(entries) do
        for _, f in ipairs(item.folders) do
            memKB[f] = Num(pcall(GetAddOnMemoryUsage, f))
        end
    end
    memStamp = GetTime()
    if RebuildMemEntries then
        RebuildMemEntries()
        if ramPage and ramPage:IsShown() then
            RefreshMemPanel()
            RefreshMemList()
            leak.Refresh()
        end
    end
end

------------------------------------------------------------
-- 格式化
------------------------------------------------------------
local function FmtMs(v)
    if v >= 100 then return ("%.0f"):format(v) end
    if v >= 10 then return ("%.1f"):format(v) end
    return ("%.2f"):format(v)
end

local function FmtMB(kb)
    local mb = (kb or 0) / 1024
    if mb >= 100 then return ("%.0f"):format(mb) end
    if mb >= 10 then return ("%.1f"):format(mb) end
    return ("%.2f"):format(mb)
end

local function MsColor(ms)
    if not metricIsAvg then return "|cffffffff" end
    if ms >= HEAVY_MS then return "|cffff5555" end
    if ms >= WARN_MS then return "|cffff9900" end
    return "|cffffffff"
end

------------------------------------------------------------
-- 條目：名冊的分組 ＋ 沒列名冊的自動補列，只留「這次真的載入了」的
-- （停用或還沒載入的插件 CPU 與記憶體都是 0，列出來只是雜訊）
------------------------------------------------------------
local function AnyLoaded(folders)
    for _, f in ipairs(folders) do
        if C_AddOns.IsAddOnLoaded(f) then return true end
    end
    return false
end

local function RebuildEntries()
    wipe(entries)
    local A = ns.AddonInfo
    local installed = A.GetInstalled()

    folderCount.total, folderCount.loaded = 0, 0
    for name in pairs(installed) do
        folderCount.total = folderCount.total + 1
        if C_AddOns.IsAddOnLoaded(name) then folderCount.loaded = folderCount.loaded + 1 end
    end

    local covered = {}
    for _, e in ipairs(ns.AddonRoster.entries) do
        for _, f in ipairs(e.folders) do covered[f] = true end
    end

    local function Add(key, folders)
        if not AnyLoaded(folders) then return end
        local item = { key = key, folders = folders }
        item.title = A.EntryTitle(item)          -- EntryTitle 只讀 folders[1]
        item.sortName = A.StripCodes(item.title):lower()
        item.icon = A.EntryMeta(item, "IconTexture")
            or "Interface\\Icons\\INV_Misc_QuestionMark"
        entries[#entries + 1] = item
    end

    for _, e in ipairs(ns.AddonRoster.entries) do
        if installed[e.folders[1]] then Add(e.key, e.folders) end
    end
    for name in pairs(installed) do
        -- 暴雪自家的 LoD 模組不是玩家能開關的東西，而且 GetAddOnMemoryUsage 對它們會報錯
        if not covered[name] and not name:match("^Blizzard_") then
            Add(name, { name })
        end
    end
end

------------------------------------------------------------
-- 取值與排序
--
-- 數字每秒重讀、順序每 SORT_TICK 秒才重排：拆開的理由是每秒重排的話列會一直
-- 上下跳，玩家連自己剛剛在看哪一行都認不出來。
------------------------------------------------------------
local function Recompute()
    local info = CurrentMetric()
    metricIsAvg = info.avg and true or false
    local metric = MetricEnum(info.value)
    -- 佔比是「這個插件 ÷ 整個遊戲」，跟長條圖的「÷ 榜首」是兩件事，分開算
    local appMs = GlobalMetric("GetApplicationMetric", metric)
    maxCPU, maxMem = 0, 0
    for _, item in ipairs(entries) do
        local cpu, mem = 0, 0
        for _, f in ipairs(item.folders) do
            cpu = cpu + FolderMetric(f, metric)
            mem = mem + (memKB[f] or 0)
        end
        item.cpu, item.mem = cpu, mem
        item.pct = appMs > 0 and (cpu / appMs * 100) or 0
        if cpu > maxCPU then maxCPU = cpu end
        if mem > maxMem then maxMem = mem end
    end
end

local function Resort()
    local db = DB()
    local key, desc = db.sort, db.desc
    table.sort(entries, function(a, b)
        local av, bv
        if key == "cpu" then
            av, bv = a.cpu or 0, b.cpu or 0
        elseif key == "mem" then
            av, bv = a.mem or 0, b.mem or 0
        end
        if av and av ~= bv then
            if desc then return av > bv end
            return av < bv
        end
        -- 名稱排序，同時也是數值打平時的決勝條件：條目有一部分來自 hash 表走訪，
        -- 順序本來就不固定，沒有這一條的話同為 0 的那一大票每次重排都會換位置
        if a.sortName ~= b.sortName then
            if key == "name" and desc then return a.sortName > b.sortName end
            return a.sortName < b.sortName
        end
        return a.key < b.key
    end)
end

------------------------------------------------------------
-- 長條填充：面板的佔比條與清單每一列的長條共用
-- ⚠ 必須宣告在兩個面板的 Refresh 之前。local 宣告在讀取點下面的話，上面那個
--    名字會靜默解析成全域 nil —— 不會報錯，只會在第一次重畫時炸掉。
------------------------------------------------------------
local function SetBar(track, value, max)
    if not max or max <= 0 or value <= 0 then
        track.fill:Hide()
        return
    end
    local frac = value / max
    if frac > 1 then frac = 1 end
    -- 下限一個實體像素：真的有量到就該看得見一條，否則「0」跟「非常小」長得一模一樣
    track.fill:SetWidth(math.max(P.Scale(1), track.maxW * frac))
    track.fill:Show()
end

------------------------------------------------------------
-- 上方兩塊主題面板
--
-- 四列的骨架兩塊共用：標題（右上角放「這個數字的前提」）、大數字、一條圖形、
-- 註腳。左邊講這一幀的時間花在哪，右邊講記憶體用了多少、往哪個方向走。
------------------------------------------------------------
local function CreatePanel(parent, caption)
    local panel = W.CreateFrame(nil, parent)
    panel:SetSize(10, PANEL_H)
    W.Stylize(panel, { 0.08, 0.08, 0.08, 0.9 })

    -- 左緣 3px 職業色直條：跟總覽選中列同一個視覺語彙
    local edge = panel:CreateTexture(nil, "ARTWORK")
    edge:SetColorTexture(W.Accent(0.9))
    edge:SetPoint("TOPLEFT", 0, 0)
    edge:SetPoint("BOTTOMLEFT", 0, 0)
    edge:SetWidth(P.Scale(3))

    local cap = panel:CreateFontString(nil, "OVERLAY")
    cap:SetFontObject(W.fontSmall)
    cap:SetPoint("TOPLEFT", 10, ROW_CAP)
    cap:SetText("|cff999999" .. caption .. "|r")

    -- 右上角：這個數字的前提（CPU 是哪個指標算的／記憶體是什麼時候量的）。
    -- 放在標題同一列而不是塞進註腳 —— 前提要在讀到數字之前就看到。
    panel.note = panel:CreateFontString(nil, "OVERLAY")
    panel.note:SetFontObject(W.fontSmall)
    panel.note:SetPoint("TOPRIGHT", -10, ROW_CAP)
    panel.note:SetJustifyH("RIGHT")

    panel.value = panel:CreateFontString(nil, "OVERLAY")
    panel.value:SetFontObject(valueFont)
    panel.value:SetPoint("TOPLEFT", 10, ROW_VALUE)
    panel.value:SetJustifyH("LEFT")

    panel.sub = panel:CreateFontString(nil, "OVERLAY")
    panel.sub:SetFontObject(W.fontSmall)
    panel.sub:SetPoint("LEFT", panel.value, "RIGHT", 5, -1)
    panel.sub:SetJustifyH("LEFT")

    panel.foot = panel:CreateFontString(nil, "OVERLAY")
    panel.foot:SetFontObject(W.fontSmall)
    panel.foot:SetPoint("TOPLEFT", 10, ROW_FOOT)
    panel.foot:SetJustifyH("LEFT")

    panel.footRight = panel:CreateFontString(nil, "OVERLAY")
    panel.footRight:SetFontObject(W.fontSmall)
    panel.footRight:SetPoint("TOPRIGHT", -10, ROW_FOOT)
    panel.footRight:SetJustifyH("RIGHT")

    return panel
end

-- 面板內的圖形區：兩塊面板各自放不同東西（佔比條／走勢圖），但位置與高度
-- 共用，橫著看才是一條線
local function PanelGraphArea(panel, leftInset)
    local area = W.CreateFrame(nil, panel)
    W.Stylize(area, { 0.13, 0.13, 0.14, 1 })
    area:SetPoint("TOPLEFT", leftInset or 10, ROW_GRAPH)
    area:SetPoint("TOPRIGHT", -10, ROW_GRAPH)
    area:SetHeight(GRAPH_H)
    return area
end

local function RefreshCpuPanel()
    local info = CurrentMetric()
    local metric = MetricEnum(info.value)
    local addonMs = GlobalMetric("GetOverallMetric", metric)
    local appMs   = GlobalMetric("GetApplicationMetric", metric)
    local fps = GetFramerate() or 0

    -- ⚠ 單位跟著指標走：在「單幀尖峰」下 appMs 是**最差的一幀**，不是每幀
    local cpu = cards.cpu
    cpu.note:SetText("|cff777777" .. info.text:gsub("（.-）", "") .. "|r")

    if hasProfiler then
        cpu.value:SetText(MsColor(addonMs) .. FmtMs(addonMs) .. "|r")
        cpu.sub:SetText("|cff999999毫秒|r")
    else
        cpu.value:SetText("|cff666666—|r")
        cpu.sub:SetText("")
    end

    local pct = (hasProfiler and appMs > 0) and (addonMs / appMs * 100) or 0
    cpu.pctFS:SetText(hasProfiler and appMs > 0
        and ("|cff999999插件佔 %.1f%%|r"):format(pct) or "|cff666666插件佔比不明|r")
    SetBar(cpu.bar, pct, 100)

    cpu.foot:SetText(("|cff999999%d FPS|r"):format(math.floor(fps + 0.5)))
    cpu.footRight:SetText(appMs > 0 and ("|cff999999%s %.1f 毫秒|r"):format(
        info.avg and "每幀" or "最差的一幀", appMs) or "")

    if folderFS then
        folderFS:SetText(("|cff777777已載入 %d ／ 共 %d 個插件資料夾|r"):format(
            folderCount.loaded, folderCount.total))
    end
end

-- 記憶體面板：總量、歸戶時間、構成條（插件 vs 暴雪與未歸戶）。
-- 前置宣告過的 local，這裡是本體
function RefreshMemPanel()
    local mem = cards.mem
    local totalKB = collectgarbage("count")   -- 純讀計數器，免費
    mem.value:SetText(FmtMB(totalKB))
    mem.sub:SetText("|cff999999MB|r")

    if not memStamp then
        mem.note:SetText("|cff666666尚未歸戶|r")
        mem.comp.fill:Hide()
        mem.foot:SetText("|cff666666按「重新測量記憶體」把總量歸戶到各插件|r")
        mem.footRight:SetText("")
        return
    end

    local ago = math.floor(GetTime() - memStamp)
    if ago < 2 then
        mem.note:SetText("|cff777777剛剛歸戶|r")
    elseif ago < 60 then
        mem.note:SetText(("|cff777777%d 秒前歸戶|r"):format(ago))
    else
        mem.note:SetText(("|cff777777%d 分鐘前歸戶|r"):format(math.floor(ago / 60)))
    end

    -- 構成條：亮的那段是插件歸戶合計，暗的其餘是暴雪 UI＋歸不了戶的部分。
    -- 兩個數字的取樣時間不同（總量即時、歸戶是上次測量），比例只會準到「分鐘級」，
    -- 但這裡要回答的問題本來就是「一半一半還是三七開」，不是小數點
    local addonKB = 0
    for _, kb in pairs(memKB) do addonKB = addonKB + kb end
    local frac = totalKB > 0 and math.min(addonKB / totalKB, 1) or 0
    local track = mem.comp
    track.fill:SetWidth(math.max(P.Scale(1), track:GetWidth() * frac))
    track.fill:Show()

    mem.foot:SetText(("|cff999999插件 %s MB（%.0f%%）｜暴雪與未歸戶 %s MB|r"):format(
        FmtMB(addonKB), frac * 100, FmtMB(math.max(totalKB - addonKB, 0))))
    mem.footRight:SetText("")
end

------------------------------------------------------------
-- 表頭（點欄名切換排序）
------------------------------------------------------------
local function RefreshHeaders()
    local db = DB()
    for _, cell in ipairs(headerCells) do
        local active = (cell.sortKey == db.sort)
        if active then
            cell.text:SetTextColor(W.Accent(1))
        else
            cell.text:SetTextColor(0.6, 0.6, 0.6)
        end
        cell.arrow:SetShown(active)
        -- 素材原本朝右：轉 -90° 朝下（遞減）、+90° 朝上（遞增）。
        -- 用貼圖不用字元，中文字型沒有 ▼
        cell.arrow:SetRotation(math.rad(db.desc and -90 or 90))
    end
end

local function CreateHeaderCell(parent, text, sortKey, justify, width, onClick)
    local cell = CreateFrame("Button", nil, parent)
    cell:SetSize(width, 16)

    cell.text = cell:CreateFontString(nil, "OVERLAY")
    cell.text:SetFontObject(W.fontSmall)
    cell.text:SetText(text)
    cell.text:SetWordWrap(false)

    cell.arrow = cell:CreateTexture(nil, "OVERLAY")
    cell.arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    cell.arrow:SetDesaturated(true)
    cell.arrow:SetVertexColor(W.Accent(1))
    cell.arrow:SetSize(10, 10)

    if justify == "RIGHT" then
        cell.text:SetPoint("RIGHT", 0, 0)
        cell.arrow:SetPoint("RIGHT", cell.text, "LEFT", -2, 0)
    else
        cell.text:SetPoint("LEFT", 0, 0)
        cell.arrow:SetPoint("LEFT", cell.text, "RIGHT", 2, 0)
    end

    cell.sortKey = sortKey
    cell:SetScript("OnEnter", function(s) s.text:SetTextColor(1, 1, 1) end)
    cell:SetScript("OnLeave", RefreshHeaders)
    cell:SetScript("OnClick", function(s) onClick(s) end)
    headerCells[#headerCells + 1] = cell
    return cell
end

------------------------------------------------------------
-- 資料列
------------------------------------------------------------
local function CreateBar(row, width, right)
    local track = row:CreateTexture(nil, "ARTWORK")
    track:SetColorTexture(1, 1, 1, 0.06)
    track:SetPoint("RIGHT", row, "RIGHT", right, 0)
    track:SetSize(width, BAR_H)

    local fill = row:CreateTexture(nil, "ARTWORK", nil, 1)
    fill:SetColorTexture(W.Accent(0.85))
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 0, 0)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 0, 0)

    track.fill, track.maxW = fill, width
    return track
end

local TOOLTIP_COUNTS = {
    { "CountTimeOver10Ms",  "超過 10 毫秒" },
    { "CountTimeOver50Ms",  "超過 50 毫秒" },
    { "CountTimeOver100Ms", "超過 100 毫秒" },
}

local function ShowRowTooltip(row)
    local item = row.item
    if not item then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(item.title, 1, 1, 1)

    if #item.folders > 1 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("資料夾明細", 1, 0.82, 0)
        local metric = MetricEnum(DB().metric)
        for _, f in ipairs(item.folders) do
            GameTooltip:AddDoubleLine(f,
                ("%s 毫秒　%s MB"):format(FmtMs(FolderMetric(f, metric)), FmtMB(memKB[f])),
                0.8, 0.8, 0.8, 1, 1, 1)
        end
    end

    if hasProfiler then
        -- 卡頓次數與尖峰都是引擎自己數好的，讀值不花錢
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("本次登入以來", 1, 0.82, 0)
        GameTooltip:AddDoubleLine("單幀尖峰",
            FmtMs(ItemMetric(item, "PeakTime", true)) .. " 毫秒", 0.8, 0.8, 0.8, 1, 1, 1)
        local quiet = true
        for _, c in ipairs(TOOLTIP_COUNTS) do
            local n = ItemMetric(item, c[1])
            if n > 0 then
                GameTooltip:AddDoubleLine(c[2], ("%d 次"):format(n), 0.8, 0.8, 0.8, 1, 0.6, 0.3)
                quiet = false
            end
        end
        if quiet then
            GameTooltip:AddLine("沒有超過 10 毫秒的單幀", 0.5, 0.5, 0.5)
        end
    end
    GameTooltip:Show()
end

local function BuildRow(row)
    row:EnableMouse(true)

    row.hoverTex = row:CreateTexture(nil, "BACKGROUND", nil, 3)
    row.hoverTex:SetAllPoints()
    row.hoverTex:SetColorTexture(1, 1, 1, 0.05)
    row.hoverTex:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.nameFS = row:CreateFontString(nil, "OVERLAY")
    row.nameFS:SetFontObject(W.fontNormal)
    row.nameFS:SetPoint("LEFT", COL.NAME_L, 0)
    row.nameFS:SetPoint("RIGHT", row, "RIGHT", COL.NAME_R, 0)
    row.nameFS:SetJustifyH("LEFT")
    row.nameFS:SetWordWrap(false)

    local function RightText(width, right, fontObject)
        local fs = row:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(fontObject or W.fontNormal)
        fs:SetPoint("RIGHT", row, "RIGHT", right, 0)
        fs:SetWidth(width)
        fs:SetJustifyH("RIGHT")
        fs:SetWordWrap(false)
        return fs
    end

    row.cpuFS  = RightText(COL.CPU_W, COL.CPU_R)
    row.cpuBar = CreateBar(row, COL.CPUBAR_W, COL.CPUBAR_R)
    row.pctFS  = RightText(COL.PCT_W, COL.PCT_R, W.fontSmall)
    row.memFS  = RightText(COL.MEM_W, COL.MEM_R)
    row.memBar = CreateBar(row, COL.MEMBAR_W, COL.MEMBAR_R)

    row:SetScript("OnEnter", function(self)
        self.hoverTex:Show()
        ShowRowTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        self.hoverTex:Hide()
        GameTooltip:Hide()
    end)
end

-- ⚠ 列會回收：每一格都要重設，不能只在「有值」的時候寫。
--
-- 但「這一列是誰」每秒不會變，而 SetText／SetTexture 不是免費的（每次都要重排
-- 文字）。這支每秒對每一列跑一次，圖示與名稱照寫等於一秒白花五十次 —— 所以拿
-- row.shownKey 記住這格現在裝的是誰，換人才重寫。數字欄本來就每秒都變，照寫。
local function UpdateRow(row, item)
    row.item = item

    local cpu, mem = item.cpu or 0, item.mem or 0
    local dim = (cpu <= 0 and mem <= 0)

    if row.shownKey ~= item.key then
        row.shownKey = item.key
        row.icon:SetTexture(item.icon)
        row.nameFS:SetText(item.title)
        row.dim = nil          -- 換人了，下面的明暗一定要重設一次
    end
    if row.dim ~= dim then
        row.dim = dim
        row.nameFS:SetAlpha(dim and 0.5 or 1)
        row.icon:SetAlpha(dim and 0.5 or 1)
    end

    row.cpuFS:SetText(MsColor(cpu) .. FmtMs(cpu) .. "|r")
    SetBar(row.cpuBar, cpu, maxCPU)

    if (item.pct or 0) > 0 then
        row.pctFS:SetText(("|cff999999%.1f%%|r"):format(item.pct))
    else
        row.pctFS:SetText("")
    end

    if memStamp then
        row.memFS:SetText(FmtMB(mem))
        SetBar(row.memBar, mem, maxMem)
    else
        row.memFS:SetText("|cff666666—|r")
        SetBar(row.memBar, 0, 0)
    end
end

------------------------------------------------------------
-- 記憶體子頁：排序副本與資料列
--
-- CPU 清單每秒重讀重排；記憶體只在「測量」的那一刻才有新數字，所以這份清單
-- 固定 MB 由大到小、只在測量後重建 —— 不用表頭排序，也沒有每秒的重寫。
------------------------------------------------------------
function RebuildMemEntries()
    wipe(memEntries)
    memTotalKB = 0
    local rates = ns.LeakTrack and ns.LeakTrack.GetRates()
    for _, item in ipairs(entries) do
        local mem, prev = 0, 0
        for _, f in ipairs(item.folders) do
            mem = mem + (memKB[f] or 0)
            prev = prev + (memPrevKB[f] or 0)
        end
        -- 獨立欄位不共用 item.mem：那個每秒被 CPU 頁的 Recompute 覆寫
        item.mem2 = mem
        item.memDelta = memHasPrev and (mem - prev) or nil
        local rate
        if rates then
            rate = 0
            for _, f in ipairs(item.folders) do rate = rate + (rates[f] or 0) end
        end
        item.memRate = rate
        memTotalKB = memTotalKB + mem
        if mem > 0 then memEntries[#memEntries + 1] = item end
    end
    -- 洩漏追蹤有結論就改成「長最快的排最上面」——那正是開著追蹤時要看的東西；
    -- 沒有結論就回到固定 MB 由大到小。
    if rates then
        table.sort(memEntries, function(a, b)
            if a.memRate ~= b.memRate then return a.memRate > b.memRate end
            if a.mem2 ~= b.mem2 then return a.mem2 > b.mem2 end
            return a.sortName < b.sortName
        end)
    else
        table.sort(memEntries, function(a, b)
            if a.mem2 ~= b.mem2 then return a.mem2 > b.mem2 end
            return a.sortName < b.sortName
        end)
    end
end

-- 「變化」欄的上色：跟上一次測量比。爬升是嫌疑（垃圾製造機的指紋是「爬升又
-- 回落」），回落是 GC 收走了。半 MB 以下當雜訊 —— 每次測量之間的正常呼吸
local function FmtDelta(kb)
    if kb == nil then return "|cff666666—|r" end
    local mb = kb / 1024
    if mb >= 5 then return ("|cffff5555+%.1f|r"):format(mb) end
    if mb >= 0.5 then return ("|cffff9900+%.1f|r"):format(mb) end
    if mb <= -0.5 then return ("|cff33ff66%.1f|r"):format(mb) end
    return "|cff8888880.0|r"
end

-- 「每小時」欄：洩漏追蹤在回收後的快照上算的斜率（MB／小時）。
-- 用亮度分級講「這筆值不值得追」；負的與 1 MB 以下都是雜訊
local function FmtRate(mb)
    if not mb or mb < 1 then return "|cff666666—|r" end
    if mb >= 20 then return ("|cffff5555+%.0f|r"):format(mb) end
    if mb >= 5  then return ("|cffff9900+%.0f|r"):format(mb) end
    return ("|cffcccccc+%.0f|r"):format(mb)
end

local function ShowMemRowTooltip(row)
    local item = row.item
    if not item then return end
    GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
    GameTooltip:AddLine(item.title, 1, 1, 1)
    if #item.folders > 1 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("資料夾明細", 1, 0.82, 0)
        for _, f in ipairs(item.folders) do
            GameTooltip:AddDoubleLine(f, FmtMB(memKB[f]) .. " MB", 0.8, 0.8, 0.8, 1, 1, 1)
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("「變化」是跟上一次測量比。持續 +、過一陣子突然一大筆 − ＝"
        .. "垃圾製造機（配置快），跟佔用大是兩回事；佔用大但不動的是資料庫，無害。",
        0.6, 0.6, 0.6, true)
    GameTooltip:Show()
end

local function BuildMemRow(row)
    row:EnableMouse(true)

    row.hoverTex = row:CreateTexture(nil, "BACKGROUND", nil, 3)
    row.hoverTex:SetAllPoints()
    row.hoverTex:SetColorTexture(1, 1, 1, 0.05)
    row.hoverTex:Hide()

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(16, 16)
    row.icon:SetPoint("LEFT", 6, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.nameFS = row:CreateFontString(nil, "OVERLAY")
    row.nameFS:SetFontObject(W.fontNormal)
    row.nameFS:SetPoint("LEFT", COL2.NAME_L, 0)
    row.nameFS:SetPoint("RIGHT", row, "RIGHT", COL2.NAME_R, 0)
    row.nameFS:SetJustifyH("LEFT")
    row.nameFS:SetWordWrap(false)

    local function RightText(width, right, fontObject)
        local fs = row:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(fontObject or W.fontNormal)
        fs:SetPoint("RIGHT", row, "RIGHT", right, 0)
        fs:SetWidth(width)
        fs:SetJustifyH("RIGHT")
        fs:SetWordWrap(false)
        return fs
    end

    row.memFS    = RightText(COL2.MEM_W, COL2.MEM_R)
    row.memBar   = CreateBar(row, COL2.MEMBAR_W, COL2.MEMBAR_R)
    row.deltaFS  = RightText(COL2.DELTA_W, COL2.DELTA_R)
    row.growthFS = RightText(COL2.GROWTH_W, COL2.GROWTH_R)
    row.shareFS  = RightText(COL2.SHARE_W, COL2.SHARE_R, W.fontSmall)

    row:SetScript("OnEnter", function(self)
        self.hoverTex:Show()
        ShowMemRowTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        self.hoverTex:Hide()
        GameTooltip:Hide()
    end)
end

local function UpdateMemRow(row, item)
    row.item = item
    if row.shownKey ~= item.key then
        row.shownKey = item.key
        row.icon:SetTexture(item.icon)
        row.nameFS:SetText(item.title)
    end
    row.memFS:SetText(FmtMB(item.mem2))
    SetBar(row.memBar, item.mem2, memEntries[1] and memEntries[1].mem2 or 0)
    row.deltaFS:SetText(FmtDelta(item.memDelta))
    row.growthFS:SetText(FmtRate(item.memRate))
    if memTotalKB > 0 then
        row.shareFS:SetText(("|cff999999%.1f%%|r"):format(item.mem2 / memTotalKB * 100))
    else
        row.shareFS:SetText("")
    end
end

function RefreshMemList()
    if memList then memList:Update(memEntries, UpdateMemRow) end
end

------------------------------------------------------------
-- Lua 堆走勢圖（記憶體子頁）
--
-- 資料來自 ns.HeapTrack（常駐、1 Hz 取樣、每分鐘留一個最低點），這裡只負責畫。
-- 直條而不是折線：折線得自己算斜率再轉成貼圖，直條就是一根貼圖一個取樣點 ——
-- 一樣讀得出趨勢，而且不必為了幾何去對抗像素對齊。
------------------------------------------------------------
local function GraphColumn(i)
    local col = graph.cols[i]
    if not col then
        col = graph.plot:CreateTexture(nil, "ARTWORK")
        col:SetColorTexture(W.Accent(0.75))
        graph.cols[i] = col
    end
    return col
end

local function RefreshGraph()
    local HT = ns.HeapTrack
    local samples = HT and HT.GetSamples()
    local n = samples and #samples or 0

    if n < GRAPH_MIN_POINTS then
        for _, col in ipairs(graph.cols) do col:Hide() end
        graph.emptyFS:SetText(("|cff666666趨勢累積中…每分鐘一點，已有 %d 點|r"):format(n))
        graph.emptyFS:Show()
        trend.rangeFS:SetText("")
        trend.verdictFS:SetText("")
        return
    end
    graph.emptyFS:Hide()

    local t = HT.GetTrend()
    -- 下限撐開後以資料中心對齊，否則平穩的線會被推到圖的邊緣
    local lo, hi = t.loMB, t.hiMB
    if hi - lo < GRAPH_MIN_SPAN_MB then
        local mid = (lo + hi) / 2
        lo, hi = mid - GRAPH_MIN_SPAN_MB / 2, mid + GRAPH_MIN_SPAN_MB / 2
    end
    -- ⚠ 底部再往下讓一截：Y 軸從最小值起算的話，最低的那幾點會被畫成零高度，
    -- 看起來像「那段沒有資料」而不是「那段最低」
    lo = lo - (hi - lo) * 0.12

    local plotW, plotH = graph.plot:GetWidth(), graph.plot:GetHeight()
    local colW, span = plotW / n, hi - lo
    for i = 1, n do
        local col = GraphColumn(i)
        local frac = (samples[i].kb / 1024 - lo) / span
        col:ClearAllPoints()
        col:SetPoint("BOTTOMLEFT", graph.plot, "BOTTOMLEFT", (i - 1) * colW, 0)
        -- 寬度多給半格把相鄰兩根之間的縫填掉：colW 幾乎不會是整數像素
        col:SetSize(math.max(1, colW + 0.5), math.max(P.Scale(1), plotH * frac))
        col:Show()
    end
    for i = n + 1, #graph.cols do graph.cols[i]:Hide() end

    -- 標籤列左邊講「看到的是什麼範圍」，右邊講「結論」——視線掃右緣就有答案
    trend.rangeFS:SetText(("|cff888888%.0f – %.0f MB／%d 分鐘|r"):format(
        t.loMB, t.hiMB, math.floor(t.spanMin + 0.5)))
    local colour = (t.level == "bad" and "|cffff5555")
        or (t.level == "warn" and "|cffff9900")
        or (t.level == "good" and "|cff33ff66") or "|cff888888"
    trend.verdictFS:SetText(colour .. t.text .. "|r")
end

------------------------------------------------------------
-- 更新迴圈：兩個子頁各自只付自己需要的錢
------------------------------------------------------------
-- 順序沒動的那幾秒只重寫欄位文字，不走 list:Update ——
-- 那支每列都會 ClearAllPoints ＋兩次 SetPoint，六十列每秒重錨一次是白花的。
local function Refresh(resort)
    Recompute()
    if resort then Resort() end
    RefreshCpuPanel()
    if resort or rendered ~= #entries then
        list:Update(entries, list.updateRow)
        rendered = #entries
    else
        for i = 1, #entries do
            local row = list.rows[i]
            if row then UpdateRow(row, entries[i]) end
        end
    end
end

local function OnTabUpdate(_, elapsed)
    valueAcc = valueAcc + elapsed
    sortAcc  = sortAcc + elapsed
    -- 走勢圖每分鐘才有新資料，用版號比對就好，不必每秒重畫幾十根貼圖
    if ramPage:IsShown() then
        local rev = ns.HeapTrack and ns.HeapTrack.GetRevision() or 0
        if rev ~= graphRev then
            graphRev = rev
            RefreshGraph()
        end
    end

    if valueAcc < VALUE_TICK then return end
    valueAcc = 0
    if cpuPage:IsShown() then
        local resort = (sortAcc >= SORT_TICK)
        if resort then sortAcc = 0 end
        Refresh(resort)
    else
        -- 記憶體頁每秒只有兩樣東西會動：總量數字與「幾秒前歸戶」
        RefreshMemPanel()
    end
end

------------------------------------------------------------
-- 分頁組裝
------------------------------------------------------------
local function OnHeaderClick(cell)
    local db = DB()
    if db.sort == cell.sortKey then
        db.desc = not db.desc
    else
        db.sort = cell.sortKey
        db.desc = (cell.sortKey ~= "name")   -- 數字預設由大到小，名稱由 A 到 Z
    end
    RefreshHeaders()
    sortAcc = 0
    Refresh(true)
end

local function ShowPage(id)
    DB().page = id
    cpuPage:SetShown(id == "cpu")
    ramPage:SetShown(id == "ram")
    if subTab.Highlight and subTab.buttons[id] then subTab.Highlight(subTab.buttons[id]) end
    if id == "cpu" then
        sortAcc = 0
        Refresh(true)
    else
        RefreshMemPanel()
        RefreshMemList()
        leak.Refresh()
        graphRev = -1           -- 進頁立刻重畫，不等下一個取樣點
        RefreshGraph()
    end
end

-- 控制列的洩漏追蹤開關＋下面三行結論區。拆出 Init 是因為 Init 的 upvalue 已滿
function leak.Build(anchor, innerW)
    local LT = ns.LeakTrack
    leak.cb = W.CreateCheckButton(ramPage, "洩漏追蹤", function(checked)
        if not LT then return end
        LT.SetEnabled(checked)
        leak.Refresh()
    end)
    leak.cb:SetPoint("LEFT", anchor, "RIGHT", 14, 0)
    leak.cb:SetScript("OnEnter", function()
        GameTooltip:SetOwner(leak.cb, "ANCHOR_TOPLEFT", 0, 4)
        GameTooltip:AddLine("洩漏追蹤", 1, 1, 1)
        GameTooltip:AddLine("在堆最乾淨的時候自動拍快照：GC 剛收完一輪、讀取畫面、暫離。"
            .. "每張記下總量、每個插件的用量，以及上一張之後做過什麼（戰鬥、拍賣場、換區域…）。",
            0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("玩滿 15 分鐘、拍到 4 張就自動比對：每小時長多少、長在插件還是暴雪那邊、"
            .. "哪幾支長最快、在做什麼的時候長。結果寫在下面，登出後也留著。", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("代價：勾選當下與讀取畫面、暫離時會強制回收一次（半秒左右的頓，"
            .. "讀取畫面會變長一點）；GC 收完時的快照是一次堆掃描。戰鬥中不拍。"
            .. "抓完就取消勾選。", 1, 0.6, 0.3, true)
        GameTooltip:Show()
    end)
    leak.cb:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 堆普查：一次性，下次 reload 才跑，跑完自己取消勾選（HeapCensus.lua）
    local HC = ns.HeapCensus
    leak.censusCB = W.CreateCheckButton(ramPage, "reload 後普查", function(checked)
        if HC then HC.SetArmed(checked) end
    end)
    leak.censusCB:SetPoint("LEFT", leak.cb, "RIGHT", math.ceil(leak.cb.label:GetStringWidth()) + 24, 0)
    leak.censusCB:SetScript("OnEnter", function()
        GameTooltip:SetOwner(leak.censusCB, "ANCHOR_TOPLEFT", 0, 4)
        GameTooltip:AddLine("reload 後普查", 1, 1, 1)
        GameTooltip:AddLine("洩漏追蹤只分得出「插件 vs 暴雪」。這個更細：reload 當下把 _G 底下"
            .. "所有的表爬一遍，3 分鐘後再爬一次，列出是哪張表變大；同時記下這段期間"
            .. "建立框架／貼圖最多的程式碼位置。", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("勾了之後下次 /reload 才開始，reload 完站著不動約 4 分鐘。"
            .. "結果印在聊天視窗並存檔，跑完自動取消勾選。", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("代價：爬的過程每幀只用幾毫秒不會卡，但會暫時多佔幾十 MB；"
            .. "開始與結束各強制回收一次（頓半秒）。", 1, 0.6, 0.3, true)
        GameTooltip:Show()
    end)
    leak.censusCB:SetScript("OnLeave", function() GameTooltip:Hide() end)
    if HC then HC.onDone = function() leak.Refresh() end end

    leak.statusFS = ramPage:CreateFontString(nil, "OVERLAY")
    leak.statusFS:SetFontObject(W.fontSmall)
    leak.statusFS:SetPoint("TOPRIGHT", ramPage, "TOPRIGHT", -SIDE, RAM_CTRL_Y - 5)
    leak.statusFS:SetJustifyH("RIGHT")

    local box = W.CreateFrame(nil, ramPage)
    W.Stylize(box, { 0.08, 0.08, 0.08, 0.9 })
    box:SetPoint("TOPLEFT", SIDE, RAM_REPORT_Y)
    box:SetSize(innerW, RAM_REPORT_H)
    leak.lines = {}
    for i = 1, 3 do
        local fs = box:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(i == 1 and W.fontNormal or W.fontSmall)
        fs:SetPoint("TOPLEFT", 10, -6 - (i - 1) * 16)
        fs:SetWidth(innerW - 20)
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        leak.lines[i] = fs
    end
    -- 一行放不下的會被截掉，完整內容在工具提示（自動換行）
    box:EnableMouse(true)
    box:SetScript("OnEnter", function()
        GameTooltip:SetOwner(box, "ANCHOR_TOP")
        GameTooltip:AddLine("洩漏追蹤結論", 1, 1, 1)
        for i = 1, 3 do
            local t = leak.lines[i]:GetText()
            if t and t ~= "" then GameTooltip:AddLine(t, 0.8, 0.8, 0.8, true) end
        end
        GameTooltip:Show()
    end)
    box:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 新快照進來時分頁開著的話，順手用那次掃描的結果刷新清單（不再掃一次）
    if LT then
        LT.onSnapshot = function()
            if tab and tab:IsShown() and ramPage:IsShown() then
                MeasureMemory(true)
            end
            leak.Refresh()
        end
    end
end

local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    -- 卡片大字。具名字型一定要帶 NAMESPACE 前綴，撞名會被別的插件蓋掉
    valueFont = CreateFont(ns.WidgetsEnv.NAMESPACE .. "_FontPerfValue")
    valueFont:SetFont(MiliUI.Style.Font, 17, "")
    valueFont:SetTextColor(1, 1, 1)
    valueFont:SetShadowColor(0, 0, 0)
    valueFont:SetShadowOffset(1, -1)

    local title = W.CreateSectionTitle(tab, "效能監控", ns.Options.PANEL_W - 32)
    title:SetPoint("TOPLEFT", SIDE, -14)

    -- 靜態的環境資訊收在標題列右緣，不佔資料版面
    folderFS = tab:CreateFontString(nil, "OVERLAY")
    folderFS:SetFontObject(W.fontSmall)
    folderFS:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -SIDE, -18)
    folderFS:SetJustifyH("RIGHT")

    ------------------------------------------------------------
    -- 子分頁鈕：跟視窗頂端的分頁同一套視覺（accent-hover ＋ ButtonGroup 高亮）
    ------------------------------------------------------------
    local defs = { { id = "cpu", label = "CPU" }, { id = "ram", label = "記憶體" } }
    local prev, groupList = nil, {}
    for _, d in ipairs(defs) do
        local b = W.CreateButton(tab, d.label, "accent-hover", 76, SUB_H)
        b.id = d.id
        if prev then
            b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 4, 0)
        else
            b:SetPoint("TOPLEFT", SIDE, SUB_Y)
        end
        subTab.buttons[d.id] = b
        groupList[#groupList + 1] = b
        prev = b
    end
    subTab.Highlight = W.CreateButtonGroup(groupList, ShowPage)

    cpuPage = CreateFrame("Frame", nil, tab)
    cpuPage:SetPoint("TOPLEFT", 0, PAGE_TOP)
    cpuPage:SetPoint("BOTTOMRIGHT")
    ramPage = CreateFrame("Frame", nil, tab)
    ramPage:SetPoint("TOPLEFT", 0, PAGE_TOP)
    ramPage:SetPoint("BOTTOMRIGHT")
    ramPage:Hide()

    local innerW = ns.Options.PANEL_W - SIDE * 2

    ------------------------------------------------------------
    -- CPU 子頁
    ------------------------------------------------------------
    cards.cpu = CreatePanel(cpuPage, "幀時間")
    cards.cpu:SetSize(innerW, PANEL_H)
    cards.cpu:SetPoint("TOPLEFT", SIDE, 0)

    -- 佔比條：純數字看不出 48% 是多還是少，一條填一半的軌道看得出來
    cards.cpu.pctFS = cards.cpu:CreateFontString(nil, "OVERLAY")
    cards.cpu.pctFS:SetFontObject(W.fontSmall)
    cards.cpu.pctFS:SetPoint("TOPLEFT", 10, ROW_GRAPH - 3)
    cards.cpu.pctFS:SetJustifyH("LEFT")

    cards.cpu.bar = W.CreateFrame(nil, cards.cpu)
    W.Stylize(cards.cpu.bar, { 0.13, 0.13, 0.14, 1 })
    cards.cpu.bar:SetPoint("TOPLEFT", 110, ROW_GRAPH)
    cards.cpu.bar:SetPoint("TOPRIGHT", -10, ROW_GRAPH)
    cards.cpu.bar:SetHeight(GRAPH_H - 5)
    cards.cpu.bar.fill = cards.cpu.bar:CreateTexture(nil, "ARTWORK")
    cards.cpu.bar.fill:SetColorTexture(W.Accent(0.75))
    cards.cpu.bar.fill:SetPoint("TOPLEFT")
    cards.cpu.bar.fill:SetPoint("BOTTOMLEFT")
    cards.cpu.bar.maxW = innerW - 120

    local metricLabel = cpuPage:CreateFontString(nil, "OVERLAY")
    metricLabel:SetFontObject(W.fontNormal)
    metricLabel:SetPoint("TOPLEFT", SIDE, CPU_CTRL_Y - 3)
    metricLabel:SetText("CPU 指標")

    local metricDD = W.CreateDropdown(cpuPage, 170, METRICS, function(value)
        DB().metric = value
        sortAcc = 0
        Refresh(true)
    end)
    metricDD:SetPoint("LEFT", metricLabel, "RIGHT", 8, 0)
    metricDD:SetSelectedValue(DB().metric)

    -- 卡頓記錄器住在 CPU 頁：它回答的是「剛剛那一幀是誰」，是時間的問題
    lagCB = W.CreateCheckButton(cpuPage, "卡頓記錄器", function(checked)
        if ns.LagWatch then ns.LagWatch.SetEnabled(checked) end
    end)
    lagCB:SetPoint("TOPRIGHT", cpuPage, "TOPRIGHT",
        -SIDE - math.ceil(lagCB.label:GetStringWidth()) - 8, CPU_CTRL_Y - 2)
    lagCB:SetScript("OnEnter", function()
        GameTooltip:SetOwner(lagCB, "ANCHOR_TOPLEFT", 0, 4)
        GameTooltip:AddLine("卡頓記錄器", 1, 1, 1)
        GameTooltip:AddLine(("某一幀超過 %d 毫秒時，自動記下那一幀每個插件"
            .. "各花了幾毫秒，並在聊天視窗點名主嫌（插件／GC 回收／遊戲引擎）。")
            :format(ns.LagWatch and ns.LagWatch.GetThreshold() or 250), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("平常每幀只做一次比較，開著沒有可感知的成本。", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("預設關閉 —— 它會主動在聊天視窗講話。要抓卡頓請先勾起來，"
            .. "關著的期間發生的卡頓抓不到。", 1, 0.6, 0.3, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("/miliui lag 看記錄｜lag <毫秒> 改門檻｜lag clear 清空", 0.5, 0.7, 1)
        GameTooltip:Show()
    end)
    lagCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 表頭：欄位幾何跟資料列共用 COL，捲軸那 20px 也要一起讓開才對得齊
    local header = CreateFrame("Frame", nil, cpuPage)
    header:SetPoint("TOPLEFT", SIDE, CPU_HEAD_Y)
    header:SetPoint("TOPRIGHT", cpuPage, "TOPRIGHT", -SIDE - SCROLL_W, CPU_HEAD_Y)
    header:SetHeight(16)

    local nameCell = CreateHeaderCell(header, "名稱", "name", "LEFT", 120, OnHeaderClick)
    nameCell:SetPoint("LEFT", COL.NAME_L, 0)

    local cpuCell = CreateHeaderCell(header, "CPU 毫秒", "cpu", "RIGHT", 100, OnHeaderClick)
    cpuCell:SetPoint("RIGHT", header, "RIGHT", COL.CPU_R, 0)

    local pctLabel = header:CreateFontString(nil, "OVERLAY")
    pctLabel:SetFontObject(W.fontSmall)
    pctLabel:SetTextColor(0.6, 0.6, 0.6)
    pctLabel:SetPoint("RIGHT", header, "RIGHT", COL.PCT_R, 0)
    pctLabel:SetText("佔遊戲")

    local memCell = CreateHeaderCell(header, "記憶體 MB", "mem", "RIGHT", 70, OnHeaderClick)
    memCell:SetPoint("RIGHT", header, "RIGHT", COL.MEM_R, 0)

    local headLine = header:CreateTexture(nil, "ARTWORK")
    headLine:SetColorTexture(W.Accent(0.3))
    headLine:SetPoint("BOTTOMLEFT", 0, -3)
    headLine:SetPoint("BOTTOMRIGHT", 0, -3)
    headLine:SetHeight(P.Scale(1))

    list = W.CreateRowList(cpuPage, 1, 1, ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", SIDE, CPU_LIST_TOP)
    list:SetPoint("BOTTOMRIGHT", cpuPage, "BOTTOMRIGHT", -SIDE, LIST_BOT)
    list.updateRow = UpdateRow

    -- 分析器被關掉的話 CPU 整欄都是 0，講一聲比讓玩家以為插件都不吃 CPU 好。
    -- ⚠ 警語得住在自己的 frame 裡：字掛在頁框上的話會被清單的列（子 frame）
    --   蓋掉 —— 子 frame 永遠畫在父層貼圖之上，調 DrawLayer 沒用。
    warnBox = W.CreateFrame(nil, cpuPage)
    W.Stylize(warnBox, { 0.14, 0.06, 0.06, 1 })
    warnBox:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
    warnBox:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, 0)
    warnBox:SetHeight(26)
    warnBox:SetFrameLevel(cpuPage:GetFrameLevel() + 20)
    warnBox:Hide()

    local warnFS = warnBox:CreateFontString(nil, "OVERLAY")
    warnFS:SetFontObject(W.fontNormal)
    warnFS:SetPoint("CENTER")
    warnFS:SetText("|cffff5555這個客戶端沒有啟用插件分析器，CPU 數據無法取得（記憶體仍可測量）。|r")

    local cpuFooter = cpuPage:CreateFontString(nil, "OVERLAY")
    cpuFooter:SetFontObject(W.fontSmall)
    cpuFooter:SetPoint("BOTTOMLEFT", SIDE + 2, FOOT_Y)
    cpuFooter:SetWidth(innerW - 4)
    cpuFooter:SetJustifyH("LEFT")
    cpuFooter:SetText("|cff888888CPU 由遊戲內建的分析器直接提供，開著這一頁不會讓遊戲變慢。"
        .. "點欄名換排序；滑鼠移到列上看資料夾明細與卡頓次數。|r")

    ------------------------------------------------------------
    -- 記憶體子頁
    ------------------------------------------------------------
    cards.mem = CreatePanel(ramPage, "Lua 記憶體")
    cards.mem:SetSize(innerW, PANEL_H)
    cards.mem:SetPoint("TOPLEFT", SIDE, 0)
    cards.mem.comp = PanelGraphArea(cards.mem)
    cards.mem.comp.fill = cards.mem.comp:CreateTexture(nil, "ARTWORK")
    cards.mem.comp.fill:SetColorTexture(W.Accent(0.75))
    cards.mem.comp.fill:SetPoint("TOPLEFT")
    cards.mem.comp.fill:SetPoint("BOTTOMLEFT")
    cards.mem.comp:EnableMouse(true)
    cards.mem.comp:SetScript("OnEnter", function()
        GameTooltip:SetOwner(cards.mem.comp, "ANCHOR_TOP")
        GameTooltip:AddLine("總量的構成", 1, 1, 1)
        GameTooltip:AddLine("亮的那段是歸戶給插件的合計；其餘是暴雪 UI 本體與"
            .. "歸不了戶的部分（10.1 起暴雪模組直接拒絕查詢），加上還沒被 GC "
            .. "收走的浮動垃圾。", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    cards.mem.comp:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 走勢圖：放大版，有自己的標籤列
    local trendLbl = ramPage:CreateFontString(nil, "OVERLAY")
    trendLbl:SetFontObject(W.fontSmall)
    trendLbl:SetPoint("TOPLEFT", SIDE, RAM_TRENDLBL_Y)
    trendLbl:SetText("記憶體趨勢")

    trend.rangeFS = ramPage:CreateFontString(nil, "OVERLAY")
    trend.rangeFS:SetFontObject(W.fontSmall)
    trend.rangeFS:SetPoint("LEFT", trendLbl, "RIGHT", 8, 0)

    trend.verdictFS = ramPage:CreateFontString(nil, "OVERLAY")
    trend.verdictFS:SetFontObject(W.fontSmall)
    trend.verdictFS:SetPoint("TOPRIGHT", ramPage, "TOPRIGHT", -SIDE, RAM_TRENDLBL_Y)
    trend.verdictFS:SetJustifyH("RIGHT")

    graph = { cols = {} }
    graph.plot = W.CreateFrame(nil, ramPage)
    W.Stylize(graph.plot, { 0.09, 0.09, 0.10, 1 })
    graph.plot:SetPoint("TOPLEFT", SIDE, RAM_PLOT_Y)
    graph.plot:SetPoint("TOPRIGHT", ramPage, "TOPRIGHT", -SIDE, RAM_PLOT_Y)
    graph.plot:SetHeight(RAM_PLOT_H)

    -- 說明住在工具提示：這段話只有第一次看的人需要，讓它常駐佔版面不划算
    graph.plot:EnableMouse(true)
    graph.plot:SetScript("OnEnter", function()
        GameTooltip:SetOwner(graph.plot, "ANCHOR_TOP")
        GameTooltip:AddLine("記憶體趨勢", 1, 1, 1)
        GameTooltip:AddLine("每分鐘記一點，值是那一分鐘的最低點 —— 最低點最接近"
            .. "「活資料」，浮動的垃圾不會抬高它，洩漏會。", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("記憶體大不大要看斜率不是數值：平穩就沒事（六十幾個插件"
            .. "的重裝停在 6 百多 MB 是常態），持續往上爬才是洩漏。", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("縱軸自動縮放，範圍在左上角；曲線只記這次登入，"
            .. "不需要開任何選項，一直都在記。", 0.6, 0.6, 0.6, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("/miliui heap 可以在聊天視窗看同一份資料", 0.5, 0.7, 1)
        GameTooltip:Show()
    end)
    graph.plot:SetScript("OnLeave", function() GameTooltip:Hide() end)

    graph.emptyFS = graph.plot:CreateFontString(nil, "OVERLAY")
    graph.emptyFS:SetFontObject(W.fontSmall)
    graph.emptyFS:SetPoint("CENTER")

    -- 控制列：管記憶體的按鈕住在記憶體頁，跟它管的東西在一起
    local measureBtn = W.CreateButton(ramPage, "重新測量記憶體", "accent", 120, 22)
    measureBtn:SetPoint("TOPLEFT", SIDE, RAM_CTRL_Y)
    measureBtn:SetScript("OnClick", function()
        MeasureMemory()
    end)

    leak.Build(measureBtn, innerW)

    -- 記憶體清單：固定 MB 由大到小，只在測量後才變，所以表頭是靜態標籤不是按鈕
    local memHeader = CreateFrame("Frame", nil, ramPage)
    memHeader:SetPoint("TOPLEFT", SIDE, RAM_HEAD_Y)
    memHeader:SetPoint("TOPRIGHT", ramPage, "TOPRIGHT", -SIDE - SCROLL_W, RAM_HEAD_Y)
    memHeader:SetHeight(16)

    local function MemHeadLabel(text, right, justify)
        local fs = memHeader:CreateFontString(nil, "OVERLAY")
        fs:SetFontObject(W.fontSmall)
        fs:SetTextColor(0.6, 0.6, 0.6)
        if justify == "LEFT" then
            fs:SetPoint("LEFT", right, 0)
        else
            fs:SetPoint("RIGHT", memHeader, "RIGHT", right, 0)
        end
        fs:SetText(text)
        return fs
    end
    MemHeadLabel("名稱", COL2.NAME_L, "LEFT")
    MemHeadLabel("記憶體 MB", COL2.MEM_R)
    MemHeadLabel("變化", COL2.DELTA_R)
    leak.head = MemHeadLabel("每小時", COL2.GROWTH_R)
    MemHeadLabel("佔插件", COL2.SHARE_R)

    local memHeadLine = memHeader:CreateTexture(nil, "ARTWORK")
    memHeadLine:SetColorTexture(W.Accent(0.3))
    memHeadLine:SetPoint("BOTTOMLEFT", 0, -3)
    memHeadLine:SetPoint("BOTTOMRIGHT", 0, -3)
    memHeadLine:SetHeight(P.Scale(1))

    memList = W.CreateRowList(ramPage, 1, 1, ROW_H, BuildMemRow)
    memList:SetPoint("TOPLEFT", SIDE, RAM_LIST_TOP)
    memList:SetPoint("BOTTOMRIGHT", ramPage, "BOTTOMRIGHT", -SIDE, LIST_BOT)

    local ramFooter = ramPage:CreateFontString(nil, "OVERLAY")
    ramFooter:SetFontObject(W.fontSmall)
    ramFooter:SetPoint("BOTTOMLEFT", SIDE + 2, FOOT_Y)
    ramFooter:SetWidth(innerW - 4)
    ramFooter:SetJustifyH("LEFT")
    ramFooter:SetText("|cff888888記憶體要掃過整個 Lua 堆才分得出是誰用的，所以只在測量時更新。"
        .. "「變化」是跟上一次測量比 —— 佔用大而不動的是資料庫，持續爬升的才要追。"
        .. "「每小時」是洩漏追蹤在回收後的快照上算的成長速度，有結論後清單照它排。|r")

    -- ⚠ 清單底部跟著註腳的**實際**高度走，不要用寫死的「頁尾一行」常數：
    -- 這段文字長到換兩行的時候就會被清單的最後幾列蓋住（2026-08-30 踩過）。
    -- 量過再錨，之後改文字也不會再撞。
    memList:SetPoint("BOTTOMRIGHT", ramPage, "BOTTOMRIGHT", -SIDE,
        FOOT_Y + math.ceil(ramFooter:GetStringHeight()) + 8)

    -- 昂貴的記憶體測量延到下一幀：先讓分頁畫出來，玩家才不會覺得「點分頁卡一下」
    tab:SetScript("OnShow", function()
        RunNextFrame(function()
            if not (tab and tab:IsShown()) then return end
            MeasureMemory()
            if cpuPage:IsShown() then Refresh(true) end
        end)
    end)
    tab:SetScript("OnUpdate", OnTabUpdate)
end

-- 對外入口（跨插件，例如 MiliUI_InfoBar 的 CPU／記憶體方塊）：開設定視窗到
-- 效能監控並選好子分頁。sub = "cpu"／"ram"，其他值＝上次看的那頁。
-- 先寫 DB().page 再開窗：ShowOptionsTab 的處理最後會 ShowPage(DB().page)，
-- 順著原本的流程走，不用碰子分頁鈕的高亮。
function ns.OpenPerfPage(sub)
    if sub == "cpu" or sub == "ram" then
        DB().page = sub
    end
    ns.OpenOptions("perf")
end

ns.RegisterCallback("ShowOptionsTab", "perfTab", function(id)
    if id ~= "perf" then
        if tab then tab:Hide() end
        return
    end
    Init()

    hasProfiler = ProfilerAvailable()
    warnBox:SetShown(not hasProfiler)
    lagCB:SetChecked(ns.LagWatch and ns.LagWatch.IsEnabled() or false)

    RebuildEntries()
    -- 記憶體重新量：每次開分頁都當作沒量過，免得顯示的是上次開窗留下的舊數字。
    -- 「上一次」的快照也一起丟 —— 隔了一個開窗週期的差值沒有意義
    memStamp = nil
    wipe(memKB)
    wipe(memPrevKB)
    memHasPrev = false
    RebuildMemEntries()
    valueAcc, sortAcc = 0, 0
    RefreshHeaders()
    graphRev = -1
    ShowPage(DB().page)
    tab:Show()
end)
