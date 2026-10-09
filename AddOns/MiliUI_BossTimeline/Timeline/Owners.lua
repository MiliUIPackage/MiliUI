------------------------------------------------------------
-- 這一條是誰放上時間軸的
--
-- 暴雪的事件資料只分三種來源（Enum.EncounterTimelineEventSource）：
--   0 Encounter  首領技能
--   1 Script     任何插件用 C_EncounterTimeline.AddScriptEvent 加的
--   2 EditMode   編輯模式的示範事件
-- **Script 沒有「哪個插件」這個欄位**，所以要自己認：在 AddScriptEvent 上掛 post-hook，
-- 從呼叫堆疊找出呼叫者的插件資料夾，再跟隨後出現的事件配對。
--
-- 配對條件：名稱＋圖示＋時長都一樣、時間差在 PAIR_WINDOW 秒內。Script 事件的資訊不是
-- 秘密值（SecretWhenEncounterEvent 只套在首領事件上），所以可以比；保險起見還是先過
-- ns.Secret 洗一次，洗不出明文就不配（寧可標「未知插件」也不要標錯）。
--
-- ⚠ ENCOUNTER_TIMELINE_EVENT_ADDED 可能在 AddScriptEvent 回傳**之前**就派送（同步事件），
--   也可能下一幀才到 —— 兩種順序都要接：
--   * 事件先到：Events 收進來時 owner 未知 → 等 hook 跑完回頭認領（ns.Events.ClaimRecent）
--   * hook 先到：先排進 pending，事件到的時候 Owners.Match 取走
--
-- 自己的自訂時間軸不走這條：Scheduler 拿得到 AddScriptEvent 的回傳值，直接 MarkMine。
--
-- hooksecurefunc 掛在 C_ 命名空間的表上是合法的，post-hook 不會污染呼叫端；暴雪自己的程式
-- 不呼叫 AddScriptEvent（編輯模式走 AddEditModeEvents），所以這個掛勾只會看到插件的呼叫。
------------------------------------------------------------
local ADDON, ns = ...

local S = ns.Secret
local L = ns.L

ns.Owners = {}
local O = ns.Owners

local PAIR_WINDOW = 1.0     -- 秒：hook 與事件的時間差超過這個就不配
local PENDING_MAX = 32

-- 常見插件給個好認的名字；其餘用插件清單裡的標題（剝掉色碼與「[標籤]」）
local FRIENDLY = {
    DiGuaTimelineAudioHelper = "DiGua Voice",
    ["DBM-Core"]             = "DBM",
    BigWigs                  = "BigWigs",
    BigWigs_Core             = "BigWigs",
    MRT                      = "MRT",
    WeakAuras                = "WeakAuras",
}

local mine    = {}   -- [eventID] = true
local pending = {}   -- { addon, name, icon, dur, t }
local seen    = {}   -- [addon] = 本次登入看過幾條（總覽頁的「誰在寫時間軸」）
local labels  = {}   -- [addon] = 顯示名稱（快取）

function O.MarkMine(id)
    if id then mine[id] = true end
end

function O.IsMine(id)
    return mine[id] == true
end

function O.Forget(id)
    mine[id] = nil
end

function O.Seen()
    return seen
end

-- 插件資料夾 → 顯示名稱
function O.Label(addon)
    if not addon then return L["Unknown addon"] end
    local cached = labels[addon]
    if cached then return cached end
    local text
    if FRIENDLY[addon] then
        text = L[FRIENDLY[addon]]
    else
        local _, title = C_AddOns.GetAddOnInfo(addon)
        title = S.PlainText(title)
        if title then
            title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            title = title:gsub("^%s*%[.-%]%s*", "")
            title = strtrim(title)
        end
        text = (title and title ~= "") and title or addon
    end
    labels[addon] = text
    return text
end

-- 呼叫堆疊裡第一個不是自己的插件資料夾
local function CallerAddon()
    local stack = debugstack(2, 24, 0)
    if type(stack) ~= "string" then return end
    for name in stack:gmatch("[Aa][Dd][Dd][Oo][Nn][Ss][/\\]([^/\\%]\"]+)[/\\]") do
        if name ~= ADDON then return name end
    end
end

local function SameRequest(p, name, icon, dur)
    if p.name ~= name or p.icon ~= icon then return false end
    if p.dur and dur then return math.abs(p.dur - dur) < 0.05 end
    return true
end

-- 事件到了：從 pending 取走配得上的那一筆，回傳插件資料夾（或 nil）
function O.Match(name, icon, dur)
    name, icon, dur = S.PlainText(name), S.PlainNumber(icon), S.PlainNumber(dur)
    if not (name or icon) then return end
    local now = GetTime()
    for i = 1, #pending do
        local p = pending[i]
        if now - p.t <= PAIR_WINDOW and SameRequest(p, name, icon, dur) then
            table.remove(pending, i)
            return p.addon
        end
    end
end

function O.NoteSeen(addon)
    if addon then seen[addon] = (seen[addon] or 0) + 1 end
end

local function OnAddScriptEvent(req)
    if type(req) ~= "table" then return end
    local addon = CallerAddon()
    if not addon then return end     -- 自己（Scheduler 另外登記）或認不出來
    local entry = {
        addon = addon,
        name  = S.PlainText(req.overrideName ~= "" and req.overrideName or nil),
        icon  = S.PlainNumber(req.iconFileID),
        dur   = S.PlainNumber(req.duration),
        t     = GetTime(),
    }
    -- 事件已經先到了的話直接認領，不必排隊
    if ns.Events and ns.Events.ClaimRecent(entry, PAIR_WINDOW) then return end
    -- 清掉過期的、限制長度（玩家整晚不打首領也不會無限長）
    local now = entry.t
    for i = #pending, 1, -1 do
        if now - pending[i].t > PAIR_WINDOW then table.remove(pending, i) end
    end
    if #pending >= PENDING_MAX then table.remove(pending, 1) end
    pending[#pending + 1] = entry
end

function O.SameRequest(entry, name, icon, dur)
    return SameRequest(entry, S.PlainText(name), S.PlainNumber(icon), S.PlainNumber(dur))
end

-- 檔案層就掛：其他插件可能在自己的 PLAYER_LOGIN 之前就加事件（測試指令、重載後補回）
if C_EncounterTimeline and C_EncounterTimeline.AddScriptEvent then
    hooksecurefunc(C_EncounterTimeline, "AddScriptEvent", function(req)
        xpcall(OnAddScriptEvent, ns.ReportError, req)
    end)
end
