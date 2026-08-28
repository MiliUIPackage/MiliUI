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
--           按「重新測量」，要嘛自己勾自動（預設關，而且戰鬥中不量）。
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
local CARD_Y     = -44
local CARD_H     = 48
local CARD_GAP   = 8
local CTRL_Y     = -100
local HEAD_Y     = -128
local LIST_TOP   = -150
-- 底部由下往上堆疊，每一段的高度與間距都具名：頁尾 → 走勢圖 → 標籤列 →
-- 分隔線，清單吃剩下的高度。這樣改圖高只要動 GRAPH_H，清單會自己讓位
-- （之前頁尾多加一行就直接壓到圖上，就是因為 GRAPH_BOT 是寫死的）。
local FOOT_Y     = 8            -- 頁尾離分頁底部
local FOOT_H     = 28           -- 頁尾兩行小字的實際高度
local GRAPH_GAP  = 10           -- 圖與頁尾之間
local GRAPH_H    = 38           -- 繪圖區高度
local GRAPH_LBL  = 14           -- 標籤列高度
local LBL_GAP    = 4            -- 標籤與圖之間
local SEC_GAP    = 8            -- 分隔線與標籤之間
local GRAPH_BOT  = FOOT_Y + FOOT_H + GRAPH_GAP
local LIST_BOT   = GRAPH_BOT + GRAPH_H + LBL_GAP + GRAPH_LBL + SEC_GAP
local ROW_H      = 22
local BAR_H      = 10           -- 長條圖高度（列高 22，上下各留 6）
-- 走勢圖 Y 軸的最小跨距。沒有下限的話自動縮放會把幾 MB 的正常呼吸畫成劇烈
-- 震盪 —— 穩定的堆就該看起來是平的，這是誠實不是美化。
local GRAPH_MIN_SPAN_MB = 60
local GRAPH_MIN_POINTS  = 3
local SCROLL_W   = 20           -- CreateScrollFrame 固定讓出的捲軸寬，表頭要跟著讓

local VALUE_TICK = 1            -- 數字重讀間隔（免費，只在分頁開著時跑）
local SORT_TICK  = 5            -- 重新排序間隔：每秒重排會讓列一直上下跳，根本讀不到
local MEM_TICK   = 5            -- 自動測量記憶體的間隔（要玩家自己勾才跑）

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

-- value 直接就是 Enum.AddOnProfilerMetric 的鍵名，不另外做一層對照表
local METRICS = {
    { value = "RecentAverageTime",    text = "近期平均（最近 60 幀）", avg = true },
    { value = "SessionAverageTime",   text = "本次登入平均",           avg = true },
    { value = "EncounterAverageTime", text = "首領戰平均",             avg = true },
    { value = "PeakTime",             text = "單幀尖峰" },
}

local SORTS = { cpu = true, mem = true, name = true }

local tab, list, stampFS, warnBox, lagCB, graph
local cards = {}
local headerCells = {}
local valueFont

local entries = {}              -- 攤平後的條目（一列一個插件，可含多個資料夾）
local memKB = {}                -- folder -> KB，測量過才有值
local memStamp                  -- 上次測量的 GetTime()，nil = 這次開窗還沒量過
local maxCPU, maxMem = 0, 0
local totalFolders, loadedFolders = 0, 0
local hasProfiler = false
local rendered = 0              -- 上次真的重排過的列數（見 Refresh）
local valueAcc, sortAcc, memAcc = 0, 0, 0
local graphRev = -1             -- 上次畫圖時的 HeapTrack 版號

