------------------------------------------------------------
-- 觀察快取：裝備等級（頭像卡片第二行）＋ 專精（圖示的退路）
--
-- C_DamageMeter 的 source 沒有裝等，而且**常常不給別人的 specIconID**
-- （實測 2026-10-14：同隊、距離遠的兩位隊友都是 nil，只有自己有）。兩樣都只能自己問：
--   * 自己 —— GetAverageItemLevel()，隨時可讀；專精暴雪本來就給
--   * 隊友 —— 觀察（NotifyInspect → INSPECT_READY →
--             C_PaperDollInfo.GetInspectItemLevel／GetInspectSpecialization）
--
-- 兩條發問的路：
--   * 卡片要顯示某人而快取沒有 → IL.Request（滑過那一下）
--   * **脫戰自動掃隊伍**：還不知道專精的隊友排隊問，每 2 秒一個。觀察有距離限制，
--     看不到的人（UnitIsVisible）先跳過、下一輪再試；全部問完就停，戰鬥中暫停。
--
-- 成本紀律：
--   * 同一時間只等一個人，兩次請求至少隔 1.5 秒（伺服器對觀察有節流，連發會整批沒回應）
--   * **別人發的觀察也收**：滑鼠提示、TinyInspect、觀察視窗觸發的 INSPECT_READY
--     一樣寫進快取，等於免費搭便車
--   * 戰鬥中不發觀察。sourceGUID 戰鬥中是秘密值，本來也查不了快取
--
-- ⚠ 觀察視窗開著時不發：NotifyInspect 會把視窗的對象換成我們問的人。
------------------------------------------------------------
local _, ns = ...

ns.ItemLevel = {}
local IL = ns.ItemLevel
local D = ns.Data
local issecret = ns.Secret.IsSecret

local LVL_TTL  = 600    -- 裝等 10 分鐘：換裝不頻繁，過期了下次滑過再問
local SPEC_TTL = 1800   -- 專精 30 分鐘；換專精有事件會直接清掉，這只是保險
local THROTTLE = 1.5
local SCAN_EVERY = 2

local cache = {}        -- [guid] = { lvl, lt, spec, st }
local pendingGUID, pendingUnit, lastRequest = nil, nil, 0
local listeners = {}    -- [owner] = fn(guid)：觀察回來時通知卡片重畫

local function PlainNumber(v)
    if v == nil or issecret(v) or type(v) ~= "number" then return nil end
    return v
end

local function PlainGUIDOf(unit)
    local g = UnitGUID(unit)
    if g == nil or issecret(g) then return nil end
    return g
end

-- 隊伍成員的 unit token，依序回呼（自己不算）
local function ForEachMember(fn)
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            if fn("raid" .. i) then return end
        end
    elseif IsInGroup() then
        for i = 1, 4 do
            if fn("party" .. i) then return end
        end
    end
end

-- 在隊伍裡找這個 GUID 的 unit token。秘密 GUID 一律不比（呼叫端已擋，這裡再防一次）。
local function UnitForGUID(guid)
    if not guid or issecret(guid) then return nil end
    if PlainGUIDOf("player") == guid then return "player" end
    local found
    ForEachMember(function(u)
        if PlainGUIDOf(u) == guid then found = u; return true end
    end)
    if found then return found end
    if PlainGUIDOf("target") == guid then return "target" end
    if PlainGUIDOf("mouseover") == guid then return "mouseover" end
    return nil
end

local function Notify(guid)
    for _, fn in pairs(listeners) do pcall(fn, guid) end
end

local function Fresh(c, field, t, ttl)
    return c and c[field] and (GetTime() - c[t]) <= ttl
end

-- 回傳裝等（四捨五入的整數）或 nil。guid 必須是明碼。
function IL.Get(guid, isOwn)
    if isOwn then
        local _, equipped = GetAverageItemLevel()
        equipped = PlainNumber(equipped)
        if equipped and equipped > 0 then return math.floor(equipped + 0.5) end
        return nil
    end
    guid = D.PlainGUID(guid)
    local c = guid and cache[guid]
    return Fresh(c, "lvl", "lt", LVL_TTL) and c.lvl or nil
end

-- 回傳 specID 或 nil（過期就是 nil，掃描靠這個決定要不要重問）
function IL.Spec(guid)
    guid = D.PlainGUID(guid)
    local c = guid and cache[guid]
    return Fresh(c, "spec", "st", SPEC_TTL) and c.spec or nil
end

