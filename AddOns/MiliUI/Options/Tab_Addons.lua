------------------------------------------------------------
-- 插件名冊的資料層：條目查詢、開設定的路由、待套用的開關
--
-- 這裡沒有任何介面。原本是「插件總覽」分頁（左清單＋右詳情），2026-11-28 併進
-- 「快速設定」（Options/QuickPanel.lua，卡片底部的開關列）之後分頁拿掉了，留下兩頁
-- 本來就共用的這一層：
--   · ns.AddonInfo：條目的標題／圖示／分組／啟用狀態、看得到的條目清單（CollectVisible）
--   · 開設定的路由（OpenSettings）：自製走 MiliUI_MenuEntries、第三方走斜線指令、再退到暴雪 Settings 分類
--   · 待套用的開關（SetDesired／ApplyPending）：批次的，按「套用並重載介面」才一次
--     Enable/DisableAddOn ＋ ReloadUI——停用本來就要重載才生效，攢一批只重載一次
-- 名冊（開關綁定、指令、說明覆蓋）在 Options/Roster.lua。
-- 用的人：快速設定、效能監控（Options/Tab_Perf.lua）、/miliui check（Api.lua）。
-- 檔名沿用 Tab_Addons.lua：改檔名等於 TOC 多一支新檔，玩家得重開遊戲才載得到。
------------------------------------------------------------
local _, ns = ...

local entriesByKey = {}
local autoByFolder = {}             -- 沒列名冊的插件的自動條目（快取，pending 的 key 才穩定）
local pending = {}                  -- key -> 期望的啟用狀態（跟現況不同才留著）
------------------------------------------------------------
-- 狀態查詢
------------------------------------------------------------
local function IsFolderEnabled(name)
    if not (C_AddOns.GetAddOnEnableState and Enum and Enum.AddOnEnableState) then return true end
    return C_AddOns.GetAddOnEnableState(name, (UnitName("player"))) ~= Enum.AddOnEnableState.None
end

-- 掃描而不是 GetAddOnInfo(name)：未安裝的名字丟進去行為不保證，掃描一定安全
local function GetInstalled()
    local installed = {}
    local total = C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0
    for i = 1, total do
        local name = C_AddOns.GetAddOnInfo(i)
        if name then installed[name] = true end
    end
    return installed
end

local function EntryEnabled(entry)
    return IsFolderEnabled(entry.folders[1])
end

local function EntryMeta(entry, field)
    return C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(entry.folders[1], field)
end

local function EntryTitle(entry)
    return EntryMeta(entry, "Title") or entry.folders[1]
end

