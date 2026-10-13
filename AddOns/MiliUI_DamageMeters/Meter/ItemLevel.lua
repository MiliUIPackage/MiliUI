------------------------------------------------------------
-- 裝備等級（頭像卡片的第二行用）
--
-- C_DamageMeter 的 source 沒有裝等，只能自己問：
--   * 自己 —— GetAverageItemLevel()，隨時可讀
--   * 隊友 —— 觀察（NotifyInspect → INSPECT_READY → C_PaperDollInfo.GetInspectItemLevel）
--
-- 成本紀律：
--   * 只在卡片要顯示某人、而快取裡沒有時才發一次觀察；同一時間只等一個人，
--     兩次請求至少隔 1.5 秒（伺服器對觀察有節流，連發會整批沒回應）
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

local TTL      = 600    -- 快取 10 分鐘：換裝不頻繁，過期了下次滑過再問
local THROTTLE = 1.5

local cache = {}        -- [guid] = { lvl, t }
local pendingGUID, pendingUnit, lastRequest = nil, nil, 0
local listeners = {}    -- [owner] = fn(guid)：觀察回來時通知卡片重畫

local function PlainNumber(v)
    if v == nil or issecret(v) or type(v) ~= "number" then return nil end
    return v
end

-- 在隊伍裡找這個 GUID 的 unit token。秘密 GUID 一律不比（呼叫端已擋，這裡再防一次）。
local function UnitForGUID(guid)
    if not guid or issecret(guid) then return nil end
    local function match(unit)
        local g = UnitGUID(unit)
        return g and not issecret(g) and g == guid
    end
    if match("player") then return "player" end
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local u = "raid" .. i
            if match(u) then return u end
        end
    else
        for i = 1, 4 do
            local u = "party" .. i
            if match(u) then return u end
        end
    end
    if match("target") then return "target" end
    if match("mouseover") then return "mouseover" end
    return nil
end

local function Notify(guid)
    for _, fn in pairs(listeners) do pcall(fn, guid) end
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
    if not guid then return nil end
    local c = cache[guid]
    if c and (GetTime() - c.t) <= TTL then return c.lvl end
    return nil
end

-- 快取沒有就排一次觀察。回來時透過 IL.Listen 註冊的函式通知。
function IL.Request(guid)
    guid = D.PlainGUID(guid)
    if not guid or guid == ns.playerGUID then return end
    if IL.Get(guid) then return end
    if InCombatLockdown() then return end
    if not (NotifyInspect and CanInspect) then return end
    if InspectFrame and InspectFrame:IsShown() then return end
    local now = GetTime()
    if now - lastRequest < THROTTLE then return end
    local unit = UnitForGUID(guid)
    if not unit then return end
    local okCan, can = pcall(CanInspect, unit)
    if not okCan or not can or issecret(can) then return end
    if pcall(NotifyInspect, unit) then
        pendingGUID, pendingUnit, lastRequest = guid, unit, now
    end
end

function IL.Listen(owner, fn) listeners[owner] = fn end

local f = CreateFrame("Frame")
f:RegisterEvent("INSPECT_READY")
f:SetScript("OnEvent", function(_, _, guid)
    guid = D.PlainGUID(guid)
    if not guid then return end
    local unit = (guid == pendingGUID and pendingUnit) or UnitForGUID(guid)
    if unit and C_PaperDollInfo and C_PaperDollInfo.GetInspectItemLevel then
        local ok, lvl = pcall(C_PaperDollInfo.GetInspectItemLevel, unit)
        lvl = ok and PlainNumber(lvl)
        if lvl and lvl > 0 then
            cache[guid] = { lvl = math.floor(lvl + 0.5), t = GetTime() }
        end
    end
    -- ⚠ 不呼叫 ClearInspectPlayer：INSPECT_READY 是廣播，排在我們後面的監聽者
    --   （TinyInspect、滑鼠提示）還要讀同一份觀察資料，先清掉它們就拿到空的。
    if guid == pendingGUID then pendingGUID, pendingUnit = nil, nil end
    if cache[guid] then Notify(guid) end
end)
