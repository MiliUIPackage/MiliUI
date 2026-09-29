------------------------------------------------------------
-- 暴雪四條檢視器的掛勾與 item 追蹤
--
--   ns.Viewers.frames[item] = { viewer, barKey, cooldownID, decorated, … }   弱鍵表
--   ns.Viewers.Get(sourceKey)          那條的暴雪檢視器框（可能是 nil）
--   ns.Viewers.EnumerateItems(fn)      對每個「目前在池子裡作用中」的 item 呼叫 fn(item, rec)
--   ns.Viewers.Count(sourceKey)        那條作用中的 item 數
--
-- 引擎契約（計畫 §2），這支是它們的第一線：
--   * **只後掛勾**（hooksecurefunc），每個掛勾本體包 ns.Guard。
--   * **暴雪框上一個欄位都不寫**：每框的資料放在上面的弱鍵表。
--   * 不 SetParent、不 Hide／Show 暴雪框；不從 item 讀尺寸。
--   * 掛勾裡只做兩件事：更新弱鍵表上的身分、丟「重排訊號」。真正的排版在 Bars，
--     訊號進待處理集合、下一幀（0.1 秒節流）合併處理。
--   * 唯一的同步動作：檢視器的 Layout 跑完之後，當場把 item 放回上次算好的格子
--     （Bars.Reapply，只用快取、不重算）。暴雪的格狀排版每次都會把 item 拉回它的格線，
--     等到下一幀才放回來會閃一下。
--
-- 就緒：暴雪的檢視器與 CooldownViewerSettings 什麼時候建好沒有保證，登入後用退避重試
-- （0、0.05、0.1、0.25、0.5、1、2 秒，之後每 2 秒），四條檢視器與設定框都在才掛。
------------------------------------------------------------
local _, ns = ...

ns.Viewers = {}
local V = ns.Viewers

V.VIEWERS = {
    essential = "EssentialCooldownViewer",
    utility   = "UtilityCooldownViewer",
    buffs     = "BuffIconCooldownViewer",
    buffbars  = "BuffBarCooldownViewer",
}
V.ORDER = { "essential", "utility", "buffs", "buffbars" }
-- 增益兩條的 item 會因為光環上下而顯示／隱藏（其他兩條的 item 永遠顯示）
V.AURA_KIND = { buffs = true, buffbars = true }

V.frames    = setmetatable({}, { __mode = "k" })   -- item → rec
V.viewerKey = setmetatable({}, { __mode = "k" })   -- 檢視器框 → sourceKey
V.ready     = false
V.blocked   = {}                                    -- 掛勾裡寫入被擋的記帳（debug 用）

local Guard = ns.Guard

local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    local can = _G.canaccessvalue
    if can and not can(v) then return nil end
    return v
end

function V.Get(sourceKey)
    local name = V.VIEWERS[sourceKey]
    return name and _G[name] or nil
end

------------------------------------------------------------
-- 訊號：丟給 Bars 的排程（Bars 還沒載入時先記著）
------------------------------------------------------------
local function Signal(sourceKey, level)
    if ns.Bars and ns.Bars.RequestSource then
        ns.Bars.RequestSource(sourceKey, level)
    end
end
V.Signal = Signal