local function StripCodes(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- 快速設定與效能監控（Options/Tab_Perf.lua）都照同一套規則把名冊攤成條目。
-- 各抄一份的話，哪天標題／圖示的取法變了就得記得改兩個地方。
-- ⚠ 這幾支只讀 entry.folders[1]，傳進來的表有 folders 就夠，不必是名冊裡的那筆。
ns.AddonInfo = {
    GetInstalled = GetInstalled,
    EntryMeta    = EntryMeta,
    EntryTitle   = EntryTitle,
    StripCodes   = StripCodes,
    EntryEnabled = EntryEnabled,
    -- OpenSettings／EntryCategory／CollectVisible 與待套用開關那幾支在下面定義完才補進來
}

------------------------------------------------------------
-- 用量：近期 CPU 與記憶體（快速設定的卡片在用；效能監控分頁有自己更完整的一套）
--
-- CPU 走 C_AddOnProfiler：引擎本來就一直在量，讀值只是查表。
--   回傳 ms/幀 與「佔整個遊戲一幀的幾 %」（這個插件 ÷ GetApplicationMetric，跟效能監控同一個算法）。
-- 記憶體要先 UpdateAddOnMemoryUsage()——那一下是整個 Lua 堆的掃描，會卡一下，
--   所以 MeasureMemory 有冷卻（MEM_COOLDOWN 秒內重複叫不重掃）、戰鬥中不掃，呼叫端只在開頁時叫。
-- 全部經過 pcall＋值域檢查：分析器可能整組不存在或被關掉；GetAddOnMemoryUsage 對暴雪內部插件會報錯。
------------------------------------------------------------
local MEM_COOLDOWN = 30
local memStamp

local function Num(ok, v)
    if not ok then return 0 end
    v = tonumber(v)
    if not v or v ~= v or v < 0 or v == math.huge then return 0 end   -- v ~= v 是 nan
    return v
end

local function ProfilerMetric()
    if type(C_AddOnProfiler) ~= "table" or type(C_AddOnProfiler.GetAddOnMetric) ~= "function"
            or type(Enum) ~= "table" or type(Enum.AddOnProfilerMetric) ~= "table" then
        return nil
    end
    if type(C_AddOnProfiler.IsEnabled) == "function" then
        local ok, on = pcall(C_AddOnProfiler.IsEnabled)
        if ok and on == false then return nil end
    end
    return Enum.AddOnProfilerMetric.RecentAverageTime
end

-- 回傳 ms, pct；量不到回 nil。pct 在拿不到整體數字時是 nil。
function ns.AddonInfo.EntryCPU(entry)
    local metric = ProfilerMetric()
    if not metric then return nil end
    local ms = 0
    for _, f in ipairs(entry.folders) do
        ms = ms + Num(pcall(C_AddOnProfiler.GetAddOnMetric, f, metric))
    end
    local app = type(C_AddOnProfiler.GetApplicationMetric) == "function"
        and Num(pcall(C_AddOnProfiler.GetApplicationMetric, metric)) or 0
    return ms, (app > 0) and (ms / app * 100) or nil
end

-- 回傳這次有沒有量過（任何一次）。force＝無視冷卻。
function ns.AddonInfo.MeasureMemory(force)
    if type(UpdateAddOnMemoryUsage) ~= "function" or type(GetAddOnMemoryUsage) ~= "function" then
        return false
    end
    local now = GetTime()
    if InCombatLockdown() then return memStamp ~= nil end
    if force or not memStamp or now - memStamp >= MEM_COOLDOWN then
        UpdateAddOnMemoryUsage()
        memStamp = now
    end
    return true
end

-- 回傳 KB；還沒量過回 nil。
function ns.AddonInfo.EntryMemKB(entry)
    if not memStamp then return nil end
    local kb = 0
    for _, f in ipairs(entry.folders) do
        if C_AddOns.IsAddOnLoaded(f) then
            kb = kb + Num(pcall(GetAddOnMemoryUsage, f))
        end
    end
    return kb
end

------------------------------------------------------------
-- 開啟該插件設定的路由：自製走 MiliUI_MenuEntries、第三方走斜線指令、
-- 再退到暴雪 Settings 分類（永遠會試）。解析不到就回 nil。
------------------------------------------------------------

-- 通用的分類搜尋：名冊指定名 → 剝掉色碼與「[標籤]」的 TOC 標題 → 資料夾名，
-- 逐一比對已註冊的 Settings 分類。比對前先正規化（剝色碼、去空白標點、轉小寫），
-- 「PremadeGroupsFilter」才對得上註冊名「Premade Groups Filter」。
-- 再借 AddonNames 的對照表反查：ParagonReputation 註冊的分類名是「聲望」，
-- 玩家看到的「巔峰聲望」是那張表改的——比對「改名後的顯示名」就能命中。
local function Norm(s)
    return (StripCodes(s or ""):gsub("[%s%p]", ""):lower())
end

------------------------------------------------------------
-- 指令 → 處理函式
--
-- 反向掃 _G 找「值等於這個指令的 SLASH_* 全域」，再從鍵名取出 token 去
-- SlashCmdList 拿處理函式。
--
-- ⚠ 不要反過來做（拿 token 去猜 SLASH_<token>N 全域）：那要求 token 大小寫
-- 與全域名一字不差、索引還得從 1 連續，MRT（token mrtSlash、指令排到 6）
-- 這種就抓不到。也不要查 hash_SlashCmdList——那只是「玩家輸入過」的快取。
-- 每次呼叫重掃：插件可能晚註冊（Ace 系、LoD），快取會讓晚到的永遠找不到。
------------------------------------------------------------
function ns.FindSlashHandler(cmd)
    if type(cmd) ~= "string" then return nil end
    cmd = string.lower(cmd)
    for k, v in pairs(_G) do
        if type(k) == "string" and type(v) == "string" and string.lower(v) == cmd then
            local token = k:match("^SLASH_(.+)%d+$")
            local fn = token and SlashCmdList[token]
            if type(fn) == "function" then return fn end
        end
    end
end

local function FindSettingsCategory(entry)
    if not (Settings and SettingsPanel and SettingsPanel.GetAllCategories) then return nil end
    local ok, cats = pcall(SettingsPanel.GetAllCategories, SettingsPanel)
    if not ok or type(cats) ~= "table" then return nil end

    local candidates = {}
    if entry.category then candidates[Norm(entry.category)] = true end
    local title = StripCodes(EntryTitle(entry))
    candidates[Norm(title)] = true
    local bare = title:match("^%[.-%]%s*(.+)$")
    if bare then candidates[Norm(bare)] = true end
    candidates[Norm(entry.folders[1])] = true
    candidates[""] = nil   -- 正規化後的空字串不當候選

    local renames = MiliUI and MiliUI.AddonListNames   -- AddonNames.lua 的對照表（僅 zhTW 有）
    for _, c in ipairs(cats) do
        if c.GetName then
            local okName, n = pcall(c.GetName, c)
            if okName and n then
                local plain = StripCodes(n)
                if candidates[Norm(plain)]
                        or (renames and renames[plain] and candidates[Norm(renames[plain])]) then
                    return c
                end
            end
        end
    end
end

local function ResolveOpen(entry)
    if entry.menuKey and MiliUI_MenuEntries then
        for _, e in ipairs(MiliUI_MenuEntries) do
            if e.key == entry.menuKey and type(e.OnClick) == "function" then
                return function() e.OnClick(e) end
            end
        end
    end
    -- 指令可以帶參數（例如 "/cell opt"）：查表用第一個字、其餘傳給處理器
    if entry.slash then
        local cmd, args = entry.slash:match("^(%S+)%s*(.-)$")
        local fn = ns.FindSlashHandler(cmd)
        if fn then
            -- 簽章是 (msg, editBox)，絕大多數不碰第二參數
            return function() pcall(fn, args or "") end
        end
    end
    local c = FindSettingsCategory(entry)
    if c then
        return function()
            local id = c.GetID and c:GetID()
            pcall(Settings.OpenToCategory, id or c)
        end
    end
    return nil
end

-- 按下「開啟設定」那一刻才解析入口：LoD 設定模組（如 tullaRange_Config）
-- 還沒載的話先拉起來重試，真的解析不到就講原因
-- 給 /miliui check 診斷用（Api.lua）
ns.ResolveEntryOpen = ResolveOpen
ns.FindEntryCategory = FindSettingsCategory

local function OpenEntrySettings(entry)
    local fn = ResolveOpen(entry)
    if not fn then
        for _, folder in ipairs(entry.folders) do
            if C_AddOns.IsAddOnLoadOnDemand and C_AddOns.IsAddOnLoadOnDemand(folder)
                    and not C_AddOns.IsAddOnLoaded(folder) then
                pcall(C_AddOns.LoadAddOn, folder)
            end
        end
        fn = ResolveOpen(entry)
    end
    if fn then
        -- 主設定視窗留著不關（玩家要連續調好幾支），但別家的設定視窗多半在較低的 strata，
        -- 所以退到後面讓路（Options.YieldFront，下次開窗或關窗時復原）
        ns.Options.YieldFront()
        fn()
    else
        ns.Print("這個插件還沒註冊設定入口（可能要等它載入完成），稍後再試。")
    end
end
ns.AddonInfo.OpenSettings = OpenEntrySettings

------------------------------------------------------------
-- 待套用的開關
------------------------------------------------------------
local function PendingCount()
    local n = 0
    for _ in pairs(pending) do n = n + 1 end
    return n
end

-- entriesByKey 是 CollectVisible 填的；還沒填過就直接翻名冊。
local function FindEntry(key)
    local e = entriesByKey[key]
    if e then return e end
    for _, r in ipairs(ns.AddonRoster.entries) do
        if r.key == key then return r end
    end
end

local function ApplyPending()
    local installed = GetInstalled()
    for key, desired in pairs(pending) do
        local entry = FindEntry(key)
        if entry then
            for _, folder in ipairs(entry.folders) do
                if installed[folder] then
                    -- 不帶 character 參數 = 所有角色一起開關，跟 LegacyAddons 同一套邏輯
                    if desired then
                        C_AddOns.EnableAddOn(folder)
                    else
                        C_AddOns.DisableAddOn(folder)
                    end
                end
            end
        end
    end
    ReloadUI()
end

-- 期望狀態跟現況一樣就不留（pending 只裝「真的要改」的）。locked 的不給動。
local function SetDesired(entry, desired)
    if entry.locked then return end
    if desired == EntryEnabled(entry) then
        pending[entry.key] = nil
    else
        pending[entry.key] = desired
    end
end

ns.AddonInfo.GetDesired     = function(entry) return pending[entry.key] end
ns.AddonInfo.SetDesired     = SetDesired
ns.AddonInfo.PendingCount   = PendingCount
ns.AddonInfo.ApplyPending   = ApplyPending
ns.AddonInfo.DiscardPending = function() wipe(pending) end

------------------------------------------------------------
-- 看得到的條目。分組照官方插件列表：讀主資料夾的 TOC Category（客戶端語系版）。
------------------------------------------------------------
local function EntryCategory(entry)
    local main = entry.folders[1]
    local cat = C_AddOns.GetAddOnMetadata(main, "Category-" .. GetLocale())
        or C_AddOns.GetAddOnMetadata(main, "Category")
    if not cat or cat == "" then cat = "其他" end
    return cat
end
ns.AddonInfo.EntryCategory = EntryCategory

-- 「看得到的條目」＝名冊裡有安裝的＋沒列名冊的已安裝插件（自動條目）。
-- 自動條目要快取（autoByFolder）：pending 的 key 才穩定。順手把 entriesByKey 填好，
-- 套用待套用變更時才查得到自動條目。
local function CollectVisible()
    local installed = GetInstalled()

    local covered = {}
    for _, e in ipairs(ns.AddonRoster.entries) do
        entriesByKey[e.key] = e
        for _, f in ipairs(e.folders) do covered[f] = true end
    end

    local visible = {}
    for _, e in ipairs(ns.AddonRoster.entries) do
        if installed[e.folders[1]] then visible[#visible + 1] = e end
    end
    for name in pairs(installed) do
        if not covered[name] then
            local e = autoByFolder[name]
            if not e then
                e = { key = name, folders = { name }, auto = true }
                autoByFolder[name] = e
            end
            entriesByKey[e.key] = e
            visible[#visible + 1] = e
        end
    end
    return visible
end
ns.AddonInfo.CollectVisible = CollectVisible
