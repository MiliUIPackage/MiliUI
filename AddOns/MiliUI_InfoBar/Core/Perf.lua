------------------------------------------------------------
-- 自家的耗時計：每個進入點各記「最大一次、次數、超過 10 毫秒幾次、最後一次超過的時刻」
--
-- 效能監控分頁只能說「資訊列這場登入有一幀花了 100 毫秒」，說不出是哪一段。
-- 這裡把資訊列**所有**會執行 Lua 的入口（事件派送、脫戰佇列、版面、各個計時器、
-- UIParent 重貼）各包一層 debugprofilestop 差值，/mib perf 直接點名。
--
-- 成本紀律：常駐開著。每次派送多兩次 debugprofilestop（讀計數器）＋一次查表，
-- 沒有字串拼接（標籤在註冊時就算好）、沒有配置。高頻事件（UPDATE_UI_WIDGET）
-- 走同一條路也量不出差別。
--
-- 用法：
--   local t0 = ns.Perf.Begin()
--   ...
--   ns.Perf.End("標籤", t0)
------------------------------------------------------------
local ADDON, ns = ...

local clock = debugprofilestop
local BIG_MS = 10

local stats = {}          -- label -> { max, count, total, over, last }
local frameMeasured = 0   -- 這個幀窗口內量到的合計（給下面的 watch 對帳用）

ns.Perf = {}
local Perf = ns.Perf

function Perf.Begin()
    return clock()
end

function Perf.End(label, t0)
    local ms = clock() - t0
    local s = stats[label]
    if not s then
        s = { max = 0, count = 0, total = 0, over = 0 }
        stats[label] = s
    end
    s.count = s.count + 1
    s.total = s.total + ms
    frameMeasured = frameMeasured + ms
    if ms > s.max then s.max = ms end
    if ms >= BIG_MS then
        s.over = s.over + 1
        s.last = date("%H:%M:%S")
    end
end

------------------------------------------------------------
-- 對帳：/mib perf watch
--
-- 每幀讀一次官方分析器的 LastTime（上一幀算在本插件頭上的毫秒數，讀值免費），
-- 超過 10 毫秒就記下「那一幀官方說 X 毫秒、我們自己量到 Y 毫秒」。Y 接近 0 就是
-- **沒被包到的入口**（或根本不是我們的 Lua，例如 GC 步驟落在我們的配置上）。
-- 這是唯一會每幀進 Lua 的東西，所以預設關、只在查問題時開，而且不存檔。
------------------------------------------------------------
local spikes = {}          -- 最近 10 筆 { at, ms, measured, heapDelta }
local prevMeasured = 0
local prevHeapKB = 0       -- 上一幀的 collectgarbage("count")；一幀掉幾十 MB 就是 GC 收尾
local watcher

local function LastTime()
    local E = Enum and Enum.AddOnProfilerMetric
    if not (E and E.LastTime and C_AddOnProfiler and C_AddOnProfiler.GetAddOnMetric) then return 0 end
    local ok, v = pcall(C_AddOnProfiler.GetAddOnMetric, ADDON, E.LastTime)
    if ok and type(v) == "number" and v == v and v ~= math.huge then return v end
    return 0
end

function Perf.SetWatch(on)
    if on then
        if not watcher then
            watcher = CreateFrame("Frame")
            watcher:SetScript("OnUpdate", function()
                local last = LastTime()
                local heapKB = collectgarbage("count")
                -- LastTime 是上一幀的帳；上一幀的事件在上一個 OnUpdate 之前派送、
                -- 計時器在之後，兩個窗口取大的那個當「我們量到的」
                local measured = math.max(prevMeasured, frameMeasured)
                if last >= BIG_MS then
                    spikes[#spikes + 1] = {
                        at = date("%H:%M:%S"), ms = last, measured = measured,
                        heapDelta = (heapKB - prevHeapKB) / 1024,
                    }
                    if #spikes > 10 then table.remove(spikes, 1) end
                end
                prevMeasured, frameMeasured = frameMeasured, 0
                prevHeapKB = heapKB
            end)
        end
        watcher:Show()
    elseif watcher then
        watcher:Hide()
    end
end

function Perf.IsWatching()
    return watcher ~= nil and watcher:IsShown()
end

function Perf.Reset()
    wipe(stats)
    wipe(spikes)
end

-- /mib perf：依最大一次降冪，前 limit 名
function Perf.Report(limit)
    limit = limit or 15
    local list = {}
    for label, s in pairs(stats) do
        list[#list + 1] = { label = label, s = s }
    end
    table.sort(list, function(a, b)
        if a.s.max ~= b.s.max then return a.s.max > b.s.max end
        return a.label < b.label
    end)
    print(ns.PREFIX_COLOR .. "MiliUI_InfoBar perf|r（最大一次｜次數｜≥10ms 次數｜合計｜最後一次 ≥10ms）")
    if #list == 0 then
        print("  還沒有記錄")
        return
    end
    for i = 1, math.min(limit, #list) do
        local e = list[i]
        local s = e.s
        local color = s.max >= 50 and "|cffff5555" or s.max >= BIG_MS and "|cffffaa33" or "|cffcccccc"
        print(string.format("  %s%6.1f ms|r  x%-4d  ≥10ms:%-3d  合計 %6.1f ms  %s  %s",
            color, s.max, s.count, s.over, s.total, s.last or "        ", e.label))
    end
    if Perf.IsWatching() then
        print("  對帳（官方 LastTime ≥10ms 的幀｜我們自己量到的）：")
        if #spikes == 0 then
            print("    開著對帳以來沒有 ≥10ms 的幀")
        end
        for _, sp in ipairs(spikes) do
            local verdict = sp.measured >= sp.ms * 0.5 and "在包到的入口裡"
                or sp.measured >= 1 and "只包到一部分" or "|cffff5555沒包到的入口／不是我們的 Lua|r"
            if (sp.heapDelta or 0) <= -5 then
                verdict = verdict .. string.format("，堆掉了 %.0f MB → GC 收尾落在我們頭上", -sp.heapDelta)
            end
            print(string.format("    %s  官方 %6.1f ms  量到 %5.1f ms  堆 %+.1f MB  %s",
                sp.at, sp.ms, sp.measured, sp.heapDelta or 0, verdict))
        end
    else
        print("  （/mib perf watch 可開啟逐幀對帳，找沒包到的入口）")
    end
end
