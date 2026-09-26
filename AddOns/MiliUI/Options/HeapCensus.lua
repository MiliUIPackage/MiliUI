------------------------------------------------------------
-- 堆普查（效能監控 › 記憶體頁的「reload 後普查」，一次性）
--
-- 洩漏追蹤只分得出「插件 vs 暴雪與未歸戶」。後者在長的時候（2026-09-27 實測：
-- reload 後站著不動 3 分鐘，暴雪那塊 +336 MB、插件 +9），GetAddOnMemoryUsage
-- 就沒話說了。這裡改問「東西掛在哪張表上」：
--
--   普查    從 _G 出發把所有看得到的表爬一遍，每個頂層名字底下有幾格、字串
--           幾 bytes；再用 EnumerateFrames 補上沒名字的框（依最近的具名祖先
--           歸類）。reload 當下爬一次、STAY_SEC 秒後再爬一次，相減。
--   建立點  同一段期間掛勾 CreateFrame／CreateFromMixins／CreateTexture／
--           CreateFontString，記呼叫的檔案與行號 —— 藏在區域變數裡、_G 走不到
--           的東西，建立的那一刻還是看得到。
--
-- ⚠ 盲區：WoW 沒有 debug.getupvalue，只存在檔案區域變數裡的表普查看不到。
--   所以報告一定附「堆長了多少 vs 普查看到長了多少」——差很多就代表東西藏在
--   區域變數裡，要看建立點那一欄。
-- ⚠ 成本：爬的過程切成每幀 BUDGET_MS 毫秒（不卡），但 visited 表會暫時吃掉
--   幾十 MB；兩次回收各頓一下。所以是一次性的：跑完自動關掉。
-- ⚠ 只讀不寫：暴雪的表只做 pairs，不寫任何欄位（見 12.1 taint 筆記）。
--   秘密值跳過不碰；禁用框的表 pairs 會報錯，每張表各自 pcall。
------------------------------------------------------------
local _, ns = ...

local STAY_SEC   = 180          -- 兩次普查的間隔
local BUDGET_MS  = 6            -- 每幀爬多久
local CELL_BYTES = 40           -- 一格表欄位的估計大小（5.1 的 Node ≈ 32～40）
local KEEP_ROOTS, KEEP_SUBS, KEEP_FRAMES, KEEP_SITES = 40, 60, 25, 30

local HC = {}
ns.HeapCensus = HC

local isSecret = issecretvalue or function() return false end
local SKIP_ROOTS = { _G = true, MiliUI_DB = true }

local function DB()
    if not MiliUI_DB then MiliUI_DB = {} end
    local perf = MiliUI_DB.perf
    if type(perf) ~= "table" then perf = {}; MiliUI_DB.perf = perf end
    local db = perf.census
    if type(db) ~= "table" then db = {}; perf.census = db end
    if type(db.armed) ~= "boolean" then db.armed = false end
    return db
end

function HC.IsArmed() return DB().armed end
function HC.SetArmed(on)
    DB().armed = on and true or false
    if on then
        ns.Print("堆普查：下次 /reload 後自動執行一次。reload 完站著不動約 4 分鐘，"
            .. "跑完會在聊天視窗報告並自動取消勾選。")
    end
end
function HC.GetLast() return DB().last end

------------------------------------------------------------
-- 建立點（掛勾只在普查期間記帳；hooksecurefunc 拆不掉，所以用旗標關）
------------------------------------------------------------
local recording = false
local sites = {}
local MY_FILE = "HeapCensus%.lua"

