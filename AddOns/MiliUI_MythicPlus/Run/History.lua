------------------------------------------------------------
-- 場次庫：存、裁、查、假資料
--
-- `db.runs` 是陣列，**最新的在前**（面板與下拉都從第 1 筆開始讀，不必反著走），
-- 超過 `db.historyCap` 就裁尾。
--
-- ⚠ 每一筆 run 都是**純資料**：只有數字、字串、布林與它們組成的表。
--   這是硬性要求，不是風格 —— SavedVariables 是靠 Lua 序列化寫檔的，塞進 frame、
--   函式或秘密值的話，輕則那一筆寫不出去，重則整個存檔壞掉。
--   所有寫入點在 Run/Snapshot.lua 與 Run/Recorder.lua 已經過守衛，這裡不重複洗。
------------------------------------------------------------
local _, ns = ...

ns.History = {}
local H = ns.History

local L = ns.L

H.RUN_VERSION = 1

------------------------------------------------------------
-- 裁切
------------------------------------------------------------
function H.Trim()
    local db = ns.db
    if not db or type(db.runs) ~= "table" then return end
    local cap = tonumber(db.historyCap) or 50
    while #db.runs > cap do
        table.remove(db.runs)
    end
end

------------------------------------------------------------
-- 修復「被加成兩倍」的舊記錄
--
-- 0.1.0 最早的版本把暴雪的整趟合併分段跟逐場分段一起加總，每個總量（連戰鬥秒數）
-- 剛好是兩倍。指紋很硬：**戰鬥秒數比整趟的牆鐘時間還長** —— 那在物理上不可能。
-- 符合的就把所有總量減半；每秒值是「總量 ÷ 秒數」，兩邊同乘 2 互相抵銷，不必動。
-- 修過的標 statsSource = "combined"（減半之後剩下的正是合併分段那一份）。
------------------------------------------------------------
local HALVE_FIELDS = { "dmg", "heal", "taken", "avoidable", "enemyTaken", "interrupts", "dispels", "deaths" }

function H.RepairDoubled()
    local db = ns.db
    if not db or type(db.runs) ~= "table" then return end
    for _, run in ipairs(db.runs) do
        local sec, ms = tonumber(run.combatSec), tonumber(run.timeMs)
        if run.statsSource == "sessions" and sec and ms and sec * 1000 > ms
            and type(run.players) == "table" then
            for _, p in ipairs(run.players) do
                for _, f in ipairs(HALVE_FIELDS) do
                    if type(p[f]) == "number" then p[f] = p[f] / 2 end
                end
            end
            run.combatSec = sec / 2
            run.statsSource = "combined"
        end
    end
end

------------------------------------------------------------
-- 新增一筆（最新的在前）
------------------------------------------------------------
function H.Add(run)
    local db = ns.db
    if not db or type(run) ~= "table" then return end
    table.insert(db.runs, 1, run)
    H.Trim()
    return run
end

function H.Count()
    local db = ns.db
    return (db and type(db.runs) == "table") and #db.runs or 0
end

function H.Get(index)
    local db = ns.db
    if not db or type(db.runs) ~= "table" then return nil end
    return db.runs[index]
end

function H.Latest()
    return H.Get(1)
end

function H.Clear()
    local db = ns.db
    if not db then return end
    wipe(db.runs)
end

------------------------------------------------------------
-- 顯示用的衍生值
--
-- ⚠ 一律現算、不存。副本名與稀有度色都會隨賽季／語系變，存下來的舊值以後會對不上。
------------------------------------------------------------

-- 副本名：優先問 API（客戶端語系正確），問不到才退存檔裡那份備援
function H.MapName(run)
    if not run then return "" end
    local id = tonumber(run.mapID)
    if id and C_ChallengeMode and C_ChallengeMode.GetMapUIInfo then
        local name = ns.Secret.PlainText(ns.Secret.SafeCall(C_ChallengeMode.GetMapUIInfo, id))
        if name and name ~= "" then return name end
    end
    return run.mapName or ""
end

-- 結果：+1 / +2 / +3 或「超時」
function H.ResultText(run)
    if not run then return "" end
    if not run.onTime then return L["Over time"] end
    local up = tonumber(run.upgrades) or 0
    if up < 1 then up = 1 end
    if up > 3 then up = 3 end
    return "+" .. up
end

-- 毫秒 → m:ss（完賽時間是毫秒，時限是秒，兩邊都要能印）
function H.FormatMs(ms)
    local n = tonumber(ms)
    if not n then return "--:--" end
    n = math.floor(n / 1000 + 0.5)
    return ("%d:%02d"):format(math.floor(n / 60), n % 60)
end

function H.FormatSec(sec)
    local n = tonumber(sec)
    if not n then return "--:--" end
    n = math.floor(n + 0.5)
    return ("%d:%02d"):format(math.floor(n / 60), n % 60)
end

-- 下拉與標題用的短描述：「+14 晶紅生命之池  9/21 01:14」
function H.Label(run)
    if not run then return "" end
    local when = ""
    local t = tonumber(run.endedAt) or tonumber(run.startedAt)
    if t then when = "  " .. date("%m/%d %H:%M", t) end
    return ("+%d %s%s"):format(tonumber(run.level) or 0, H.MapName(run), when)
end

------------------------------------------------------------
-- 假場次：`/mmp test`
--
-- 讓人不進鑰石就看得到版面。**不存檔** —— 面板直接拿這張表畫，
-- 所以它的形狀必須跟真的一模一樣，不然「測起來好好的、實戰爛掉」。
--
-- variant 2 用來驗各種旗標的樣子（超時、統計來源是總計、有殘缺標記）。
------------------------------------------------------------
local FAKE_NAMES = { "米利", "德莫", "阿丹", "小賴", "琪琪" }
local FAKE_CLASS = { "PALADIN", "MAGE", "ROGUE", "PRIEST", "DRUID" }

function H.MakeFake(variant)
    local overTime = (variant == 2)
    local run = {
        v = H.RUN_VERSION,
        id = time(),
        char = (UnitName("player") or "?"),
        fake = true,
        mapID = nil,
        mapName = L["Test Dungeon"],
        level = 14,
        affixes = {},
        timeMs = overTime and 1967000 or 1523000,
        limitSec = 1680,
        onTime = not overTime,
        upgrades = overTime and 0 or 2,
        practiceRun = false,
        deaths = overTime and 19 or 3,
        deathPenaltySec = overTime and 285 or 45,
        oldScore = 3194,
        newScore = overTime and 3194 or 3206,
        isMapRecord = not overTime,
        isAffixRecord = false,
        startedAt = time() - 2000,
        endedAt = time(),
        statsSource = overTime and "overall" or "sessions",
        statsFlags = overTime and { truncated = true, resetDuringRun = true } or {},
        combatSec = 742,
        players = {},
    }
    for i = 1, 5 do
        run.players[i] = {
            name = FAKE_NAMES[i],
            class = FAKE_CLASS[i],
            isSelf = (i == 1) or nil,
            score = 3206 - (i - 1) * 180,
            dmg = 294100000 / i,
            dps = 294100 / i,
            heal = (i == 4) and 88000000 or 2400000 / i,
            hps = (i == 4) and 118000 or 3200 / i,
            taken = 52100000 / i,
            avoidable = 4200000 / i,
            enemyTaken = 0,
            interrupts = 8 - i,
            dispels = 5 - i,
            deaths = (i == 1) and 1 or (i % 3),
            loot = {},
        }
    end
    return run
end
