if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end
local L = DamageMeterTools_L or function(s) return s end
local defaults = {
    texture = {
        source = "MATERIALS",
        lsmName = "Blizzard",
        customTexturePath = "",
        hardDisabled = false,
        restorePendingReload = false,
        backgroundMode = "TRANSPARENT_BORDER",
        backgroundAlpha = 35,
        compatMode = false,
        showBorder = false,
        displayMode = "DEFAULT",
    },

    hover = {
        hideDelay = 2,
    },

    visibility = {
        mode = "HEADER_FADE",
    },

    combatHide = {
        zoneFilter = {
            world = true,
            party = false,
            raid = false,
            pvp = false,
            arena = false,
        },
        fadeOutDelay = 2.0,
        fadeInTime = 0.2,
        fadeOutTime = 0.2,
        hiddenAlpha = 0,
    },
autoreset = {
    combatStart = false,
    bossStart = false,
    mythicStart = true,
    mythicEnter = false,
    instanceEnter = false,
    notify = true,
    confirmReset = false,
},
    frameBind = {
        enableSnap = true,

        snapGroupMode = "123",

        win2Position = "DOWN",
        win3Position = "RIGHT",

        spacing = 0,
        matchSize = true,
        sizeSyncMode = "123",

        tickInterval = 0.08,
        freePositions = {},
    },
    contextMenu = {
        requireShift = false,
    },

    theme = {
        style = "OCEAN",
    },

    locale = {
        override = "AUTO",
    },

    headerSkin = {
        style = "GLASS",
        mode = "STYLE",
        lsmName = "Blizzard",
        titleFontSize = 14,
        titleFontName = "GAME_DEFAULT",
        showModeSuffix = true,
        backgroundAlpha = 16,
        titleTextMode = "ALWAYS",
        showLines = false,

        titleTextColor = {
            r = 1.00,
            g = 0.82,
            b = 0.20,
            a = 1.00,
        },

        suffixTextColor = {
            r = 1.00,
            g = 1.00,
            b = 1.00,
            a = 1.00,
        },

        backgroundColor = {
            r = 0.02,
            g = 0.04,
            b = 0.06,
            a = 1.00,
        },
    },

    export = {
        topN = 5,
        cooldown = 1.5,
        hideRealm = true,
    },

    launcher = {
        minimap = {
            hide = false,
        },
    },

    errors = {
        notify = true,        -- 是否提示「有錯誤請看控制台」
        consoleOnly = true,   -- ✅ 建議：只在控制台顯示錯誤內容
        notifyInterval = 5,   -- 幾秒內最多提示一次
        logMax = 60,          -- 最多保存幾筆錯誤（SavedVariables）
        log = {},             -- 錯誤記錄（SavedVariables）
    },
    restrictedPVP = {
        notify = true,
    },
    modules = {
        Texture = true,
        Hover = true,
        FrameBind = true,
        Export = true,
        ContextMenu = true,
        HeaderSkin = true,
        CombatHide = false,
        AutoReset = false,
    },
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then
                dst[k] = {}
            end
            CopyDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

CopyDefaults(defaults, DamageMeterToolsDB)

DamageMeterTools = DamageMeterTools or {}

DamageMeterTools.DEFAULTS = defaults
DamageMeterTools._debounceTimers = DamageMeterTools._debounceTimers or {}
DamageMeterTools._callbacks = DamageMeterTools._callbacks or {}
DamageMeterTools.db = _G.DamageMeterToolsDB or DamageMeterToolsDB
-- =========================================================
-- ✅ 全域錯誤攔截器（顯示模組名稱）
-- =========================================================
DamageMeterTools._ErrorHandlerInstalled = DamageMeterTools._ErrorHandlerInstalled or false

DamageMeterTools._ModuleMap = {
    ["DamageMeterTools_HeaderVisual.lua"] = "HeaderSkin",
    ["DamageMeterTools_Texture.lua"] = "Texture",
    ["DamageMeterTools_FrameBind.lua"] = "FrameBind",
    ["DamageMeterTools_CombatHide.lua"] = "CombatHide",
    ["DamageMeterTools_ContextMenu.lua"] = "ContextMenu",
    ["DamageMeterTools_FormatExport.lua"] = "Export",
    ["DamageMeterTools_TexturePicker.lua"] = "TexturePicker",
    ["DamageMeterTools_FontPicker.lua"] = "FontPicker",
    ["DamageMeterTools_Console.lua"] = "Console",
    ["DamageMeterTools_Options.lua"] = "Options",
    ["DamageMeterTools_Launcher.lua"] = "Launcher",
    ["DamageMeterTools_Theme.lua"] = "Theme",
    ["DamageMeterTools_Config.lua"] = "Config",
    ["DamageMeterTools_AutoReset.lua"] = "AutoReset",
    ["Locale.lua"] = "LocaleCore",
    ["enUS.lua"] = "LocaleEN",
    ["zhTW.lua"] = "LocaleTW",
    ["zhCN.lua"] = "LocaleCN",
}

local function GetModuleDisplayName(module)
    if not module or module == "" then
        return L("未知模組") or "Unknown"
    end

    local key = "模組_" .. module
    local text = L(key)

    if text ~= key then
        return text
    end

    return module
end

local function TranslateLuaError(msg)
    if type(msg) ~= "string" then return msg end

    local prefix, core = msg:match("^(.-:%d+:)%s*(.+)$")
    core = core or msg

    local t

    t = core:match("attempt to index field '([^']+)' %(a nil value%)")
    if t then core = (L("嘗試索引欄位 '%s'（nil）") or core):format(t)
    else
        t = core:match("attempt to index local '([^']+)' %(a nil value%)")
        if t then core = (L("嘗試索引區域變數 '%s'（nil）") or core):format(t)
        else
            t = core:match("attempt to call method '([^']+)' %(a nil value%)")
            if t then core = (L("嘗試呼叫方法 '%s'（nil）") or core):format(t)
            else
                t = core:match("attempt to call global '([^']+)' %(a nil value%)")
                if t then core = (L("嘗試呼叫全域函式 '%s'（nil）") or core):format(t)
                else
                    if core:find("attempt to call a nil value", 1, true) then
                        core = L("嘗試呼叫 nil 值") or core
                    end
                end
            end
        end
    end

    t, func, detail = core:match("bad argument #(%d+) to '([^']+)' %((.+)%)")
    if t then
        core = (L("函式 '%s' 的第 %d 個參數錯誤（%s）") or core):format(func, tonumber(t), detail)
    end

    if core:find("attempt to perform arithmetic on a nil value", 1, true) then
        core = L("嘗試對 nil 做算術運算") or core
    end
    if core:find("attempt to compare nil", 1, true) then
        core = L("嘗試比較 nil") or core
    end
    if core:find("stack overflow", 1, true) then
        core = L("堆疊溢位") or core
    end

    if prefix then
        return prefix .. " " .. core
    end
    return core
end

-- ===== 錯誤記錄（去重）與提示 =====
DamageMeterTools._ErrorMap = DamageMeterTools._ErrorMap or {}
DamageMeterTools._ErrorList = DamageMeterTools._ErrorList or {}
DamageMeterTools._ErrorLogMax = 60
DamageMeterTools._ErrorNotifyLast = DamageMeterTools._ErrorNotifyLast or 0
DamageMeterTools._ErrorNotifySuppressed = DamageMeterTools._ErrorNotifySuppressed or 0
function DamageMeterTools:InitErrorLog()
    local db = self.db or DamageMeterToolsDB or {}
    db.errors = db.errors or {}
    db.errors.log = db.errors.log or {}

    self._ErrorMap = {}
    self._ErrorList = {}

    for i, item in ipairs(db.errors.log) do
        if item and item.key then
            self._ErrorMap[item.key] = item
            table.insert(self._ErrorList, item)
        end
    end
end
local function NormalizeErrorKey(msg)
    if type(msg) ~= "string" then return tostring(msg) end
    msg = msg:gsub(":%d+:", ":#:")
    msg = msg:gsub("%s+%[string \".-\"%]:(%d+):", " [string \"#\"]:#:")
    return msg
end

local function PushErrorLog(raw, module, display, summary)
    local key = NormalizeErrorKey(raw)
    local now = GetTime() or 0
    local map = DamageMeterTools._ErrorMap
    local list = DamageMeterTools._ErrorList

    local db = DamageMeterTools.db or DamageMeterToolsDB or {}
    db.errors = db.errors or {}
    db.errors.log = db.errors.log or {}
    local max = tonumber(db.errors.logMax) or DamageMeterTools._ErrorLogMax or 60

    local item = map[key]
    if not item then
        item = {
            key = key,
            raw = raw,
            summary = summary or raw,
            module = module,
            display = display,
            count = 1,
            first = now,
            last = now,
        }
        map[key] = item
        table.insert(list, 1, item)
        if #list > max then
            local removed = table.remove(list)
            if removed and removed.key then
                map[removed.key] = nil
            end
        end
    else
        item.count = (item.count or 1) + 1
        item.last = now
        item.raw = raw
        item.summary = summary or item.summary or raw
        item.module = module or item.module
        item.display = display or item.display
    end

    -- ✅ 存進 SavedVariables
    db.errors.log = list

    return item
end

function DamageMeterTools:GetErrorLog()
    return self._ErrorList or {}
end

function DamageMeterTools:ClearErrorLog()
    self._ErrorMap = {}
    self._ErrorList = {}

    local db = self.db or DamageMeterToolsDB or {}
    db.errors = db.errors or {}
    db.errors.log = {}
end

local function ShouldNotifyError()
    local db = DamageMeterTools.db or DamageMeterToolsDB or {}
    db.errors = db.errors or {}
    if db.errors.notify == false then
        return false
    end

    local now = GetTime() or 0
    local interval = tonumber(db.errors.notifyInterval) or 5
    if (now - (DamageMeterTools._ErrorNotifyLast or 0)) < interval then
        DamageMeterTools._ErrorNotifySuppressed = (DamageMeterTools._ErrorNotifySuppressed or 0) + 1
        return false
    end
    return true
end

function DamageMeterTools:ReportError(err)
    local raw = tostring(err or (L("未知錯誤") or "unknown error"))

    -- 抓出檔名（一定要用 raw，不能用翻譯後的）
    local file =
        raw:match("DamageMeterTools\\([^\\]+%.lua)") or
        raw:match("DamageMeterTools/([^/]+%.lua)") or
        raw:match("Locale\\([^\\]+%.lua)") or
        raw:match("Locale/([^/]+%.lua)")

    local module = self._ModuleMap[file] or file or "Unknown"
    local display = GetModuleDisplayName(module)
    local label = "DMT " .. (L("錯誤") or "Error")

    local msg = TranslateLuaError(raw) or raw

    -- ✅ 記錄到控制台（去重）
    PushErrorLog(raw, module, display, msg)

    -- ✅ 永遠只跳一行提醒（不顯示詳細錯誤）
    if ShouldNotifyError() then
        print("|cffff8800[DMT]|r " .. (L("偵測到錯誤，請至控制台查看。") or "Errors detected. Please check console."))
        DamageMeterTools._ErrorNotifyLast = GetTime() or 0
        DamageMeterTools._ErrorNotifySuppressed = 0
    end
end

function DamageMeterTools:InstallErrorHandler()
    if self._ErrorHandlerInstalled then return end
    self._ErrorHandlerInstalled = true

    -- ✅ 記住原本 handler
    self._origErrorHandler = geterrorhandler()

    -- ✅ 我們自己的 handler
    self._DMT_ErrorHandler = function(err)
        if DamageMeterTools and DamageMeterTools.ReportError then
            DamageMeterTools:ReportError(err)
        else
            print("|cffff0000[DMT Error]|r " .. tostring(err))
        end

        local db = DamageMeterTools.db or DamageMeterToolsDB or {}
        db.errors = db.errors or {}

    end

    seterrorhandler(self._DMT_ErrorHandler)
end

-- ✅ 如果被其他插件改掉，強制再裝回來
function DamageMeterTools:EnsureErrorHandler()
    if not self._DMT_ErrorHandler then return end
    if geterrorhandler() ~= self._DMT_ErrorHandler then
        self._origErrorHandler = geterrorhandler()
        seterrorhandler(self._DMT_ErrorHandler)
    end
end

-- =========================================================
-- ✅ Taint / Blocked Action 監聽（避免沒看到錯誤）
-- =========================================================
DamageMeterTools._TaintCache = DamageMeterTools._TaintCache or {}

local function ReportTaintOnce(key, text)
    if DamageMeterTools._TaintCache[key] then return end
    DamageMeterTools._TaintCache[key] = true
    print("|cffff8800[DMT 警告]|r " .. text)
end

local taintWatcher = CreateFrame("Frame")
taintWatcher:RegisterEvent("ADDON_ACTION_BLOCKED")
taintWatcher:RegisterEvent("ADDON_ACTION_FORBIDDEN")

taintWatcher:SetScript("OnEvent", function(_, event, addon, func)
    if addon ~= "DamageMeterTools" then return end
    local msg = string.format(
        L("偵測到受保護動作被阻擋：%s") or "Blocked protected action: %s",
        tostring(func or "unknown")
    )
    ReportTaintOnce(event .. ":" .. tostring(func), msg)
end)
DamageMeterTools:InitErrorLog()
DamageMeterTools:InstallErrorHandler()

-- ✅ 保險：載入後再補一次
C_Timer.After(2, function()
    DamageMeterTools:EnsureErrorHandler()
end)

-- ✅ 每次有新插件載入時都再檢查
local _dmtErrFrame = CreateFrame("Frame")
_dmtErrFrame:RegisterEvent("ADDON_LOADED")
_dmtErrFrame:RegisterEvent("PLAYER_LOGIN")
_dmtErrFrame:SetScript("OnEvent", function()
    DamageMeterTools:EnsureErrorHandler()
end)

function DamageMeterTools:Debounce(key, delay, func)
    if type(func) ~= "function" then
        return
    end

    key = tostring(key or "default")
    delay = tonumber(delay) or 0

    local t = self._debounceTimers[key]
    if t then
        t:Cancel()
        self._debounceTimers[key] = nil
    end

    self._debounceTimers[key] = C_Timer.NewTimer(delay, function()
        self._debounceTimers[key] = nil
        local ok, err = pcall(func)
        if not ok then
            print("|cffff4040[DMT]|r " .. (L("Debounce 錯誤") or "Debounce error") .. ": " .. tostring(err))
        end
    end)
end

function DamageMeterTools:RegisterSettingsCallback(key, func)
    if type(func) ~= "function" then
        return
    end

    local k = tostring(key or "ALL")
    self._callbacks[k] = self._callbacks[k] or {}
    table.insert(self._callbacks[k], func)
end

function DamageMeterTools:NotifySettingsChanged(changedKey)
    local function SafeRun(func)
        local ok, err = pcall(func)
        if not ok then
            print("|cffff4040[DMT]|r " .. (L("設定回呼錯誤") or "Settings callback error") .. ": " .. tostring(err))
        end
    end

    if changedKey == nil or changedKey == "ALL" then
        for _, list in pairs(self._callbacks) do
            if type(list) == "table" then
                for _, func in ipairs(list) do
                    SafeRun(func)
                end
            elseif type(list) == "function" then
                SafeRun(list)
            end
        end
        return
    end

    local key = tostring(changedKey)

    local list = self._callbacks[key]
    if type(list) == "table" then
        for _, func in ipairs(list) do
            SafeRun(func)
        end
    elseif type(list) == "function" then
        SafeRun(list)
    end

    local allList = self._callbacks["ALL"]
    if type(allList) == "table" then
        for _, func in ipairs(allList) do
            SafeRun(func)
        end
    elseif type(allList) == "function" then
        SafeRun(allList)
    end
end

local function GetLiveDB()
    _G.DamageMeterToolsDB = _G.DamageMeterToolsDB or {}
    return _G.DamageMeterToolsDB
end

local function EnsureModulesTable()
    local db = GetLiveDB()
    db.modules = db.modules or {}
    return db, db.modules
end

function DamageMeterTools:IsModuleEnabled(key, defaultValue)
    local db, modules = EnsureModulesTable()
    self.db = db

    key = tostring(key or "")
    if key == "" then
        return defaultValue ~= false
    end

    if modules[key] == nil then
        modules[key] = (defaultValue ~= false) and true or false
    end

    return modules[key] == true
end

function DamageMeterTools:SetModuleEnabled(key, enabled)
    local db, modules = EnsureModulesTable()
    self.db = db

    key = tostring(key or "")
    if key == "" then
        return
    end

    modules[key] = enabled and true or false
    _G.DamageMeterToolsDB = db
    DamageMeterToolsDB = db

    self:NotifySettingsChanged(key)
end

function DamageMeterTools:GetDB()
    local db = GetLiveDB()
    self.db = db
    DamageMeterToolsDB = db
    return db
end

function DamageMeterTools_IsRestrictedPVPZone()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then
        return false
    end

    return instanceType == "pvp" or instanceType == "arena"
end

local _dmtRestrictedPVPState = nil
local _dmtRestrictedPVPNotifyLastTime = 0
local _dmtRestrictedPVPNotifyLastKind = nil
local _dmtRestrictedPVPNotifyCooldown = 2.0

local function DMT_GetRestrictedPVPLocale()
    if DamageMeterTools_Locale and DamageMeterTools_Locale.GetCurrentLocale then
        local ok, locale = pcall(function()
            return DamageMeterTools_Locale:GetCurrentLocale()
        end)
        if ok and type(locale) == "string" and locale ~= "" then
            return locale
        end
    end

    return GetLocale() or "enUS"
end

local function DMT_GetRestrictedPVPMessage(kind)
    if kind == "pause" then
        return L("已進入戰場/競技場，已暫停材質與標題列美化，以降低暴雪警告機率。")
            or "Entered Battleground/Arena: Texture and Header Skin have been temporarily disabled to reduce Blizzard UI warnings."
    elseif kind == "resume" then
        return L("已離開戰場/競技場，已恢復材質與標題列美化。")
            or "Left Battleground/Arena: Texture and Header Skin have been restored."
    end

    return nil
end

local function DMT_RefreshRestrictedPVPModules()
    if DamageMeterTools and DamageMeterTools.NotifySettingsChanged then
        DamageMeterTools:NotifySettingsChanged("Texture")
        DamageMeterTools:NotifySettingsChanged("HeaderSkin")
        DamageMeterTools:NotifySettingsChanged("Hover")
    end

    if DamageMeterTools_TextureForceRebuild then
        DamageMeterTools_TextureForceRebuild()
    end

    if DamageMeterTools_HeaderSkinApplyNow then
        DamageMeterTools_HeaderSkinApplyNow()
    end

    if DamageMeterTools_HoverApplyNow then
        DamageMeterTools_HoverApplyNow()
    end
end

local function DMT_ShouldNotifyRestrictedPVP(kind)
    local now = GetTime() or 0

    if _dmtRestrictedPVPNotifyLastKind == kind and (now - (_dmtRestrictedPVPNotifyLastTime or 0)) < _dmtRestrictedPVPNotifyCooldown then
        return false
    end

    _dmtRestrictedPVPNotifyLastTime = now
    _dmtRestrictedPVPNotifyLastKind = kind
    return true
end

local function DMT_NotifyRestrictedPVP(kind)
    local db = GetLiveDB()
    db.restrictedPVP = db.restrictedPVP or {}

    if db.restrictedPVP.notify == false then
        return
    end

    local msg = DMT_GetRestrictedPVPMessage(kind)
    if not msg or msg == "" then
        return
    end

    if not DMT_ShouldNotifyRestrictedPVP(kind) then
        return
    end

    print("|cff66ccff[DMT]|r " .. msg)
end

function DamageMeterTools_HandleRestrictedPVPZoneChange()
    local restricted = DamageMeterTools_IsRestrictedPVPZone()

    if _dmtRestrictedPVPState == nil then
        _dmtRestrictedPVPState = restricted
        DMT_RefreshRestrictedPVPModules()

        if restricted then
            DMT_NotifyRestrictedPVP("pause")
        end
        return
    end

    if _dmtRestrictedPVPState == restricted then
        return
    end

    _dmtRestrictedPVPState = restricted
    DMT_RefreshRestrictedPVPModules()
    DMT_NotifyRestrictedPVP(restricted and "pause" or "resume")
end

local _dmtRestrictedPVPFrame = CreateFrame("Frame")
_dmtRestrictedPVPFrame:RegisterEvent("PLAYER_LOGIN")
_dmtRestrictedPVPFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
_dmtRestrictedPVPFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
_dmtRestrictedPVPFrame:RegisterEvent("ZONE_CHANGED_INDOORS")
_dmtRestrictedPVPFrame:SetScript("OnEvent", function()
    C_Timer.After(0, function()
        DamageMeterTools_HandleRestrictedPVPZoneChange()
    end)
end)