-- 這兩個是 DB() 的快取。DB() 每次都要走訪 METRICS 驗證欄位，而這兩個值一個
-- 每幀讀（OnUpdate）、一個每列讀（MsColor）—— 直接查 DB 等於把驗證邏輯
-- 塞進最熱的迴圈裡。設定值改動的入口只有三個，同步在那裡做。
local autoMem = false
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
    if type(db.autoMem) ~= "boolean" then db.autoMem = false end
    return db
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
local function MeasureMemory()
    if type(UpdateAddOnMemoryUsage) ~= "function"
            or type(GetAddOnMemoryUsage) ~= "function" then
        return
    end
    UpdateAddOnMemoryUsage()
    wipe(memKB)
    for _, item in ipairs(entries) do
        for _, f in ipairs(item.folders) do
            memKB[f] = Num(pcall(GetAddOnMemoryUsage, f))
        end
    end
    memStamp = GetTime()
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

    totalFolders, loadedFolders = 0, 0
    for name in pairs(installed) do
        totalFolders = totalFolders + 1
        if C_AddOns.IsAddOnLoaded(name) then loadedFolders = loadedFolders + 1 end
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
-- 上方四張數字卡
------------------------------------------------------------
local function CreateCard(parent, caption)
    local card = W.CreateFrame(nil, parent, nil, nil)
    card:SetSize(10, CARD_H)
    W.Stylize(card, { 0.08, 0.08, 0.08, 0.9 })

    -- 左緣 3px 職業色直條：跟總覽選中列同一個視覺語彙
    local edge = card:CreateTexture(nil, "ARTWORK")
    edge:SetColorTexture(W.Accent(0.9))
    edge:SetPoint("TOPLEFT", 0, 0)
    edge:SetPoint("BOTTOMLEFT", 0, 0)
    edge:SetWidth(P.Scale(3))

    local cap = card:CreateFontString(nil, "OVERLAY")
    cap:SetFontObject(W.fontSmall)
    cap:SetPoint("TOPLEFT", 10, -7)
    cap:SetText("|cff999999" .. caption .. "|r")

    card.value = card:CreateFontString(nil, "OVERLAY")
    card.value:SetFontObject(valueFont)
    card.value:SetPoint("TOPLEFT", cap, "BOTTOMLEFT", 0, -3)
    card.value:SetJustifyH("LEFT")

    card.sub = card:CreateFontString(nil, "OVERLAY")
    card.sub:SetFontObject(W.fontSmall)
    card.sub:SetPoint("LEFT", card.value, "RIGHT", 5, -1)
    card.sub:SetJustifyH("LEFT")

    return card
end

local function RefreshCards()
    local metric = MetricEnum(DB().metric)
    local addonMs = GlobalMetric("GetOverallMetric", metric)
    local appMs   = GlobalMetric("GetApplicationMetric", metric)

    if hasProfiler then
        cards.cpu.value:SetText(MsColor(addonMs) .. FmtMs(addonMs) .. "|r")
        cards.cpu.sub:SetText(appMs > 0
            and ("|cff999999毫秒／幀　佔遊戲 %.1f%%|r"):format(addonMs / appMs * 100)
            or "|cff999999毫秒／幀|r")
    else
        cards.cpu.value:SetText("|cff666666—|r")
        cards.cpu.sub:SetText("|cff999999毫秒／幀|r")
    end

    local fps = GetFramerate() or 0
    cards.fps.value:SetText(("%d"):format(math.floor(fps + 0.5)))
    cards.fps.sub:SetText(appMs > 0
        and ("|cff999999FPS　每幀 %.1f 毫秒|r"):format(appMs)
        or "|cff999999FPS|r")

    -- 總量走 collectgarbage("count")：純讀計數器，跟昂貴的 UpdateAddOnMemoryUsage 無關
    cards.mem.value:SetText(FmtMB(collectgarbage("count")))
    if memStamp then
        local sum = 0
        for _, kb in pairs(memKB) do sum = sum + kb end
        cards.mem.sub:SetText(("|cff999999MB　插件合計 %s MB|r"):format(FmtMB(sum)))
    else
        cards.mem.sub:SetText("|cff999999MB|r")
    end

    cards.count.value:SetText(("%d"):format(loadedFolders))
    cards.count.sub:SetText(("|cff999999已載入　共 %d 個資料夾|r"):format(totalFolders))
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
-- Lua 堆走勢圖
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
        graph.emptyFS:SetText(("|cff666666累積中…每分鐘一個取樣點，已有 %d 點|r"):format(n))
        graph.emptyFS:Show()
        graph.rangeFS:SetText("")
        graph.verdictFS:SetText("")
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
    -- ⚠ 再把底部往下讓一截：Y 軸從最小值起算的話，最低的那一兩點會被畫成
    -- 零高度，看起來像「那段沒有資料」而不是「那段最低」。讓出 12% 之後
    -- 最低點仍有可見的一截。
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

    graph.rangeFS:SetText(("|cff888888%.0f – %.0f MB／%d 分鐘|r"):format(
        t.loMB, t.hiMB, math.floor(t.spanMin + 0.5)))
    local colour = (t.level == "bad" and "|cffff5555")
        or (t.level == "warn" and "|cffff9900")
        or (t.level == "good" and "|cff33ff66") or "|cff888888"
    graph.verdictFS:SetText(colour .. t.text .. "|r")
