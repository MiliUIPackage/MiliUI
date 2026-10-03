------------------------------------------------------------
-- 診斷記錄：引擎發現「現況跟預期不一樣」時記一行，留在存檔裡
--
-- 冷卻管理器的毛病多半是「不報錯但畫面壞了」（進副本、被系統換專精、暴雪重建整條檢視器），
-- 發生當下沒有任何 Lua 錯誤可以看，事後也重現不了。所以引擎每次自己修掉一個異常
-- （縮放被改、清單漏了暴雪正在顯示的法術、讀取畫面後重排…）就在這裡記一行，
-- 連同 /mcdm debug 的完整輸出一起存進 SavedVariables：
--
--   MiliUI_CooldownManager_DB.diag = {
--       log  = { "09-30 16:21:05 [adopt] utility ← 19397, 19393", … },   最近 LOG_MAX 行（跨登入保留）
--       dump = { … },  dumpAt = "09-30 16:30:12",                          上一次 /mcdm debug 的輸出
--       perf = { … },  perfAt = "…",                                       上一次 /mcdm perf 的輸出
--   }
--
--   ns.Diag.Note(kind, text)   記一行。跟上一行一模一樣就只累計次數，不洗版
--   ns.Diag.Lines(n)           最近 n 行（新 → 舊），給 /mcdm debug 印
--   ns.Diag.SaveDump(lines)    存 /mcdm debug 的輸出
--   ns.Diag.SavePerf(lines)    存 /mcdm perf 的輸出（另一個欄位：/mcdm debug 換掉 dump 時不會把它洗掉）
--   ns.Diag.Attach(sv)         DB 就緒後接上存檔（之前記的先放在記憶體裡）
--
-- 這支只記不修，修的動作在各模組；字串不進語系檔（開發用）。
------------------------------------------------------------
local _, ns = ...

ns.Diag = {}
local D = ns.Diag

local LOG_MAX = 120
local log = {}            -- 接上存檔之後就是存檔裡那張表
local lastText, lastIndex, repeats = nil, nil, 0

local function Stamp()
    local d = _G.date
    return d and d("%m-%d %H:%M:%S") or "?"
end

local function Push(line)
    log[#log + 1] = line
    while #log > LOG_MAX do table.remove(log, 1) end
    return #log
end

function D.Note(kind, text)
    text = "[" .. tostring(kind) .. "] " .. tostring(text)
    if text == lastText and lastIndex and log[lastIndex] then
        repeats = repeats + 1
        log[lastIndex] = ("%s %s ×%d"):format(Stamp(), text, repeats)
        return
    end
    lastText, repeats = text, 1
    lastIndex = Push(Stamp() .. " " .. text)
end

function D.Lines(n)
    local out = {}
    for i = #log, math.max(1, #log - (n or 10) + 1), -1 do out[#out + 1] = log[i] end
    return out
end

function D.Count() return #log end

function D.SaveDump(lines)
    local sv = _G.MiliUI_CooldownManager_DB
    if type(sv) ~= "table" or type(sv.diag) ~= "table" then return end
    sv.diag.dump = lines
    sv.diag.dumpAt = Stamp()
end

function D.SavePerf(lines)
    local sv = _G.MiliUI_CooldownManager_DB
    if type(sv) ~= "table" or type(sv.diag) ~= "table" then return end
    sv.diag.perf = lines
    sv.diag.perfAt = Stamp()
end

function D.Attach(sv)
    if type(sv) ~= "table" then return end
    local saved = type(sv.diag) == "table" and sv.diag or {}
    local old = type(saved.log) == "table" and saved.log or {}
    -- 舊的在前、這次登入到目前為止記的接在後面
    local pending = log
    log = {}
    for i = 1, #old do if type(old[i]) == "string" then Push(old[i]) end end
    Push(Stamp() .. " ── 登入／重載 ──")
    for i = 1, #pending do Push(pending[i]) end
    lastText, lastIndex = nil, nil
    saved.log = log
    sv.diag = saved
end
