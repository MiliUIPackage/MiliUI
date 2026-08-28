------------------------------------------------------------
-- Lua 堆成長曲線
--
-- 「記憶體用得多不多」的答案不在數值而在**斜率**：六十幾個插件的重裝穩在
-- 6 百多 MB 是常態，同一場遊戲從 400 爬到 900 才是洩漏。所以這支常駐取樣、
-- 畫在效能監控分頁上，不跟任何開關綁定。
--
-- 成本：每秒一次 collectgarbage("count")（純讀計數器的 C 呼叫，不觸發回收）。
-- 刻意不用每幀取樣 —— 每分鐘只留一個點，1 Hz 的六十個樣本早就足夠找到谷底，
-- 而每幀是它的六十倍成本換不到解析度。
--
-- ⚠ 存的是**每分鐘的最低點**，不是當下值。取樣點會被浮動垃圾推高幾十 MB，
--   照著畫是一條鋸齒線，看不出趨勢。最低點最接近「活資料」——洩漏會抬高地板，
--   垃圾不會 —— 取最小值等於免費做了一次趨勢濾波。
-- ⚠ 不進 SavedVariables：/reload 會重建整個 Lua 狀態，跨 reload 比較沒有意義。
--   曲線的壽命就是這次登入，這是誠實的範圍。
------------------------------------------------------------
local _, ns = ...

local SAMPLE_SEC = 1            -- 取樣間隔
local BUCKET_SEC = 60           -- 每個資料點涵蓋的秒數
local MAX_POINTS = 180          -- 保留 3 小時，比任何一場遊戲長
local MIN_SPAN_MIN = 15         -- 短於這個時間的斜率只當參考值

local HT = {}
ns.HeapTrack = HT

local samples = {}              -- { {t = 起算後秒數, kb = 該分鐘最低點}, ... }
local floorKB                   -- 本分鐘看過的最低點
local startTime, bucketEnd
local revision = 0              -- 有新點就 +1，畫圖端用它判斷要不要重畫

local function Sample()
    local kb = collectgarbage("count")
    if not floorKB or kb < floorKB then floorKB = kb end

    local now = GetTime()
    if now < bucketEnd then return end

    samples[#samples + 1] = { t = now - startTime, kb = floorKB }
    floorKB = nil
    bucketEnd = now + BUCKET_SEC
    while #samples > MAX_POINTS do table.remove(samples, 1) end
    revision = revision + 1
end

function HT.GetSamples() return samples end
function HT.GetRevision() return revision end
function HT.GetCurrentMB() return collectgarbage("count") / 1024 end

function HT.Reset()
    wipe(samples)
    floorKB = nil
    startTime = GetTime()
    bucketEnd = startTime + BUCKET_SEC
    revision = revision + 1
end

-- 斜率用頭尾各三分之一的**均值**比，不用單點：單一取樣點會被「剛好落在 GC
-- 前後」主導，那是相位不是趨勢。回傳 nil＝樣本還不夠，呼叫端自己顯示累積中。
function HT.GetTrend()
    local n = #samples
    if n < 3 then return nil end

    local lo, hi = samples[1].kb, samples[1].kb
    for i = 1, n do
        local kb = samples[i].kb
        if kb < lo then lo = kb end
        if kb > hi then hi = kb end
    end

    local third = math.max(1, math.floor(n / 3))
    local headSum, tailSum = 0, 0
    for i = 1, third do headSum = headSum + samples[i].kb end
    for i = n - third + 1, n do tailSum = tailSum + samples[i].kb end
    local headMB = headSum / third / 1024
    local tailMB = tailSum / third / 1024

    local spanMin = (samples[n].t - samples[1].t) / 60
    -- 判準走「每小時多少 MB」而不是總增量：玩 20 分鐘漲 60MB 跟玩 3 小時漲
    -- 60MB 是完全不同的兩件事
    local perHour = spanMin > 0 and ((tailMB - headMB) / spanMin * 60) or 0

    local level, text
    if spanMin < MIN_SPAN_MIN then
        level, text = "unsure", ("時間還短（%d 分鐘），趨勢僅供參考"):format(math.floor(spanMin + 0.5))
    elseif perHour >= 100 then
        level, text = "bad", ("每小時 +%.0f MB —— 洩漏的量級，值得追"):format(perHour)
    elseif perHour >= 30 then
        level, text = "warn", ("每小時 +%.0f MB —— 偏高，再觀察一小時"):format(perHour)
    else
        level, text = "good", ("每小時 %+.0f MB —— 穩定"):format(perHour)
    end

    return {
        loMB = lo / 1024, hiMB = hi / 1024,
        headMB = headMB, tailMB = tailMB,
        spanMin = spanMin, perHour = perHour,
        level = level, text = text,
    }
end

------------------------------------------------------------
-- 文字報告 -> /miliui heap（效能監控分頁畫的是同一份資料）
------------------------------------------------------------
local SPARK = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" }

function HT.Report()
    local nowMB = HT.GetCurrentMB()
    local t = HT.GetTrend()
    if not t then
        ns.Print(("Lua 堆目前 %.0f MB。取樣還不夠（每分鐘一點，已有 %d 點）—— "
            .. "玩個 20 分鐘以上再回來看趨勢。"):format(nowMB, #samples))
        return
    end

    local range = math.max(t.hiMB - t.loMB, 1)
    local bars = {}
    for i = 1, #samples do
        local mb = samples[i].kb / 1024
        bars[i] = SPARK[math.floor((mb - t.loMB) / range * (#SPARK - 1) + 0.5) + 1]
    end

    local colour = (t.level == "bad" and "|cffff5555")
        or (t.level == "warn" and "|cffff9900")
        or (t.level == "good" and "|cff33ff66") or "|cff888888"

    ns.Print(("Lua 堆成長曲線（%d 分鐘、%d 個取樣點，記的是每分鐘活資料下界）："):format(
        math.floor(t.spanMin + 0.5), #samples))
    print("  " .. table.concat(bars))
    print(("  範圍 %.0f ～ %.0f MB｜目前 %.0f MB｜前段均值 %.0f → 後段均值 %.0f"):format(
        t.loMB, t.hiMB, nowMB, t.headMB, t.tailMB))
    print(("  %s%s|r"):format(colour, t.text))
end

startTime = GetTime()
bucketEnd = startTime + BUCKET_SEC
C_Timer.NewTicker(SAMPLE_SEC, Sample)