local function CallSite()
    local stack = debugstack(3, 8, 0) or ""
    local found = {}
    for path, line in stack:gmatch("([%w_%-%./\\ ]-%.lua)\"?%]?:(%d+)") do
        if not path:find(MY_FILE) then
            local short = path:gsub("^.-[Aa]dd[Oo]ns[/\\]", "")
            found[#found + 1] = short .. ":" .. line
            if #found == 2 then break end
        end
    end
    if not found[1] then return "?" end
    return found[2] and (found[1] .. " ← " .. found[2]) or found[1]
end

local function Count(kind)
    if not recording then return end
    local key = kind .. " " .. CallSite()
    sites[key] = (sites[key] or 0) + 1
end

local hooked = false
local function InstallHooks()
    if hooked then return end
    hooked = true
    hooksecurefunc("CreateFrame", function() Count("CreateFrame") end)
    if CreateFromMixins then
        hooksecurefunc("CreateFromMixins", function() Count("CreateFromMixins") end)
    end
    local meta = getmetatable(CreateFrame("Frame"))
    local idx = meta and meta.__index
    if type(idx) == "table" then
        hooksecurefunc(idx, "CreateTexture", function() Count("CreateTexture") end)
        hooksecurefunc(idx, "CreateFontString", function() Count("CreateFontString") end)
    end
end

------------------------------------------------------------
-- 普查本體（coroutine，每幀 BUDGET_MS）
------------------------------------------------------------
local visited
local roots, subs, frames       -- label -> { n = 格數, b = 字串 bytes }／框數
local sliceStart = 0

local function Bump(map, label, n, b)
    local e = map[label]
    if not e then e = { n = 0, b = 0 }; map[label] = e end
    e.n, e.b = e.n + n, e.b + b
end

local tStack, lStack = {}, {}

-- 掃一張表的直接內容；子表推進堆疊。sub = 這張表所屬的第二層標籤（nil＝它就是根）
local function ScanOne(t, root, sub)
    local n, b = 0, 0
    for k, v in pairs(t) do
        n = n + 1
        if not isSecret(k) then
            local tk = type(k)
            if tk == "string" then b = b + #k
            elseif tk == "table" and not visited[k] then
                tStack[#tStack + 1] = k
                lStack[#lStack + 1] = sub or (root .. ".[表]")
            end
        end
        if not isSecret(v) then
            local tv = type(v)
            if tv == "string" then b = b + #v
            elseif tv == "table" and not visited[v] then
                tStack[#tStack + 1] = v
                lStack[#lStack + 1] = sub or (root .. "." .. (type(k) == "string" and not isSecret(k) and k or "[" .. type(k) .. "]"))
            end
        end
    end
    return n, b
end

local function Crawl(root, t)
    local base = #tStack
    tStack[base + 1], lStack[base + 1] = t, false
    while #tStack > base do
        local top = #tStack
        local cur, sub = tStack[top], lStack[top]
        tStack[top], lStack[top] = nil, nil
        if not visited[cur] then
            visited[cur] = true
            local ok, n, b = pcall(ScanOne, cur, root, sub or nil)
            if ok then
                -- +1 當作表頭本身（空表也有成本）
                Bump(roots, root, n + 1, b)
                if sub then Bump(subs, sub, n + 1, b) end
            end
            if debugprofilestop() - sliceStart > BUDGET_MS then coroutine.yield() end
        end
    end
end

local function FrameLabel(f)
    local cur = f
    for _ = 1, 25 do
        local ok, name = pcall(cur.GetName, cur)
        if ok and type(name) == "string" and not isSecret(name) then return "框@" .. name end
        local ok2, parent = pcall(cur.GetParent, cur)
        if not ok2 or not parent then break end
        cur = parent
    end
    return "框@（無名、無具名祖先）"
end

local function Census()
    visited = {}               -- 強參照：弱表在爬的途中被回收，位址重用會漏算
    roots, subs, frames = {}, {}, {}
    visited[_G] = true

    local names = {}
    for k, v in pairs(_G) do
        if type(k) == "string" and not SKIP_ROOTS[k] and not isSecret(v) and type(v) == "table" then
            names[#names + 1] = k
        end
    end
    table.sort(names)         -- 固定順序：共用的表兩次都算給同一個名字，差值才有意義
    for _, k in ipairs(names) do
        local v = rawget(_G, k)
        if type(v) == "table" and not visited[v] then Crawl(k, v) end
    end

    local f = EnumerateFrames()
    while f do
        if not visited[f] then
            local label = FrameLabel(f)
            frames[label] = (frames[label] or 0) + 1
            Crawl(label, f)
        end
        f = EnumerateFrames(f)
    end

    local snap = { roots = roots, subs = subs, frames = frames }
    visited, roots, subs, frames = nil, nil, nil, nil
    return snap
end

------------------------------------------------------------
-- 比對與報告
------------------------------------------------------------
local function Est(e) return e and (e.n * CELL_BYTES + e.b) or 0 end

local function DiffTop(a, b, keep)
    local out = {}
    for label, eb in pairs(b) do
        local d = Est(eb) - Est(a[label])
        if d > 64 * 1024 then
            out[#out + 1] = { label = label, mb = d / 1048576,
                cells = eb.n - (a[label] and a[label].n or 0), nowMB = Est(eb) / 1048576 }
        end
    end
    table.sort(out, function(x, y) return x.mb > y.mb end)
    while #out > keep do table.remove(out) end
    return out
end

local function SumEst(map)
    local s = 0
    for _, e in pairs(map) do s = s + Est(e) end
    return s / 1048576
end

local function Report(A, B, heapA, heapB, secs)
    local r = {
        when = date("%Y-%m-%d %H:%M"), secs = secs,
        heapA = heapA / 1024, heapB = heapB / 1024,
        seenA = SumEst(A.roots), seenB = SumEst(B.roots),
        roots = DiffTop(A.roots, B.roots, KEEP_ROOTS),
        subs = DiffTop(A.subs, B.subs, KEEP_SUBS),
    }
    local fr = {}
    for label, n in pairs(B.frames) do
        local d = n - (A.frames[label] or 0)
        if d > 0 then fr[#fr + 1] = { label = label, n = d } end
    end
    table.sort(fr, function(x, y) return x.n > y.n end)
    while #fr > KEEP_FRAMES do table.remove(fr) end
    r.frames = fr
    local st = {}
    for key, n in pairs(sites) do st[#st + 1] = { site = key, n = n } end
    table.sort(st, function(x, y) return x.n > y.n end)
    while #st > KEEP_SITES do table.remove(st) end
    r.sites = st
    return r
end

local function PrintReport(r)
    ns.Print(("堆普查完成（%d 秒）：堆 %.0f → %.0f MB（%+.0f），普查看得到的部分 %.0f → %.0f MB（%+.0f）")
        :format(r.secs, r.heapA, r.heapB, r.heapB - r.heapA, r.seenA, r.seenB, r.seenB - r.seenA))
    for i = 1, math.min(6, #r.roots) do
        local e = r.roots[i]
        print(("  |cffffcc66%+.1f MB|r  %s  |cff888888(+%d 格)|r"):format(e.mb, e.label, e.cells))
    end
    if r.sites[1] then
        print("  建立次數最多：")
        for i = 1, math.min(4, #r.sites) do
            print(("    %d×  %s"):format(r.sites[i].n, r.sites[i].site))
        end
    end
    if (r.heapB - r.heapA) > 2 * math.max(r.seenB - r.seenA, 1) then
        print("  |cff999999堆長的遠多於普查看到的 —— 多半藏在區域變數裡，看建立點那幾行。|r")
    end
    print("  |cff999999完整結果已存檔，/reload 後可以交給 Claude 讀。|r")
end

------------------------------------------------------------
-- 驅動
------------------------------------------------------------
local driver = CreateFrame("Frame")
driver:Hide()
local co

local function Run()
    local startT = GetTime()
    if ns.LagWatch and ns.LagWatch.Suppress then ns.LagWatch.Suppress(3) end
    collectgarbage("collect")
    local heapA = collectgarbage("count")
    recording = true
    local A = Census()

    local waitUntil = startT + STAY_SEC
    while GetTime() < waitUntil do coroutine.yield() end

    recording = false
    if ns.LagWatch and ns.LagWatch.Suppress then ns.LagWatch.Suppress(3) end
    collectgarbage("collect")
    local heapB = collectgarbage("count")
    local B = Census()

    local r = Report(A, B, heapA, heapB, math.floor(GetTime() - startT))
    A, B = nil, nil
    wipe(sites)
    local db = DB()
    db.last = r
    db.armed = false
    collectgarbage("collect")
    PrintReport(r)
    if HC.onDone then HC.onDone() end
end

driver:SetScript("OnUpdate", function(self)
    if InCombatLockdown() then return end   -- 戰鬥中暫停，不跟戰鬥搶幀
    sliceStart = debugprofilestop()
    local ok, err = coroutine.resume(co)
    if not ok then
        self:Hide()
        recording = false
        DB().armed = false
        ns.Print("堆普查中斷：" .. tostring(err))
        return
    end
    if coroutine.status(co) == "dead" then self:Hide() end
end)

driver:RegisterEvent("PLAYER_ENTERING_WORLD")
driver:SetScript("OnEvent", function(self, _, isLogin, isReload)
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    if not ((isLogin or isReload) and DB().armed) then return end
    InstallHooks()
    ns.Print(("堆普查開始：先爬一次，%d 秒後再爬一次比對。這段期間請站著不動。")
        :format(STAY_SEC))
    co = coroutine.create(Run)
    self:Show()
end)