------------------------------------------------------------
-- 分段的專精快照
--
-- 上面的快取只記「這個人現在」的專精。一王冰 DK 打、之後換穢邪，切回一王那段
-- 也會畫成穢邪 —— 技能明細是暴雪逐段存的、還是冰的技能，錯的只有我們補的圖示。
-- 所以每一段一出現，就把當下的專精表綁給它：
--   * live＝目前的專精表 [guid] = specID。被分段綁住之後就凍結，之後有人**換**專精
--     先複製一份新的再改（copy-on-write）—— 沒人換專精時所有分段共用同一張。
--   * 分段 ID 從 DAMAGE_METER_COMBAT_SESSION_UPDATED 的第二個參數拿（暴雪自己的視窗
--     也這樣讀：每次兩發，總計那發是 0、目前那發帶 sessionID）。分段開打就會出現，
--     戰鬥中又沒人能換專精，所以「第一次看到」就是「開打時」。
--   * 綁的時候還不知道的人（觀察還沒問到、或換專精剛被清掉），之後第一次問到就補進
--     每一張缺他的表：那一段之後最先問到的專精，就是他當時專精的最佳估計。
--     已經有值的表不動 —— 那正是換專精之前的樣子。
-- 只放記憶體：/reload 之後舊分段退回查 live（暴雪也不保證分段 ID 跨登入還是同一段）。
------------------------------------------------------------
local live, liveFrozen = {}, false
local bound = {}                -- [sessionID] = 那一段開打時的專精表
local currentSessionID          -- 「目前」那一段的 ID（D.S.Current 自己沒有 sessionID）

-- 快取的專精變了。spec＝nil 是「知道他換了、還不知道換成什麼」
local function SetLiveSpec(guid, spec)
    local old = live[guid]
    if old == spec then return end
    if old == nil then
        for _, map in pairs(bound) do
            if map[guid] == nil then map[guid] = spec end
        end
        live[guid] = spec
        return
    end
    if liveFrozen then
        local copy = {}
        for g, s in pairs(live) do copy[g] = s end
        live, liveFrozen = copy, false
    end
    live[guid] = spec
end

local function BindSession(id)
    currentSessionID = id
    if bound[id] then return end
    bound[id] = live
    liveFrozen = true
    -- 新的一段（一場戰鬥一次）順手丟掉暴雪已經不給的分段
    local list = D.GetAvailableSessions()
    if list and #list > 0 then
        local keep = {}
        for _, sess in ipairs(list) do
            local sid = PlainNumber(sess.sessionID)
            if sid then keep[sid] = true end
        end
        for sid in pairs(bound) do
            if sid ~= id and not keep[sid] then bound[sid] = nil end
        end
    end
end

-- 這個畫面該查哪一張專精表：歷史分段查它綁的、「目前」查目前那一段綁的；
-- 總計跨好幾段（本來就沒有單一答案）、還沒綁到的，查 live
function IL.SpecMap(sessType, sessID)
    sessID = PlainNumber(sessID)
    if sessID then return bound[sessID] or live end
    if sessType == D.S.Current and currentSessionID then
        return bound[currentSessionID] or live
    end
    return live
end

-- 回傳 specID 或 nil。map 是 IL.SpecMap 的回傳，nil＝live
function IL.SpecIn(map, guid)
    guid = D.PlainGUID(guid)
    return guid and (map or live)[guid] or nil
end

-- 除錯報告用：最近幾次專精變動（換專精事件、觀察問到不一樣的專精）
local specLog = {}
local function LogSpec(fmt, ...)
    table.insert(specLog, date("%H:%M:%S ") .. fmt:format(...))
    if #specLog > 12 then table.remove(specLog, 1) end
end

local function UnitLabel(unit)
    local name = unit and UnitName(unit)
    if name == nil or issecret(name) then return "?" end
    return name
end

