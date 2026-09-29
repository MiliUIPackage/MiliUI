------------------------------------------------------------
-- MiliUI_CooldownManager 命名空間、共用出口、登入流程
--
-- 這支放的是「每個模組都會用、而且規則一定要一致」的東西：
--   ns.Guard(fn)        掛勾本體的 xpcall 包裝
--   ns.Defer(fn, ...)   延到下一幀（同一幀多次只排一次 C_Timer）
--   ns.Write(frame, fn) 容器層寫入的**唯一出口**（戰鬥中碰保護框就記帳）
--   ns.Events           事件註冊表（登入完成後才開始派送）
--   互斥偵測            舊的冷卻管理器插件同時載入時，本插件整個不初始化
------------------------------------------------------------
local ADDON, ns = ...

local L = ns.L          -- Locales\Locale.lua 在 TOC 排在本檔之前

ns.ADDON_NAME   = ADDON
ns.VERSION      = C_AddOns.GetAddOnMetadata(ADDON, "Version") or "dev"
-- 聊天前綴與暴雪設定頁標題共用，跟 TOC 的 [冷卻] 標籤同色
ns.PREFIX_COLOR = "|cff00FFFF"

-- player token 不受 12.1 身分限制，讀職業是安全的
ns.playerClass  = select(2, UnitClass("player"))

-- 秘密值判斷統一走共用層（Libs/MiliUIWidgets/Secret.lua），不要各自宣告 issecretvalue
ns.IsSecret = ns.Secret.IsSecret

function ns.Print(msg)
    print(ns.PREFIX_COLOR .. L["[MiliUI CDM]"] .. "|r " .. tostring(msg))
end

------------------------------------------------------------
-- 錯誤收集與封鎖動作攔截（共用層 Libs/MiliUIWidgets/Errors.lua）
--
-- ns.ReportError 是**內部逐項隔離**用的處理器（xpcall 的第二個參數）：錯誤記進
-- ns.errors 給除錯看，同時轉給全域 errorhandler。封鎖動作（ADDON_ACTION_BLOCKED）
-- 不是 Lua error、pcall 攔不住，共用層另外聽事件並印一行。
------------------------------------------------------------
ns.Errors.Install(function(line)
    print(ns.PREFIX_COLOR .. L["[MiliUI CDM]"] .. "|r |cffff5555" .. line .. "|r")
end)

------------------------------------------------------------
-- ns.Guard(fn) → 包好的函式
--
-- 所有 hooksecurefunc／HookScript 的本體都要包這層：我們的掛勾跑在暴雪那一批
-- 呼叫裡面，拋錯會中斷暴雪後面的處理（一條檢視器排版排到一半）。
-- 處理器在**呼叫當下**才取 geterrorhandler()，錯誤照常進玩家裝的錯誤收集器。
--
-- 回傳值照 xpcall：ok, ...。掛勾不看回傳值，要用的地方自己接。
------------------------------------------------------------
function ns.Guard(fn)
    return function(...)
        return xpcall(fn, geterrorhandler(), ...)
    end
end

------------------------------------------------------------
-- ns.Defer(fn, ...)：下一幀執行
--
-- 同一幀排進來的全部併成一次 C_Timer.After(0)，逐項隔離（一個拋錯不連坐）。
-- 參數在排進來的當下就存起來 —— ⚠ 不要把秘密值排進來再在下一幀拿去比較，
-- 延後不會讓秘密值變明文。
------------------------------------------------------------
local deferQueue, deferArmed = {}, false

local function FlushDefer()
    deferArmed = false
    local list = deferQueue
    deferQueue = {}
    for i = 1, #list do
        local job = list[i]
        xpcall(job.fn, ns.ReportError, unpack(job, 1, job.n))
    end
end

function ns.Defer(fn, ...)
    deferQueue[#deferQueue + 1] = { fn = fn, n = select("#", ...), ... }
    if not deferArmed then
        deferArmed = true
        C_Timer.After(0, FlushDefer)
    end
end

------------------------------------------------------------
-- ns.Write(frame, fn [, key])：容器層寫入的唯一出口
--
-- 容器的 SetPoint／SetSize／Show／Hide 全部經過這裡：
--   * 不在戰鬥          → 立刻做
--   * 戰鬥中、框不在保護鏈上 → 立刻做
--   * 戰鬥中、框在保護鏈上   → 記帳，PLAYER_REGEN_ENABLED 一次補做
--
-- 為什麼要判保護：光環格的持有框是 secure 框，而**保護是沿錨點鏈往上傳的**——
-- 一條容器只要底下錨了一顆保護框，容器自己就變成保護框，戰鬥中動它會被擋。
-- 判斷用 frame:IsProtected()，包 pcall；讀不到（拋錯或回秘密值）一律當保護，
-- 寧可晚一點套，也不要讓暴雪跳「動作被封鎖」。
--
-- key（選用）：同一個框、同一個 key 的帳只留最後一筆。例如同一場戰鬥裡改了三次
-- 位置，脫戰只需要套最後那次；不給 key 的每筆都照順序補做。
------------------------------------------------------------
local writeQueue, writeIndex = {}, {}

local function IsProtectedFrame(frame)
    local ok, protected = pcall(frame.IsProtected, frame)
    if not ok then return true end
    if ns.IsSecret(protected) then return true end
    return protected and true or false
end
ns.IsProtectedFrame = IsProtectedFrame

local writeWatcher = CreateFrame("Frame")
writeWatcher:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    local list = writeQueue
    writeQueue, writeIndex = {}, {}
    for i = 1, #list do
        local job = list[i]
        if not job.dead then
            xpcall(job.fn, ns.ReportError, job.frame)
        end
    end
end)

