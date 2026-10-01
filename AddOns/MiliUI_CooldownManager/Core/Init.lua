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

-- 顯示名：對方 TOC 的 Title 拿掉色碼與「[冷卻]」這種分類標籤，再補上資料夾名。
-- 標籤拿掉之後中文標題只剩「冷卻管理器」，跟暴雪的冷卻管理器、跟我們自己都分不出來，
-- 所以括號裡一定帶資料夾名（玩家在插件列表的說明欄看得到它）。
local function ConflictTitle()
    -- 沒安裝時（設定檔頁也會叫）有的客戶端版本會拋錯，包起來
    local ok, title = pcall(C_AddOns.GetAddOnMetadata, CONFLICT_ADDON, "Title")
    if not ok or type(title) ~= "string" or title == "" then return CONFLICT_ADDON end
    title = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    title = title:gsub("^%s*%[[^%]]*%]%s*", "")
    if title == "" or title == CONFLICT_ADDON then return CONFLICT_ADDON end
    return L["%s (%s)"]:format(title, CONFLICT_ADDON)
end

ns.ConflictTitle = ConflictTitle

local function DisableAndReload(folders)
    local who = UnitName("player")
    for _, name in ipairs(folders) do
        pcall(C_AddOns.DisableAddOn, name, who)
    end
    ReloadUI()
end
ns.DisableAndReload = DisableAndReload

-- 二選一彈窗。不用共用層的 W.CreateChoicePopup，原因有二：
--
-- 1. 那支會把彈窗登記進 UISpecialFrames（按 ESC 關）。暴雪的 CloseAllWindows 會把清單裡的
--    框全部 Hide，而它在登入過程裡不只一個觸發點（UIParent 的 OnShow、PLAYER_CONTROL_LOST、
--    全螢幕面板）——PLAYER_LOGIN 開的彈窗會在玩家看到之前就被收掉，之後也不會再開，
--    結果就是「兩支同時開著卻沒有任何提示」。這是非選不可的決定，不給 ESC 關。
-- 2. 三個選項都會重載介面，玩家要先看懂每顆按鈕會發生什麼才按得下去。橫排按鈕塞不下說明，
--    所以改成直排：一顆按鈕、底下一行灰字講後果。直排的按鈕也不怕歐語的長字串溢出。
--
-- 對方的存檔裡有這隻角色的設定時，最上面多一顆主按鈕「匯入」（Core/Import.lua）：讀它的、
-- 寫我們的、停用它、重載；這時其餘按鈕都是一般樣式（一組按鈕只有一個主動作）。
local conflictPopup

