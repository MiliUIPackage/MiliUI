------------------------------------------------------------
-- 任務完成音效：任務記錄裡某條任務從「未完成」翻成「可以交了」的那一刻響一聲。
--
--   ns.Sound.Items()        設定頁下拉的選項（第一項「無」；接著遊戲內建語音；最後 LSM 的音效）
--   ns.Sound.Preview(v)     設定頁「試聽」（不看節流）
--   ns.Sound.Path(v)        設定值 → PlaySoundFile 吃的路徑或檔案編號（查不到 nil）
--
-- 設定值（ns.db.sounds.questComplete）：false ＝ 無；"file:<檔案編號>" ＝ 遊戲內建；
-- 其餘字串 ＝ LibSharedMedia 的音效名（別的插件註冊的）。
--
-- 內建清單是暴雪自己的語音檔（FileDataID），不帶任何音檔資產：預設的「工作完成！」
-- 是獸人苦工那句（Sound\Creature\Peon\PeonBuildingComplete1.ogg），其餘是各種族
-- /congratulate 的語音。這張表是 Kaliel's Tracker 多年用下來的同一批檔案編號。
-- 種族名稱直接問 C_CreatureInfo.GetRaceInfo，不另建語系條目。
--
-- 偵測不掛追蹤器：追蹤器只畫有追蹤的任務，而「可以交了」是任務記錄的事實。
-- 每次任務事件之後掃一遍任務記錄，逐條記住 IsComplete 的結果；只有
-- **記過 false 又變成 true** 才響 —— 第一次看到就已經完成的（重載、進世界、
-- 接下來就是完成狀態的對話任務）不算，否則每次 /reload 都會響一輪。
-- 同一次掃描裡好幾條一起完成只響一次（交完一條連鎖解開下一條的常見情況）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local T = ns.Tracker

ns.Sound = {}
local S = ns.Sound

local FILE_PREFIX = "file:"
local CHANNEL = "Master"
local THROTTLE = 1.5

-- { fileID, raceID, sex }：raceID nil ＝ 不是種族語音（文字走 L）
--   raceID 照 C_CreatureInfo：人類 1、矮人 3、夜精靈 4、地精 7、德萊尼 11、狼人 22、
--   獸人 2、不死族 5、牛頭人 6、食人妖 8、血精靈 10、哥布林 9、熊貓人 24
local BUILTIN = {
    { 558132 },                        -- PeonBuildingComplete1.ogg
    { 540703, 1,  "m" }, { 540654, 1,  "f" },   -- Human
    { 540042, 3,  "m" }, { 539981, 3,  "f" },   -- Dwarf
    { 541085, 4,  "m" }, { 541031, 4,  "f" },   -- Night Elf
    { 540512, 7,  "m" }, { 540432, 7,  "f" },   -- Gnome
    { 539661, 11, "m" }, { 539676, 11, "f" },   -- Draenei
    { 542228, 22, "m" }, { 542028, 22, "f" },   -- Worgen
    { 541401, 2,  "m" }, { 541317, 2,  "f" },   -- Orc
    { 542775, 5,  "m" }, { 542684, 5,  "f" },   -- Undead
    { 561484, 6,  "m" }, { 542997, 6,  "f" },   -- Tauren（男是 TaurenYes3.ogg）
    { 543307, 8,  "m" }, { 543273, 8,  "f" },   -- Troll
    { 539400, 10, "m" }, { 539175, 10, "f" },   -- Blood Elf
    { 542005, 9,  "m" }, { 541735, 9,  "f" },   -- Goblin
    { 630070, 24, "m" }, { 636419, 24, "f" },   -- Pandaren
}

local function RaceName(raceID)
    local info = C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(raceID)
    return info and info.raceName or nil
end

local function BuiltinText(e)
    if not e[2] then return L["Orc peon: \"Work complete!\""] end
    local race = RaceName(e[2]) or ("Race " .. e[2])
    local sex = e[3] == "m" and (MALE or "Male") or (FEMALE or "Female")
    return race .. " (" .. sex .. ")"