function ns.Write(frame, fn, key)
    if not frame then return end
    if not (InCombatLockdown() and IsProtectedFrame(frame)) then
        xpcall(fn, ns.ReportError, frame)
        return true
    end
    local job = { frame = frame, fn = fn }
    if key ~= nil then
        local byFrame = writeIndex[frame]
        if not byFrame then byFrame = {}; writeIndex[frame] = byFrame end
        local old = byFrame[key]
        if old then old.dead = true end      -- 舊的作廢，新的排到最後（順序＝最後的意圖）
        byFrame[key] = job
    end
    writeQueue[#writeQueue + 1] = job
    writeWatcher:RegisterEvent("PLAYER_REGEN_ENABLED")
    return false
end

-- 目前記帳中的筆數（除錯用）
function ns.PendingWrites()
    local n = 0
    for i = 1, #writeQueue do
        if not writeQueue[i].dead then n = n + 1 end
    end
    return n
end

------------------------------------------------------------
-- 事件註冊表
--
-- ns.Events.Register(event, key, fn [, unit])
--   key 讓同一事件的重複註冊可以覆蓋（模組重新初始化不會疊 handler）。
--   fn 收到的是事件參數（不含事件名），逐項 xpcall 隔離。
--   unit 給了就走 RegisterUnitEvent（C 端過濾，不讓全團的事件都進 Lua）。
--
-- ⚠ 登入完成（ns.Events.Start）之前只登記、不向引擎註冊：互斥偵測成立時
--   整支插件不初始化，事件也不該派送到還沒建好的模組上。
------------------------------------------------------------
ns.Events = {}
local Events = ns.Events
local handlers, units = {}, {}
local started = false

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then return end
    for _, fn in pairs(list) do
        xpcall(fn, ns.ReportError, ...)
    end
end)

local function Arm(event)
    if units[event] then
        eventFrame:RegisterUnitEvent(event, units[event])
    else
        eventFrame:RegisterEvent(event)
    end
end

function Events.Register(event, key, fn, unit)
    handlers[event] = handlers[event] or {}
    handlers[event][key] = fn
    if unit then units[event] = unit end
    if started then Arm(event) end
end

function Events.Unregister(event, key)
    local list = handlers[event]
    if not list then return end
    list[key] = nil
    if next(list) == nil then
        handlers[event] = nil
        if started then eventFrame:UnregisterEvent(event) end
    end
end

function Events.Start()
    if started then return end
    started = true
    for event in pairs(handlers) do Arm(event) end
end

------------------------------------------------------------
-- 專精：spells 表以 specID 為鍵，設定檔也可以綁專精（見 Core/DB.lua）
------------------------------------------------------------
function ns.RefreshSpec()
    local idx = GetSpecialization and GetSpecialization()
    ns.specIndex = idx
    ns.specID = idx and GetSpecializationInfo(idx) or nil
end

------------------------------------------------------------
-- 互斥偵測
--
-- 另一支冷卻管理器插件同樣會認領重錨暴雪的四條檢視器；兩支同時跑，檢視器會被兩邊
-- 輪流拉走，而且兩邊都在暴雪框上掛勾，taint 面加倍。所以不做「並存模式」：
-- 偵測到就彈窗讓玩家二選一，本插件在這次登入裡**什麼都不初始化**。
--
-- 資料夾名是功能上的識別字（IsAddOnLoaded／DisableAddOn 要用），顯示給玩家看的
-- 名稱一律從對方 TOC 的 Title 讀，不寫進語系檔。
------------------------------------------------------------
local CONFLICT_ADDON   = "Ayije_CDM"
local CONFLICT_FOLDERS = { "Ayije_CDM", "Ayije_CDM_Options" }

local function ConflictLoaded()
    local ok, loaded = pcall(C_AddOns.IsAddOnLoaded, CONFLICT_ADDON)
    return ok and loaded and true or false
end

-- OptionalDeps 保證它（若有啟用）比我們先載入，檔案層就判得出來
ns.conflict = ConflictLoaded()

local function ConflictTitle()
    local title = C_AddOns.GetAddOnMetadata(CONFLICT_ADDON, "Title")
    if type(title) ~= "string" or title == "" then return CONFLICT_ADDON end
    title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    return title
end

local function DisableAndReload(folders)
    local who = UnitName("player")
    for _, name in ipairs(folders) do
        pcall(C_AddOns.DisableAddOn, name, who)
    end
    ReloadUI()
end

local conflictPopup
function ns.ShowConflictPopup()
    local W = ns.W
    if not W then return end
    if not conflictPopup then
        local other = ConflictTitle()
        conflictPopup = W.CreateChoicePopup(UIParent, 480,
            L["%s and MiliUI Cooldown Manager both take over Blizzard's Cooldown Manager, so only one of them can be enabled."]:format(other),
            {
                { text = L["Disable %s and reload"]:format(other), color = "primary",
                  onClick = function() DisableAndReload(CONFLICT_FOLDERS) end },
                { text = L["Disable this addon for now"], color = "normal",
                  onClick = function() DisableAndReload({ ADDON }) end },
            })
    end
    conflictPopup:Show()
end

------------------------------------------------------------
-- 登入流程
------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    ns.conflict = ns.conflict or ConflictLoaded()
    if ns.conflict then
        -- 其餘初始化全部不跑：沒有 DB、沒有事件、沒有掛勾
        ns.ShowConflictPopup()
        return
    end

    ns.RefreshSpec()
    local ok = xpcall(ns.DB.Init, ns.ReportError)
    if not ok then return end
    ns.Events.Start()
    ns.ready = true
    ns.Fire("Loaded")
end)