function IL.DebugLines()
    local maps, n = {}, 0
    for _, map in pairs(bound) do
        if not maps[map] then maps[map] = true; n = n + 1 end
    end
    local sessions = 0
    for _ in pairs(bound) do sessions = sessions + 1 end
    local lines = {
        ("current=%s bound=%d tables=%d frozen=%s"):format(tostring(currentSessionID),
            sessions, n, tostring(liveFrozen)),
    }
    for _, line in ipairs(specLog) do lines[#lines + 1] = line end
    return lines
end

local function CanAsk()
    if InCombatLockdown() then return false end
    if not (NotifyInspect and CanInspect) then return false end
    if InspectFrame and InspectFrame:IsShown() then return false end
    return GetTime() - lastRequest >= THROTTLE
end

local function Ask(guid, unit)
    local okCan, can = pcall(CanInspect, unit)
    if not okCan or not can or issecret(can) then return false end
    if pcall(NotifyInspect, unit) then
        pendingGUID, pendingUnit, lastRequest = guid, unit, GetTime()
        return true
    end
    return false
end

-- 快取沒有就排一次觀察。回來時透過 IL.Listen 註冊的函式通知。
function IL.Request(guid)
    guid = D.PlainGUID(guid)
    if not guid or guid == ns.playerGUID then return end
    if IL.Get(guid) and IL.Spec(guid) then return end
    if not CanAsk() then return end
    local unit = UnitForGUID(guid)
    if unit then Ask(guid, unit) end
end

function IL.Listen(owner, fn) listeners[owner] = fn end

------------------------------------------------------------
-- 脫戰自動掃隊伍
------------------------------------------------------------
local scanTicker

local function StopScan()
    if scanTicker then scanTicker:Cancel(); scanTicker = nil end
end

-- 一輪：問一個還不知道專精、而且看得到的隊友。回傳還有沒有人沒問到。
local function ScanOnce()
    if InCombatLockdown() or not IsInGroup() then StopScan(); return end
    local missing, asked = false, false
    ForEachMember(function(u)
        local guid = PlainGUIDOf(u)
        if not guid or IL.Spec(guid) then return end
        -- 離線的人永遠問不到，不算「還有人沒問」，否則掃描停不下來
        if not UnitIsConnected(u) then return end
        missing = true
        if asked or not CanAsk() then return end
        -- 太遠的觀察不會回來，先跳過，下一輪他可能就走近了
        if not UnitIsVisible(u) then return end
        asked = Ask(guid, u)
    end)
    if not missing then StopScan() end
end

local function StartScan()
    if scanTicker or InCombatLockdown() or not IsInGroup() then return end
    scanTicker = C_Timer.NewTicker(SCAN_EVERY, ScanOnce)
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
-- 脫戰時沒有 ticker，專精一變要自己叫視窗重畫（長條的圖示備忘比的是解析出來的專精）
local function RefreshWindows()
    if ns.Windows then ns.Windows.ForEach(function(W) if W.Refresh then W.Refresh() end end) end
end

local function OnInspectReady(guid)
    guid = D.PlainGUID(guid)
    if not guid then return end
    local unit = (guid == pendingGUID and pendingUnit) or UnitForGUID(guid)
    local specChanged = false
    if unit then
        local c = cache[guid] or {}
        if C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
            local ok, lvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
            lvl = ok and PlainNumber(lvl)
            if lvl and lvl > 0 then c.lvl, c.lt = math.floor(lvl + 0.5), GetTime() end
        end
        if GetInspectSpecialization then
            local ok, spec = pcall(GetInspectSpecialization, unit)
            spec = ok and PlainNumber(spec)
            if spec and spec > 0 then
                specChanged = (live[guid] ~= spec)
                if specChanged then
                    LogSpec("inspect %s %s -> %s", UnitLabel(unit), tostring(live[guid]), spec)
                end
                c.spec, c.st = spec, GetTime()
                SetLiveSpec(guid, spec)
            end
        end
        if c.lvl or c.spec then cache[guid] = c end
    end
    -- ⚠ 不呼叫 ClearInspectPlayer：INSPECT_READY 是廣播，排在我們後面的監聽者
    --   （TinyInspect、滑鼠提示）還要讀同一份觀察資料，先清掉它們就拿到空的。
    if guid == pendingGUID then pendingGUID, pendingUnit = nil, nil end
    if specChanged then RefreshWindows() end
    if cache[guid] then Notify(guid) end
end

-- 隊友換專精：清掉他的專精、馬上重問（不等掃描的 2 秒）。已經綁進分段的舊專精不動。
-- arg1 可能是秘密的 unit token，不拿它比對
local function OnSpecChanged(unit)
    if unit == nil or issecret(unit) then
        LogSpec("event unit=secret")
        return
    end
    if unit == "player" then return end
    local guid = PlainGUIDOf(unit)
    local c = guid and cache[guid]
    -- 沒觀察過的人（陌生人的名條、目標）不管；還沒問到的隊友本來就在掃描的名單上
    if not c then return end
    LogSpec("event %s %s spec=%s", unit, UnitLabel(unit), tostring(live[guid]))
    c.spec = nil
    if live[guid] ~= nil then
        SetLiveSpec(guid, nil)
        RefreshWindows()
    end
    IL.Request(guid)
end

local f = CreateFrame("Frame")
f:RegisterEvent("INSPECT_READY")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
-- 暴雪傷害統計的事件：舊客戶端沒有，RegisterEvent 對不存在的事件會拋錯
for _, ev in ipairs({ "DAMAGE_METER_COMBAT_SESSION_UPDATED", "DAMAGE_METER_RESET" }) do
    local ok, err = pcall(f.RegisterEvent, f, ev)
    if not ok and ns.HAS_API then
        ns.ReportError("RegisterEvent failed: " .. ev .. " (" .. tostring(err) .. ")")
    end
end
f:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "DAMAGE_METER_COMBAT_SESSION_UPDATED" then
        -- 戰鬥中連續打：已經綁過的分段只是一次查表
        local id = PlainNumber(arg2)
        if id and id > 0 then BindSession(id) end
    elseif event == "DAMAGE_METER_RESET" then
        bound, currentSessionID, liveFrozen = {}, nil, false
    elseif event == "INSPECT_READY" then
        OnInspectReady(arg1)
    elseif event == "PLAYER_REGEN_DISABLED" then
        StopScan()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        OnSpecChanged(arg1)
        StartScan()
    else
        StartScan()
    end
end)
