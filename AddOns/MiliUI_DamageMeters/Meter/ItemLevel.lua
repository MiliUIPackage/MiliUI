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

-- 回傳 specID 或 nil
function IL.Spec(guid)
    guid = D.PlainGUID(guid)
    local c = guid and cache[guid]
    return Fresh(c, "spec", "st", SPEC_TTL) and c.spec or nil
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
                specChanged = (c.spec ~= spec)
                c.spec, c.st = spec, GetTime()
            end
        end
        if c.lvl or c.spec then cache[guid] = c end
    end
    -- ⚠ 不呼叫 ClearInspectPlayer：INSPECT_READY 是廣播，排在我們後面的監聽者
    --   （TinyInspect、滑鼠提示）還要讀同一份觀察資料，先清掉它們就拿到空的。
    if guid == pendingGUID then pendingGUID, pendingUnit = nil, nil end
    if specChanged then
        -- 長條的圖示備忘連 specGen 一起比；不加這個，specIconID 一直是 nil 的那幾列不會重畫
        D.specGen = D.specGen + 1
        if ns.Windows then ns.Windows.ForEach(function(W) if W.Refresh then W.Refresh() end end) end
    end
    if cache[guid] then Notify(guid) end
end

local f = CreateFrame("Frame")
f:RegisterEvent("INSPECT_READY")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:RegisterEvent("PLAYER_REGEN_DISABLED")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "INSPECT_READY" then
        OnInspectReady(arg1)
    elseif event == "PLAYER_REGEN_DISABLED" then
        StopScan()
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        -- 隊友換專精：清掉他的專精，讓掃描重問。arg1 可能是秘密的 unit token，不拿它比對
        if arg1 and not issecret(arg1) and arg1 ~= "player" then
            local guid = PlainGUIDOf(arg1)
            if guid and cache[guid] then cache[guid].spec = nil end
        end
        StartScan()
    else
        StartScan()
    end
end)