------------------------------------------------------------
-- 寫入被擋的記帳（item 不是保護框，理論上不會發生；發生了就等脫戰重試）
------------------------------------------------------------
local retryFrame
local function NoteBlocked(what, item, fn)
    V.blocked[#V.blocked + 1] = what
    if #V.blocked > 20 then table.remove(V.blocked, 1) end
    if not retryFrame then
        retryFrame = CreateFrame("Frame")
        retryFrame.jobs = {}
        retryFrame:SetScript("OnEvent", function(self)
            self:UnregisterEvent("PLAYER_REGEN_ENABLED")
            local jobs = self.jobs
            self.jobs = {}
            for i = 1, #jobs do xpcall(jobs[i], ns.ReportError) end
        end)
    end
    retryFrame.jobs[#retryFrame.jobs + 1] = function() fn(item) end
    retryFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

------------------------------------------------------------
-- 暴雪「大小」設定不准生效：item 的縮放鎖 1
--
-- 我們的格子尺寸直接寫在 item 上（SetSize），暴雪的縮放再乘上去就會對不上格線。
------------------------------------------------------------
local scaleGuard = false
local function LockScale(item)
    if scaleGuard or ns.released then return end
    scaleGuard = true
    local ok = pcall(item.SetScale, item, 1)
    scaleGuard = false
    if not ok then
        NoteBlocked("SetScale", item, LockScale)
    end
end

------------------------------------------------------------
-- 登記一個 item（第一次看到時掛勾；池化的框永不銷毀，所以每框只掛一次）
------------------------------------------------------------
local function OnSetCooldownID(item, cooldownID)
    local rec = V.frames[item]
    if not rec then return end
    local id = Plain(cooldownID)
    if type(id) ~= "number" then id = nil end
    if rec.cooldownID ~= id then
        rec.cooldownID = id
        rec.decorated = nil          -- 逐法術覆寫跟著身分走
    end
    Signal(rec.barKey, "membership")
end

local function OnClearCooldownID(item)
    local rec = V.frames[item]
    if not rec then return end
    if rec.cooldownID ~= nil then
        rec.cooldownID = nil
        rec.decorated = nil
    end
    Signal(rec.barKey, "membership")
end

local function OnActiveStateChanged(item)
    local rec = V.frames[item]
    if rec then Signal(rec.barKey, "membership") end
end

local function OnItemSetScale(item, scale)
    local s = Plain(scale)
    if s ~= 1 then LockScale(item) end
end

local function HookItem(item, rec)
    if rec.hooked then return end
    rec.hooked = true
    hooksecurefunc(item, "SetScale", Guard(OnItemSetScale))
    if item.SetCooldownID then
        hooksecurefunc(item, "SetCooldownID", Guard(OnSetCooldownID))
    end
    if item.ClearCooldownID then
        hooksecurefunc(item, "ClearCooldownID", Guard(OnClearCooldownID))
    end
    if item.OnActiveStateChanged then
        hooksecurefunc(item, "OnActiveStateChanged", Guard(OnActiveStateChanged))
    end
    -- 樣式那一側要掛的（倒數轉圈、去飽和、長條內容）交給 Decorate
    if ns.Decorate and ns.Decorate.HookItem then
        ns.Decorate.HookItem(item, rec)
    end
end

-- item 目前的身分（明文 number 或 nil）。欄位名對過 12.1.0.69933 的
-- Blizzard_CooldownViewer/CooldownViewerItemData.lua：SetCooldownID 寫 self.cooldownID、
-- getter 是 CooldownViewerItemDataMixin:GetCooldownID()。getter 第一順位（pcall，它只 return 欄位），
-- 暴雪哪天改名或改成別的存法時 rawget 當退路。登入時 item 已經在池子裡、SetCooldownID
-- 早就叫過了，這裡讀錯＝整條被當成沒人認領停到畫面外。
local function ReadItemID(item)
    local get = item.GetCooldownID
    if type(get) == "function" then
        local ok, v = pcall(get, item)
        if ok then
            v = Plain(v)
            if type(v) == "number" then return v end
        end
    end
    local v = Plain(rawget(item, "cooldownID"))
    if type(v) == "number" then return v end
    return nil
end
V.ReadItemID = ReadItemID

local function Track(viewer, item)
    local key = V.viewerKey[viewer]
    if not key or not item then return end
    local rec = V.frames[item]
    if not rec then
        rec = { viewer = viewer, barKey = key }
        V.frames[item] = rec
    end
    rec.viewer, rec.barKey = viewer, key
    rec.decorated = nil               -- 取出時暴雪會重設計時顯示、縮放 ⇒ 樣式要重套
    rec.acquired = (rec.acquired or 0) + 1
    -- 取出時的身分：RefreshData 之後才會 SetCooldownID，這裡讀得到就先記（明文）
    rec.cooldownID = ReadItemID(item) or rec.cooldownID
    -- 第一次看到時的尺寸（我們 SetSize 之前）：Bars.ReleaseAll 還給暴雪時用；讀不到就不還原
    if rec.origW == nil then
        local ok, w, h = pcall(item.GetSize, item)
        if ok then w, h = Plain(w), Plain(h) else w, h = nil, nil end
        if type(w) == "number" and type(h) == "number" and w > 0 and h > 0 then
            rec.origW, rec.origH = w, h
        else
            rec.origW = false
        end
    end
    HookItem(item, rec)
    LockScale(item)
end
V.Track = Track

------------------------------------------------------------
-- 檢視器本體的掛勾
------------------------------------------------------------
local function OnAcquireItemFrame(viewer, item)
    Track(viewer, item)
    Signal(V.viewerKey[viewer], "membership")
end

local function OnRefreshLayout(viewer)
    Signal(V.viewerKey[viewer], "membership")
end

-- 暴雪的格狀排版剛把 item 拉回它的格線：當場用快取放回去，並排一次完整重排
local function OnLayout(viewer)
    local key = V.viewerKey[viewer]
    if not key then return end
    if ns.Bars and ns.Bars.Reapply then ns.Bars.Reapply(key) end
    Signal(key, "membership")
end

-- 暴雪改了顯示計時／長條內容 ⇒ 樣式重套
local function OnViewerStyleChanged(viewer)
    local key = V.viewerKey[viewer]
    if not key then return end
    for item, rec in pairs(V.frames) do
        if rec.viewer == viewer then rec.decorated = nil end
    end
    Signal(key, "layout")
end

local function OnViewerSetPoint(viewer)
    if ns.Bars and ns.Bars.PinViewer then
        ns.Bars.PinViewer(V.viewerKey[viewer])
    end
end

local function HookViewer(key, viewer)
    if V.viewerKey[viewer] then return end
    V.viewerKey[viewer] = key
    hooksecurefunc(viewer, "OnAcquireItemFrame", Guard(OnAcquireItemFrame))
    hooksecurefunc(viewer, "RefreshLayout", Guard(OnRefreshLayout))
    if viewer.Layout then
        hooksecurefunc(viewer, "Layout", Guard(OnLayout))
    end
    hooksecurefunc(viewer, "SetPoint", Guard(OnViewerSetPoint))
    if viewer.SetTimerShown then
        hooksecurefunc(viewer, "SetTimerShown", Guard(OnViewerStyleChanged))
    end
    if viewer.SetBarContent then
        hooksecurefunc(viewer, "SetBarContent", Guard(OnViewerStyleChanged))
    end
    if viewer.SetHideWhenInactive then
        hooksecurefunc(viewer, "SetHideWhenInactive", Guard(OnRefreshLayout))
    end

    -- 登入前（或掛勾前）就已經取出的 item
    local pool = viewer.itemFramePool
    if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
        for item in pool:EnumerateActive() do
            Track(viewer, item)
        end
    end
end

------------------------------------------------------------
-- 列舉作用中的 item（讀池子，不寫）
------------------------------------------------------------
function V.EnumerateItems(fn, onlyKey)
    for _, key in ipairs(V.ORDER) do
        if not onlyKey or onlyKey == key then
            local viewer = V.Get(key)
            local pool = viewer and V.viewerKey[viewer] and viewer.itemFramePool
            if type(pool) == "table" and type(pool.EnumerateActive) == "function" then
                for item in pool:EnumerateActive() do
                    local rec = V.frames[item]
                    if not rec then
                        Track(viewer, item)
                        rec = V.frames[item]
                    end
                    if rec then fn(item, rec) end
                end
            end
        end
    end
end

function V.Count(sourceKey)
    local n = 0
    V.EnumerateItems(function() n = n + 1 end, sourceKey)
    return n
end

------------------------------------------------------------
-- 冷卻管理器本身沒開：戰鬥外開一次（只在它是 0 時）
------------------------------------------------------------
local cvarDone = false
local function EnsureCVar()
    if cvarDone then return end
    local get = (C_CVar and C_CVar.GetCVar) or GetCVar
    local set = (C_CVar and C_CVar.SetCVar) or SetCVar
    if not (get and set) then cvarDone = true; return end
    if InCombatLockdown() then
        ns.Events.Register("PLAYER_REGEN_ENABLED", "viewers_cvar", function()
            ns.Events.Unregister("PLAYER_REGEN_ENABLED", "viewers_cvar")
            ns.Defer(EnsureCVar)
        end)
        return
    end
    cvarDone = true
    local ok, v = pcall(get, "cooldownViewerEnabled")
    if ok and Plain(v) ~= nil and tostring(v) == "0" then
        pcall(set, "cooldownViewerEnabled", "1")
    end
end
V.EnsureCVar = EnsureCVar

------------------------------------------------------------
-- 就緒：退避重試
------------------------------------------------------------
local BACKOFF = { 0, 0.05, 0.1, 0.25, 0.5, 1, 2 }
local attempt = 0
local MAX_ATTEMPTS = 60           -- 最後一段每 2 秒一次 ⇒ 約兩分鐘後放棄

local function AllPresent()
    if not _G.CooldownViewerSettings then return false end
    for _, key in ipairs(V.ORDER) do
        if not V.Get(key) then return false end
    end
    return true
end

local function Install()
    for _, key in ipairs(V.ORDER) do
        HookViewer(key, V.Get(key))
    end
    V.ready = true
    EnsureCVar()
    if ns.Fire then ns.Fire("ViewersReady") end
end

local function TryInstall()
    if V.ready then return end
    if AllPresent() then
        local ok, err = xpcall(Install, ns.ReportError)
        if not ok then
            V.installError = err
            if ns.EngineFailed then ns.EngineFailed({ "Viewers" }) end
        end
        return
    end
    attempt = attempt + 1
    if attempt > MAX_ATTEMPTS then return end
    local delay = BACKOFF[attempt] or BACKOFF[#BACKOFF]
    C_Timer.After(delay, TryInstall)
end

function V.Init()
    if V.ready or attempt > 0 then return end
    attempt = 1
    C_Timer.After(BACKOFF[1], TryInstall)
end

function V.Attempts() return attempt end