end

------------------------------------------------------------
-- 更新迴圈
------------------------------------------------------------
local function RefreshStamp()
    if not stampFS then return end
    if not memStamp then
        stampFS:SetText("|cff666666記憶體尚未測量|r")
        return
    end
    local ago = math.floor(GetTime() - memStamp)
    if ago < 2 then
        stampFS:SetText("|cff888888記憶體：剛剛測量|r")
    elseif ago < 60 then
        stampFS:SetText(("|cff888888記憶體：%d 秒前測量|r"):format(ago))
    else
        stampFS:SetText(("|cff888888記憶體：%d 分鐘前測量|r"):format(math.floor(ago / 60)))
    end
end

-- 順序沒動的那幾秒只重寫欄位文字，不走 list:Update ——
-- 那支每列都會 ClearAllPoints ＋兩次 SetPoint，六十列每秒重錨一次是白花的。
local function Refresh(resort)
    Recompute()
    if resort then Resort() end
    RefreshCards()
    RefreshStamp()
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
    -- 自動測量在戰鬥中停手：那一下的堆掃描是看得見的頓格，戰鬥中最不該發生
    if autoMem and not InCombatLockdown() then
        memAcc = memAcc + elapsed
        if memAcc >= MEM_TICK then
            memAcc = 0
            MeasureMemory()
        end
    end
    -- 走勢圖每分鐘才有新資料，用版號比對就好，不必每秒重畫幾十根貼圖
    local rev = ns.HeapTrack and ns.HeapTrack.GetRevision() or 0
    if rev ~= graphRev then
        graphRev = rev
        RefreshGraph()
    end

    if valueAcc < VALUE_TICK then return end
    valueAcc = 0
    local resort = (sortAcc >= SORT_TICK)
    if resort then sortAcc = 0 end
    Refresh(resort)
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

    ------------------------------------------------------------
    -- 數字卡
    ------------------------------------------------------------
    local cardW = (ns.Options.PANEL_W - SIDE * 2 - CARD_GAP * 3) / 4
    local defs = {
        { key = "cpu",   caption = "插件 CPU" },
        { key = "fps",   caption = "遊戲畫面" },
        { key = "mem",   caption = "Lua 記憶體" },
        { key = "count", caption = "插件資料夾" },
    }
    local prev
    for _, d in ipairs(defs) do
        local card = CreateCard(tab, d.caption)
        card:SetSize(cardW, CARD_H)
        if prev then
            card:SetPoint("TOPLEFT", prev, "TOPRIGHT", CARD_GAP, 0)
        else
            card:SetPoint("TOPLEFT", SIDE, CARD_Y)
        end
        cards[d.key] = card
        prev = card
    end

    ------------------------------------------------------------
    -- 控制列
    ------------------------------------------------------------
    local metricLabel = tab:CreateFontString(nil, "OVERLAY")
    metricLabel:SetFontObject(W.fontNormal)
    metricLabel:SetPoint("TOPLEFT", SIDE, CTRL_Y - 3)
    metricLabel:SetText("CPU 指標")

    local metricDD = W.CreateDropdown(tab, 170, METRICS, function(value)
        DB().metric = value
        sortAcc = 0
        Refresh(true)
    end)
    metricDD:SetPoint("LEFT", metricLabel, "RIGHT", 8, 0)
    metricDD:SetSelectedValue(DB().metric)

    local measureBtn = W.CreateButton(tab, "重新測量記憶體", "accent", 120, 22)
    measureBtn:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -SIDE, CTRL_Y)
    measureBtn:SetScript("OnClick", function()
        MeasureMemory()
        memAcc = 0
        Refresh(true)
    end)

    local autoCB = W.CreateCheckButton(tab, "每 5 秒自動測量", function(checked)
        DB().autoMem = checked
        autoMem = checked
        memAcc = 0
        if checked then
            -- 打勾的當下講一次就好：這是整頁唯一真的會花錢的動作，玩家該知道
            -- 代價再決定留不留著（工具提示只有滑過才看得到，不夠）
            ns.Print("自動測量每 5 秒掃描一次整個 Lua 堆，堆越大越貴，"
                .. "開著可能造成額外的細微頓格（戰鬥中會自動停手）。看完記得取消勾選。")
            MeasureMemory()
            Refresh(true)
        end
    end)
    -- 量標籤實際字寬來擺位：勾選框的標籤掛在框的右邊往按鈕方向長，
    -- 位移寫死的話換字型或改字就會疊到「重新測量記憶體」上
    autoCB:SetPoint("RIGHT", measureBtn, "LEFT",
        -(math.ceil(autoCB.label:GetStringWidth()) + 14), 0)
    autoCB:SetChecked(DB().autoMem)
    autoCB:SetScript("OnEnter", function()
        GameTooltip:SetOwner(autoCB, "ANCHOR_TOPLEFT", 0, 4)
        GameTooltip:AddLine("每 5 秒自動測量", 1, 1, 1)
        GameTooltip:AddLine("每 5 秒重新歸戶一次記憶體。用途：抓「數字持續爬升、"
            .. "過一陣子突然回落」的那幾列 —— 那是垃圾製造機，跟佔用大是兩回事。", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("這是整個 Lua 堆的掃描，堆越大越貴，開著可能造成額外的"
            .. "細微頓格。戰鬥中自動停手，分頁一關就停。", 1, 0.6, 0.3, true)
        GameTooltip:Show()
    end)
    autoCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- 卡頓記錄器的開關住在這一頁最順手：儀表板回答「誰平常吃最多」，
    -- 這顆回答「剛剛那一下是誰」。實作在 LagWatch.lua，指令 /miliui lag 同一組開關。
    lagCB = W.CreateCheckButton(tab, "卡頓記錄器", function(checked)
        if ns.LagWatch then ns.LagWatch.SetEnabled(checked) end
    end)
    lagCB:SetPoint("RIGHT", autoCB, "LEFT",
        -(math.ceil(lagCB.label:GetStringWidth()) + 18), 0)
    lagCB:SetScript("OnEnter", function()
        GameTooltip:SetOwner(lagCB, "ANCHOR_TOPLEFT", 0, 4)
        GameTooltip:AddLine("卡頓記錄器", 1, 1, 1)
        GameTooltip:AddLine(("某一幀超過 %d 毫秒時，自動記下那一幀每個插件"
            .. "各花了幾毫秒，並在聊天視窗點名主嫌（插件／GC 回收／遊戲引擎）。")
            :format(ns.LagWatch and ns.LagWatch.GetThreshold() or 250), 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("平常每幀只做一次比較，開著沒有可感知的成本。", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("/miliui lag 看記錄｜lag <毫秒> 改門檻｜lag clear 清空", 0.5, 0.7, 1)
        GameTooltip:Show()
    end)
    lagCB:SetScript("OnLeave", function() GameTooltip:Hide() end)

    stampFS = tab:CreateFontString(nil, "OVERLAY")
    stampFS:SetFontObject(W.fontSmall)
    stampFS:SetPoint("LEFT", metricDD, "RIGHT", 14, 0)
    stampFS:SetJustifyH("LEFT")

    ------------------------------------------------------------
    -- 表頭：欄位幾何跟資料列共用 COL，捲軸那 20px 也要一起讓開才對得齊
    ------------------------------------------------------------
    local header = CreateFrame("Frame", nil, tab)
    header:SetPoint("TOPLEFT", SIDE, HEAD_Y)
    header:SetPoint("TOPRIGHT", tab, "TOPRIGHT", -SIDE - SCROLL_W, HEAD_Y)
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

    ------------------------------------------------------------
    -- 清單
    ------------------------------------------------------------
    list = W.CreateRowList(tab, 1, 1, ROW_H, BuildRow)
    list:SetPoint("TOPLEFT", SIDE, LIST_TOP)
    list:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -SIDE, LIST_BOT)
    list.updateRow = UpdateRow

    -- 分析器被關掉的話 CPU 整欄都是 0，講一聲比讓玩家以為插件都不吃 CPU 好。
    -- ⚠ 警語得住在自己的 frame 裡：字掛在 tab 上的話會被清單的列（子 frame）
    --   蓋掉 —— 子 frame 永遠畫在父層貼圖之上，調 DrawLayer 沒用。
    warnBox = W.CreateFrame(nil, tab)
    W.Stylize(warnBox, { 0.14, 0.06, 0.06, 1 })
    warnBox:SetPoint("TOPLEFT", list, "TOPLEFT", 0, 0)
    warnBox:SetPoint("TOPRIGHT", list, "TOPRIGHT", 0, 0)
    warnBox:SetHeight(26)
    warnBox:SetFrameLevel(tab:GetFrameLevel() + 20)
    warnBox:Hide()

    local warnFS = warnBox:CreateFontString(nil, "OVERLAY")
    warnFS:SetFontObject(W.fontNormal)
    warnFS:SetPoint("CENTER")
    warnFS:SetText("|cffff5555這個客戶端沒有啟用插件分析器，CPU 數據無法取得（記憶體仍可測量）。|r")

    ------------------------------------------------------------
    -- Lua 堆走勢圖
    ------------------------------------------------------------
    graph = { cols = {} }

    -- 分隔線：讓走勢圖讀起來是「另一個區塊」而不是清單掉出來的東西。
    -- 比表頭那條再暗一階 —— 它分的是區塊，不是欄位。
    local sepLine = tab:CreateTexture(nil, "ARTWORK")
    sepLine:SetColorTexture(W.Accent(0.18))
    sepLine:SetPoint("BOTTOMLEFT", SIDE, LIST_BOT - SEC_GAP)
    sepLine:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -SIDE, LIST_BOT - SEC_GAP)
    sepLine:SetHeight(P.Scale(1))

    local labelY = GRAPH_BOT + GRAPH_H + LBL_GAP

    local graphLbl = tab:CreateFontString(nil, "OVERLAY")
    graphLbl:SetFontObject(W.fontSmall)
    graphLbl:SetPoint("BOTTOMLEFT", SIDE, labelY)
    graphLbl:SetText("Lua 記憶體趨勢")

    graph.rangeFS = tab:CreateFontString(nil, "OVERLAY")
    graph.rangeFS:SetFontObject(W.fontSmall)
    graph.rangeFS:SetPoint("LEFT", graphLbl, "RIGHT", 8, 0)

    -- 判決靠右：跟左邊的標題與範圍分開，玩家的視線只要掃右緣就能看結論
    graph.verdictFS = tab:CreateFontString(nil, "OVERLAY")
    graph.verdictFS:SetFontObject(W.fontSmall)
    graph.verdictFS:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -SIDE, labelY)
    graph.verdictFS:SetJustifyH("RIGHT")

    -- 繪圖區自己一個 frame：直條是它的子貼圖，SetSize 用原始單位跟欄位一致
    graph.plot = W.CreateFrame(nil, tab)
    W.Stylize(graph.plot, { 0.09, 0.09, 0.10, 1 })
    graph.plot:SetPoint("BOTTOMLEFT", SIDE, GRAPH_BOT)
    graph.plot:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -SIDE, GRAPH_BOT)
    graph.plot:SetHeight(GRAPH_H)

    -- 說明住在工具提示而不是頁尾：頁尾每多一行就把圖往上擠一行，而這段話
    -- 只有第一次看的人需要
    graph.plot:EnableMouse(true)
    graph.plot:SetScript("OnEnter", function()
        GameTooltip:SetOwner(graph.plot, "ANCHOR_TOP")
        GameTooltip:AddLine("Lua 記憶體趨勢", 1, 1, 1)
        GameTooltip:AddLine("每分鐘記一點，值是那一分鐘的最低點 —— 最低點最接近"
            .. "「活資料」，浮動的垃圾不會抬高它，洩漏會。", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("記憶體大不大要看斜率不是數值：平穩就沒事（六十幾個插件"
            .. "的重裝本來就是幾百 MB），持續往上爬才是洩漏。", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("縱軸是自動縮放的，範圍寫在左上角；曲線只記這次登入，"
            .. "不需要開任何選項，一直都在記。", 0.6, 0.6, 0.6, true)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("/miliui heap 可以在聊天視窗看同一份資料", 0.5, 0.7, 1)
        GameTooltip:Show()
    end)
    graph.plot:SetScript("OnLeave", function() GameTooltip:Hide() end)

    graph.emptyFS = graph.plot:CreateFontString(nil, "OVERLAY")
    graph.emptyFS:SetFontObject(W.fontSmall)
    graph.emptyFS:SetPoint("CENTER")

    ------------------------------------------------------------
    -- 底部說明
    ------------------------------------------------------------
    local footer = tab:CreateFontString(nil, "OVERLAY")
    footer:SetFontObject(W.fontSmall)
    footer:SetPoint("BOTTOMLEFT", SIDE + 2, FOOT_Y)
    footer:SetWidth(ns.Options.PANEL_W - SIDE * 2 - 4)
    footer:SetJustifyH("LEFT")
    footer:SetSpacing(2)
    footer:SetText("|cff888888CPU 由遊戲內建的分析器直接提供，開著這一頁不會讓遊戲變慢；"
        .. "記憶體要掃過整個 Lua 堆才分得出是誰用的，所以只在開啟分頁時量一次。\n"
        .. "點欄名可以換排序；滑鼠移到一列或走勢圖可以看更多說明。|r")

    RefreshHeaders()

    -- 昂貴的記憶體測量延到下一幀：先讓分頁畫出來，玩家才不會覺得「點分頁卡一下」
    tab:SetScript("OnShow", function()
        RunNextFrame(function()
            if not (tab and tab:IsShown()) then return end
            MeasureMemory()
            Refresh(true)
        end)
    end)
    tab:SetScript("OnUpdate", OnTabUpdate)
end

ns.RegisterCallback("ShowOptionsTab", "perfTab", function(id)
    if id ~= "perf" then
        if tab then tab:Hide() end
        return
    end
    Init()

    hasProfiler = ProfilerAvailable()
    warnBox:SetShown(not hasProfiler)
    autoMem = DB().autoMem
    lagCB:SetChecked(ns.LagWatch and ns.LagWatch.IsEnabled() or false)

    RebuildEntries()
    -- 記憶體重新量：每次開分頁都當作沒量過，免得顯示的是上次開窗留下的舊數字
    memStamp = nil
    wipe(memKB)
    valueAcc, sortAcc, memAcc = 0, 0, 0
    Refresh(true)
    -- 版號歸零強制重畫：分頁可能關了一小時，那期間累積的點都還沒畫過
    graphRev = -1
    tab:Show()
end)