end

local function LSM()
    return LibStub and LibStub("LibSharedMedia-3.0", true)
end

-- 下拉選項。做成函式、開頁那一刻才求值：LSM 的音效是別的插件註冊的，可能比我們晚載入
function S.Items()
    local items = { { text = L["None"], value = false } }
    for _, e in ipairs(BUILTIN) do
        items[#items + 1] = { text = BuiltinText(e), value = FILE_PREFIX .. e[1] }
    end
    local lsm = LSM()
    if lsm then
        local ok, list = pcall(lsm.List, lsm, "sound")
        if ok and type(list) == "table" then
            local names = {}
            for _, name in ipairs(list) do
                if type(name) == "string" then names[#names + 1] = name end
            end
            table.sort(names)
            for _, name in ipairs(names) do
                items[#items + 1] = { text = name, value = name }
            end
        end
    end
    return items
end

function S.Path(v)
    if type(v) ~= "string" or v == "" then return nil end
    local id = v:match("^" .. FILE_PREFIX .. "(%d+)$")
    if id then return tonumber(id) end
    local lsm = LSM()
    if not lsm then return nil end
    local ok, path = pcall(lsm.Fetch, lsm, "sound", v, true)
    if not ok then return nil end
    if (type(path) == "string" and path ~= "") or type(path) == "number" then return path end
    return nil
end

local function PlayRaw(v)
    local path = S.Path(v)
    if path == nil then return false end
    local ok, willPlay = pcall(PlaySoundFile, path, CHANNEL)
    return ok and willPlay ~= false
end

function S.Preview(v)
    return PlayRaw(v)
end

local function Setting()
    local s = ns.db and ns.db.sounds
    return s and s.questComplete or false
end

------------------------------------------------------------
-- 偵測
------------------------------------------------------------
local state = {}        -- questID → 上次掃到的 IsComplete
local lastPlayed = 0

local function PlayQuestComplete()
    local v = Setting()
    if not v then return end
    local now = GetTime()
    if now - lastPlayed < THROTTLE then return end
    if PlayRaw(v) then lastPlayed = now end
end
S.PlayQuestComplete = PlayQuestComplete

local function Scan()
    if not (C_QuestLog and C_QuestLog.GetNumQuestLogEntries and C_QuestLog.GetInfo) then return end
    local isComplete = C_QuestLog.IsComplete
    if not isComplete then return end
    local seen, fire = {}, false
    for i = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(i)
        local qID = info and not info.isHeader and not info.isHidden and info.questID
        if qID then
            seen[qID] = true
            local done = isComplete(qID) and true or false
            if state[qID] == false and done then fire = true end
            state[qID] = done
        end
    end
    -- 交掉／放棄的從表裡拿掉，再接一次才會重新從「第一次看到」起算
    for qID in pairs(state) do
        if not seen[qID] then state[qID] = nil end
    end
    if fire then PlayQuestComplete() end
end

ns.RegisterCallback("Init", "sound", function()
    local evt = CreateFrame("Frame")
    for _, e in ipairs({
        "QUEST_LOG_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
        "QUEST_WATCH_UPDATE", "UNIT_QUEST_LOG_CHANGED", "PLAYER_ENTERING_WORLD",
    }) do
        evt:RegisterEvent(e)
    end
    evt:SetScript("OnEvent", function()
        -- 沒選音效就不用掃；但表要清空，之後一選上才不會拿舊的基準誤判
        if not Setting() then
            if next(state) then wipe(state) end
            return
        end
        -- 事件會連發（一次完成會帶好幾個 QUEST_LOG_UPDATE），合併成一次掃描
        T.Defer("sound", Scan, 0.1)
    end)
    -- 開著的話先建基準：登入當下就已完成的任務不響
    if Setting() then T.Defer("sound", Scan, 0.1) end
end)