local function BuildConflictPopup()
    local W, P = ns.W, ns.P
    local WIDTH, PAD, GAP, BTN_H = 460, 16, 12, 24
    local short = CONFLICT_ADDON
    local Import = ns.Import
    local canImport = Import and Import.Available and Import.Available()

    local choices = {}
    if canImport then
        local again = Import.Imported() ~= nil
        local desc = L["Copies every %s profile into a new profile here (your existing profiles are left alone), then turns it off."]:format(short)
        if again then desc = desc .. " " .. L["Importing again replaces the profiles made by the last import."] end
        choices[#choices + 1] = {
            text = again and L["Re-import and switch to MiliUI"] or L["Import and switch to MiliUI"],
            desc = desc, color = "primary",
            onClick = function()
                local ok, err = xpcall(Import.FromAyije, geterrorhandler())
                if not ok and err then ns.Print(tostring(err)) end
            end,
        }
    end
    choices[#choices + 1] = {
        text = canImport and L["Switch to MiliUI without importing"] or L["Switch to MiliUI Cooldown Manager"],
        desc = L["Turns off %s. MiliUI Cooldown Manager keeps its current settings."]:format(short),
        color = canImport and "normal" or "primary",
        onClick = function() DisableAndReload(CONFLICT_FOLDERS) end,
    }
    choices[#choices + 1] = {
        text = L["Keep %s"]:format(short),
        desc = L["Turns off MiliUI Cooldown Manager. To switch later, re-enable it in the AddOns list."],
        color = "normal",
        onClick = function() DisableAndReload({ ADDON }) end,
    }

    local mask = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    mask:SetAllPoints(UIParent)
    mask:SetFrameStrata("FULLSCREEN_DIALOG")
    mask:SetFrameLevel(400)
    mask:EnableMouse(true)
    mask:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8" })
    mask:SetBackdropColor(0.15, 0.15, 0.15, 0.7)
    mask:Hide()

    local popup = W.CreateFrame(nil, UIParent, WIDTH, 100)
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetFrameLevel(410)
    popup:SetBackdropBorderColor(W.Accent(1))
    popup:SetPoint("CENTER")

    local inner = WIDTH - PAD * 2
    local msg = popup:CreateFontString(nil, "OVERLAY")
    msg:SetFontObject(W.fontNormal)
    msg:SetPoint("TOPLEFT", PAD, -PAD)
    msg:SetWidth(inner)
    msg:SetJustifyH("LEFT")
    msg:SetText(L["%s and MiliUI Cooldown Manager both take over Blizzard's Cooldown Manager, so only one can stay enabled. Pick the one to keep; the UI reloads right after."]:format(ConflictTitle()))

    local descs, prev = {}, msg
    for _, c in ipairs(choices) do
        local b = W.CreateButton(popup, c.text, c.color, inner, BTN_H)
        b:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -GAP)
        b:SetScript("OnClick", function()
            popup:Hide()
            c.onClick()
        end)
        local d = popup:CreateFontString(nil, "OVERLAY")
        d:SetFontObject(W.fontSmall)
        d:SetTextColor(0.6, 0.6, 0.6)
        d:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -4)
        d:SetWidth(inner)
        d:SetJustifyH("LEFT")
        d:SetText(c.desc)
        descs[#descs + 1] = d
        prev = d
    end

    -- 高度在 OnShow 量（字串換行後的高度要等字型就緒才準）
    popup:SetScript("OnShow", function(self)
        mask:Show()
        local h = PAD * 2 + (msg:GetStringHeight() or 0)
        for _, d in ipairs(descs) do
            h = h + GAP + BTN_H + 4 + (d:GetStringHeight() or 0)
        end
        P.Height(self, math.ceil(h))
    end)
    popup:SetScript("OnHide", function() mask:Hide() end)
    popup:Hide()
    return popup
end

function ns.ShowConflictPopup()
    if not ns.W then return end
    conflictPopup = conflictPopup or BuildConflictPopup()
    conflictPopup:Show()
end

------------------------------------------------------------
-- 引擎啟動（登入流程在 DB 就緒之後叫一次）
--
-- 順序有意義：Catalog（知道每條該有哪些 id）→ Viewers（開始掛暴雪檢視器，退避重試）
-- → Custom（自訂項目的事件）→ Glow（觸發發光的 manager 掛勾）→ Sound（讀取畫面靜音、光環格音效登記）
-- → Keybinds（綁定事件）
-- → Bars（容器與排程；Viewers 就緒時它會收到 ViewersReady）
-- → Interrupt／Resources／Pips／Castbar（資源條、自訂格子、施法條：在 Bars 上登記自己的面板容器）
-- → Visibility（alpha；面板排在條後面，資源條要讀核心技能的 alpha）。
-- 每一步各自隔離，一支拋錯不會讓後面的不啟動。
--
-- 設定檔／專精換了：清樣式簽章、重讀目錄、全部重排、重套 alpha——沒有任何選項要 /reload。
------------------------------------------------------------
local ENGINE = { "Catalog", "Viewers", "Custom", "Glow", "Sound", "Keybinds", "Bars",
                 "Interrupt", "Resources", "Pips", "Castbar", "Visibility" }

local function RestyleAll(reason)
    if ns.Decorate then ns.Decorate.InvalidateAll() end
    if ns.Catalog then ns.Catalog.Refresh(reason) end
    if ns.Bars then
        if reason == "profile" and ns.Bars.OnProfileChanged then
            ns.Bars.OnProfileChanged()
        else
            ns.Bars.RelayoutAll(reason)
        end
    end
    if ns.Visibility then ns.Visibility.ApplyAll() end
end
ns.RestyleAll = RestyleAll

-- 引擎有一步起不來：把暴雪的冷卻管理器還給暴雪（半套的引擎會把 item 停在畫面外、沒有路徑放回來），
-- 聊天框印一行。只做一次（Viewers 的延後安裝失敗也走這裡）。
function ns.EngineFailed(names)
    ns.engineFailed = ns.engineFailed or {}
    for _, n in ipairs(names or {}) do ns.engineFailed[#ns.engineFailed + 1] = n end
    if ns.released then return end
    if ns.Bars and ns.Bars.ReleaseAll then
        xpcall(ns.Bars.ReleaseAll, ns.ReportError, "engine")
    end
    ns.Print(L["Failed to start (%s). Blizzard's Cooldown Manager has been handed back; type /mcdm debug for the error."]
        :format(table.concat(ns.engineFailed, ", ")))
end

function ns.StartEngine()
    local failed = {}
    for _, name in ipairs(ENGINE) do
        local mod = ns[name]
        if mod and mod.Init then
            local ok = xpcall(mod.Init, ns.ReportError)
            if not ok then failed[#failed + 1] = name end
        end
    end
    ns.RegisterCallback("ProfileChanged", "engine", function() RestyleAll("profile") end)
    ns.RegisterCallback("SpecChanged", "engine", function() RestyleAll("spec") end)
    if #failed > 0 then ns.EngineFailed(failed) end
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
    if ns.Diag then xpcall(ns.Diag.Attach, ns.ReportError, _G.MiliUI_CooldownManager_DB) end
    ns.Events.Start()
    ns.ready = true
    ns.Fire("Loaded")
    ns.StartEngine()
end)
