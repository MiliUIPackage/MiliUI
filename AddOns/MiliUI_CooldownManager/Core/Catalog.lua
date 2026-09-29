------------------------------------------------------------
-- 目錄：cooldownID → 法術資料，與每一條的有序清單
--
--   ns.Catalog.Bar(barKey)     有序 cooldownID 陣列（已套本專精的 order／groupOf／hidden）
--   ns.Catalog.Info(id)        { spellID, overrideSpellID, icon, name, category, equipSlot,
--                                hasAura, charges, isInvisible, isKnown, effectiveCategory, home }
--   ns.Catalog.Refresh(reason) 重讀；內容（簽章）變了才廣播 "CatalogChanged"
--   ns.Catalog.IsPaused()      暴雪冷卻管理器設定面板開著 ⇒ true（Bars 暫停重排）
--
-- 資料來源只有兩個明文 API：`C_CooldownViewer.GetCooldownViewerCategorySet(category, true)`
-- 與 `GetCooldownViewerCooldownInfo(id)`，全部 pcall，欄位過 canaccessvalue 才收。
--
-- 玩家在暴雪面板排的順序與分類覆寫：解碼 `C_CooldownViewer.GetLayoutData()`。
--   格式 "<編碼版本>|<Base64>"，編碼版本目前 1：
--   Base64 → DecodeBase64 → DecompressString(Deflate) → DeserializeCBOR → 表
--     data[1]                          存檔格式版本（目前 5；4 起 data[2] 才是 layoutID）
--     data[2][specTag]                 這個專精作用中的 layoutID
--     data[3][specTag][layoutID][1]    有序 cooldownID（**跨所有類別的一條**）
--     data[3][specTag][layoutID][2]    { [category] = { cooldownID, … } } 分類覆寫
--   specTag = classID × 10 + 專精序號。
--   解不開、版本不認得、這個專精用的是預設版面（沒有存檔）→ 退回類別集合的原始順序，
--   **無感**：不印訊息、不報錯，只在 /mcdm debug 看得到走了哪條（C.source）。
--
-- ⚠ 為什麼自己解碼，不問暴雪的 CooldownViewerSettings:GetDataProvider()：
--   它的 GetOrderedCooldownIDsForCategory 會在第一次呼叫時**建快取並寫回自己的欄位**
--   （displayData）。從插件呼叫就是污染的執行在寫暴雪的表，之後暴雪自己的檢視器讀那份
--   快取時整條執行都帶污染，讀到秘密值就炸（[[wow-121-secret-values]]「暴雪會讀的欄位
--   一個都不能寫」）。自己解碼只讀不寫。
--
-- 條的成員規則（照暴雪 DataProvider 的語意）：
--   * 候選池是八個類別集合串起來的順序：Essential、Utility、TrackedBuff、TrackedBar、
--     EquipSlotEssential、EquipSlotTracked、SpecAgnosticEssential、SpecAgnosticTracked
--     （enum 值執行時從 Enum.CooldownViewerCategory 解析，不寫死數字）。
--   * 每個 id 的**有效類別**＝分類覆寫 > （HideByDefault 旗標 ⇒ 隱藏）> 資料本身的類別。
--   * 條只收有效類別等於自己那一類的 id（essential ← Essential…），而且 isKnown。
--     12.1 新增的四個類別（裝備欄、不分專精）是**候選池**：玩家在暴雪面板把它們拖進
--     核心／輔助／增益之後，覆寫的類別就是那一條，自然併進去；還留在原類別的，暴雪
--     檢視器也不會為它建框，所以不列（列了會變成永遠的空位／占位格）。
------------------------------------------------------------
local _, ns = ...

ns.Catalog = {}
local C = ns.Catalog

local EMPTY = setmetatable({}, { __newindex = function() error("read-only") end })

-- 四條暴雪檢視器對應的條與類別
C.SOURCE_BARS = { "essential", "utility", "buffs", "buffbars" }
local BAR_CATEGORY_NAME = {
    essential = "Essential",
    utility   = "Utility",
    buffs     = "TrackedBuff",
    buffbars  = "TrackedBar",
}
C.BAR_CATEGORY_NAME = BAR_CATEGORY_NAME

-- 候選池的順序＝暴雪 DataProvider 串接類別的順序；home 是「這一類預設歸哪條」（給設定介面分區用）
local POOL = {
    { name = "Essential",             home = "essential" },
    { name = "Utility",               home = "utility" },
    { name = "TrackedBuff",           home = "buffs" },
    { name = "TrackedBar",            home = "buffbars" },
    { name = "EquipSlotEssential",    home = "essential" },
    { name = "EquipSlotTracked",      home = "buffs" },
    { name = "SpecAgnosticEssential", home = "essential" },
    { name = "SpecAgnosticTracked",   home = "buffs" },
}

local HIDE_BY_DEFAULT = 2          -- Enum.CooldownSetSpellFlags.HideByDefault（取不到 Enum 時的退路）
local HIDDEN = "hidden"            -- 有效類別：不在任何檢視器
local SUPPORTED_DATA_VERSION = { [4] = true, [5] = true }
local ENCODING_VERSION = 1

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
-- 明文才收：秘密值、讀不到的一律當沒有
local function Plain(v)
    if v == nil then return nil end
    if ns.IsSecret and ns.IsSecret(v) then return nil end
    local can = _G.canaccessvalue
    if can and not can(v) then return nil end
    return v
end
C.Plain = Plain

local function EnumCategory(name)
    local E = Enum and Enum.CooldownViewerCategory
    local v = E and E[name]
    return type(v) == "number" and v or nil
end

local function HideByDefaultFlag()
    local E = Enum and Enum.CooldownSetSpellFlags
    local v = E and E.HideByDefault
    return type(v) == "number" and v or HIDE_BY_DEFAULT
end

-- 位元測試不靠 bit 函式庫（離線測試也跑得動）
local function HasFlag(flags, flag)
    if type(flags) ~= "number" or type(flag) ~= "number" or flag <= 0 then return false end
    return (flags % (flag * 2)) >= flag
end
C.HasFlag = HasFlag

-- CBOR 解回來的表，鍵有可能是數字也可能是字串；兩種都試
local function Get(t, k)
    if type(t) ~= "table" or k == nil then return nil end
    local v = t[k]
    if v == nil then v = t[tostring(k)] end
    if v == nil and type(k) == "string" then v = t[tonumber(k)] end
    return v
end

function C.SpecTag()
    local classID = select(3, UnitClass("player"))
    local idx = ns.specIndex
    if idx == nil then
        local fn = (C_SpecializationInfo and C_SpecializationInfo.GetSpecialization) or GetSpecialization
        idx = fn and fn() or nil
    end
    classID, idx = Plain(classID), Plain(idx)
    if type(classID) ~= "number" or type(idx) ~= "number" or idx <= 0 then return nil end
    return classID * 10 + idx
end

------------------------------------------------------------
-- 版面字串解碼（純邏輯，WoW 端只用到 C_EncodingUtil 與 Enum.CompressionMethod）
--
-- 回傳 data 表，或 nil, 原因字串。原因只給 debug 看。
------------------------------------------------------------
function C.DecodeLayoutString(str)
    if type(str) ~= "string" or Plain(str) == nil then return nil, "not-string" end
    if str == "" then return nil, "empty" end
    local sep = str:find("|", 1, true)
    if not sep then return nil, "no-version" end
    local ver = tonumber(str:sub(1, sep - 1))
    if ver ~= ENCODING_VERSION then return nil, "encoding-" .. tostring(ver) end
    local payload = str:sub(sep + 1)
    if payload == "" then return nil, "no-payload" end

    local EU = C_EncodingUtil
    if not (EU and EU.DecodeBase64 and EU.DecompressString and EU.DeserializeCBOR) then
        return nil, "no-encodingutil"
    end
    local ok, decoded = pcall(EU.DecodeBase64, payload)
    if not ok or type(decoded) ~= "string" then return nil, "base64" end
    local method = Enum and Enum.CompressionMethod and Enum.CompressionMethod.Deflate
    local inflated
    ok, inflated = pcall(EU.DecompressString, decoded, method)
    if not ok or type(inflated) ~= "string" then return nil, "inflate" end
    local data
    ok, data = pcall(EU.DeserializeCBOR, inflated)
    if not ok or type(data) ~= "table" then return nil, "cbor" end
    local dataVersion = Get(data, 1)
    if not SUPPORTED_DATA_VERSION[dataVersion] then return nil, "data-" .. tostring(dataVersion) end
    return data
end

-- data（已解碼）＋ specTag → 有序 id 陣列（可能是 nil）、分類覆寫 { [id] = category }、原因
function C.ExtractSpecLayout(data, specTag)
    if type(data) ~= "table" or not specTag then return nil, {}, "no-data" end
    local layoutID = Get(Get(data, 2), specTag)
    if layoutID == nil then return nil, {}, "no-active-layout" end
    local layout = Get(Get(Get(data, 3), specTag), layoutID)
    if type(layout) ~= "table" then return nil, {}, "default-layout" end

    local order
    local rawOrder = Get(layout, 1)
    if type(rawOrder) == "table" then
        order = {}
        local seen = {}
        for i = 1, #rawOrder do
            local id = tonumber(rawOrder[i])
            if id and not seen[id] then
                seen[id] = true
                order[#order + 1] = id
            end
        end
    end

    local overrides = {}
    local rawCats = Get(layout, 2)
    if type(rawCats) == "table" then
        for cat, ids in pairs(rawCats) do
            local c = tonumber(cat)
            if c and type(ids) == "table" then
                for _, id in pairs(ids) do
                    id = tonumber(id)
                    if id then overrides[id] = c end
                end
            end
        end
    end
    return order, overrides, "layout"
end

------------------------------------------------------------
-- 狀態
------------------------------------------------------------
C.info       = {}          -- [cooldownID] = info
C.ordered    = {}          -- 完整的有效順序（跨類別）
C.lists      = {}          -- [sourceBar] = { cooldownID… }（還沒套我們的覆寫）
C.pool       = {}          -- [homeBar] = 還在候選池（沒被拖進任何檢視器）的 id
C.sig        = nil         -- 內容簽章（版面字串＋專精＋每條的清單）
C.layoutString = nil       -- 上次讀到的 GetLayoutData 原字串
C.source     = "none"      -- 順序從哪來：layout | fallback:<原因>
C.builds     = 0           -- 實際重建次數（debug／測試用）
local dirty  = true
local paused = false

local function ReadLayoutString()
    local api = C_CooldownViewer and C_CooldownViewer.GetLayoutData
    if not api then return nil end
    local ok, s = pcall(api)
    if not ok then return nil end
    s = Plain(s)
    return type(s) == "string" and s or nil
end
C.ReadLayoutString = ReadLayoutString

local function ReadInfo(id)
    local api = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCooldownInfo
    if not api then return nil end
    local ok, raw = pcall(api, id)
    if not ok or type(raw) ~= "table" then return nil end
    local spellID    = Plain(raw.spellID)
    local overrideID = Plain(raw.overrideSpellID)
    local shown      = overrideID or spellID
    local icon, name
    if shown and C_Spell then
        if C_Spell.GetSpellTexture then
            local ok2, tex = pcall(C_Spell.GetSpellTexture, shown)
            if ok2 then icon = Plain(tex) end
        end
        if C_Spell.GetSpellName then
            local ok3, nm = pcall(C_Spell.GetSpellName, shown)
            if ok3 then name = Plain(nm) end
        end
    end
    local isKnown = Plain(raw.isKnown)
    return {
        cooldownID      = id,
        spellID         = spellID,
        overrideSpellID = overrideID,
        icon            = icon,
        name            = name,
        category        = Plain(raw.category),
        equipSlot       = Plain(raw.equipSlot),
        hasAura         = Plain(raw.hasAura) and true or false,
        charges         = Plain(raw.charges) and true or false,
        isInvisible     = Plain(raw.isInvisible) and true or false,
        isKnown         = isKnown ~= false,       -- 讀不到當作學了（寧可多一格空位也不要少）
        flags           = Plain(raw.flags),
    }
end

------------------------------------------------------------
-- 重建
------------------------------------------------------------
local function Build()
    C.builds = C.builds + 1
    local info, defaultOrder = {}, {}
    local homeOf = {}
    local setAPI = C_CooldownViewer and C_CooldownViewer.GetCooldownViewerCategorySet

    for _, p in ipairs(POOL) do
        local cat = EnumCategory(p.name)
        if cat ~= nil and setAPI then
            local ok, ids = pcall(setAPI, cat, true)
            if ok and type(ids) == "table" then
                for i = 1, #ids do
                    local id = Plain(ids[i])
                    if type(id) == "number" and not info[id] then
                        local rec = ReadInfo(id)
                        if rec then
                            if rec.category == nil then rec.category = cat end
                            rec.home = p.home
                            info[id] = rec
                            homeOf[id] = p.home
                            defaultOrder[#defaultOrder + 1] = id
                        end
                    end
                end
            end
        end
    end

    -- 玩家順序：存檔順序（去掉已不存在的）＋ 新出現的接在後面
    local str = ReadLayoutString()
    C.layoutString = str
    local tag = C.SpecTag()
    C.specTag = tag
    local data, why = C.DecodeLayoutString(str)
    local order, overrides, why2
    if data then
        order, overrides, why2 = C.ExtractSpecLayout(data, tag)
    else
        overrides = {}
    end
    if order then
        C.source = "layout"
    else
        C.source = "fallback:" .. tostring(why2 or why)
    end

    local ordered, seen = {}, {}
    if order then
        for _, id in ipairs(order) do
            if info[id] and not seen[id] then
                seen[id] = true
                ordered[#ordered + 1] = id
            end
        end
    end
    for _, id in ipairs(defaultOrder) do
        if not seen[id] then
            seen[id] = true
            ordered[#ordered + 1] = id
        end
    end

    -- 有效類別 → 分條
    local hideFlag = HideByDefaultFlag()
    local catToBar = {}
    for bar, name in pairs(BAR_CATEGORY_NAME) do
        local v = EnumCategory(name)
        if v ~= nil then catToBar[v] = bar end
    end
    local hideInvisible = _G.CDM_HIDE_INVISIBLE_ITEMS == true

    local lists, pool = {}, {}
    for _, bar in ipairs(C.SOURCE_BARS) do lists[bar] = {}; pool[bar] = {} end
    for _, id in ipairs(ordered) do
        local rec = info[id]
        local eff
        if overrides[id] ~= nil then
            eff = overrides[id]
        elseif HasFlag(rec.flags, hideFlag) then
            eff = HIDDEN
        else
            eff = rec.category
        end
        rec.effectiveCategory = eff
        local bar = catToBar[eff]
        rec.bar = bar
        if bar and rec.isKnown and not (hideInvisible and rec.isInvisible) then
            local l = lists[bar]
            l[#l + 1] = id
        elseif not bar and eff ~= HIDDEN and rec.home and pool[rec.home] then
            local l = pool[rec.home]
            l[#l + 1] = id
        end
    end

    C.info, C.ordered, C.lists, C.pool = info, ordered, lists, pool

    -- 簽章：版面原字串＋專精＋每條清單（天賦改變 isKnown 也會反映在清單上）
    local parts = { str or "", tostring(tag) }
    for _, bar in ipairs(C.SOURCE_BARS) do
        parts[#parts + 1] = table.concat(lists[bar], ",")
    end
    local sig = table.concat(parts, "#")
    local changed = sig ~= C.sig
    C.sig = sig
    dirty = false
    return changed
end

local function EnsureBuilt()
    if dirty then
        local ok, changed = pcall(Build)
        if not ok then
            dirty = false
            if ns.ReportError then ns.ReportError(changed) end
            return false
        end
        return changed
    end
    return false
end

function C.MarkDirty() dirty = true end
function C.IsDirty() return dirty end

-- 重讀；內容變了回 true 並廣播 "CatalogChanged"
function C.Refresh(reason)
    dirty = true
    local changed = EnsureBuilt()
    if changed and ns.Fire then ns.Fire("CatalogChanged", reason) end
    return changed
end

-- 便宜的新鮮度檢查（Bars 每次排版前叫）：暴雪換專精／存版面是在它自己的下一幀做的，
-- 不一定有事件接得到；版面字串或專精跟上次建置時不同就重讀。
function C.CheckFresh()
    if dirty then
        local changed = EnsureBuilt()
        if changed and ns.Fire then ns.Fire("CatalogChanged", "dirty") end
        return changed
    end
    if ReadLayoutString() ~= C.layoutString or C.SpecTag() ~= C.specTag then
        return C.Refresh("stale")
    end
    return false
end

------------------------------------------------------------
-- 對外查詢
------------------------------------------------------------
function C.Info(id)
    EnsureBuilt()
    if id == nil then return nil end
    return C.info[id]
end

-- 這個 id 目前在哪一條暴雪檢視器（有效類別）；不在任何一條回 nil
function C.SourceOf(id)
    EnsureBuilt()
    local rec = id ~= nil and C.info[id]
    return rec and rec.bar or nil
end

local function SpellsTable()
    local p = ns.profile
    local spec = ns.specID
    local sp = p and type(p.spells) == "table" and spec and p.spells[spec]
    return type(sp) == "table" and sp or nil
end

-- 條的有序清單（已套 order／groupOf／hidden）。回傳的是新表，呼叫端可以自由改。
function C.Bar(barKey)
    EnsureBuilt()
    local out = {}
    local p = ns.profile
    local bars = p and p.bars
    local bar = type(bars) == "table" and bars[barKey]
    if type(bar) ~= "table" then return out end

    local sp = SpellsTable()
    local groupOf = sp and type(sp.groupOf) == "table" and sp.groupOf or EMPTY
    local hidden  = sp and type(sp.hidden) == "table" and sp.hidden or EMPTY

    -- 拉進自訂群組：目標群組要真的存在，否則留在原本那條（群組被刪掉不會讓法術憑空消失）
    local function RoutedTo(id)
        local g = groupOf[id]
        if g ~= nil and g ~= barKey and type(bars[g]) == "table" then return g end
        return nil
    end

    local src = bar.source
    if BAR_CATEGORY_NAME[src] then
        for _, id in ipairs(C.lists[src] or EMPTY) do
            if not hidden[id] and RoutedTo(id) == nil then out[#out + 1] = id end
        end
        -- 別的檢視器被指名拉到「這一條」的（例如把核心技能拉回輔助）
        for _, other in ipairs(C.SOURCE_BARS) do
            if other ~= src then
                for _, id in ipairs(C.lists[other] or EMPTY) do
                    if groupOf[id] == barKey and not hidden[id] then out[#out + 1] = id end
                end
            end
        end
    else
        -- 自訂群組：照完整順序收被拉進來的
        for _, id in ipairs(C.ordered) do
            local rec = C.info[id]
            if rec and rec.bar and groupOf[id] == barKey and not hidden[id] then
                local list = C.lists[rec.bar]
                -- 只收真的在某條檢視器清單上的（isKnown 等條件已在那裡過濾）
                for i = 1, #list do
                    if list[i] == id then out[#out + 1] = id; break end
                end
            end
        end
    end

    -- 我們自己的順序覆寫：列到的照列的順序排在前面，沒列到的照原順序接在後面
    local ord = sp and type(sp.order) == "table" and sp.order[barKey]
    if type(ord) == "table" and #ord > 0 then
        local present = {}
        for _, id in ipairs(out) do present[id] = true end
        local sorted, used = {}, {}
        for _, id in ipairs(ord) do
            if present[id] and not used[id] then
                used[id] = true
                sorted[#sorted + 1] = id
            end
        end
        for _, id in ipairs(out) do
            if not used[id] then sorted[#sorted + 1] = id end
        end
        out = sorted
    end
    return out
end

-- 還在候選池（沒被拖進任何檢視器）的 id，給設定介面的「要先去暴雪面板加」用
function C.Pool(homeBar)
    EnsureBuilt()
    local out = {}
    for _, id in ipairs(C.pool[homeBar] or EMPTY) do out[#out + 1] = id end
    return out
end

------------------------------------------------------------
-- 暴雪設定面板開關：開著時暫停重排，關掉時版面字串變了才重讀
------------------------------------------------------------
function C.IsPaused() return paused end

function C.OnSettingsShow()
    paused = true
end

function C.OnSettingsHide()
    paused = false
    local str = ReadLayoutString()
    if str ~= C.layoutString then
        C.Refresh("settings")
    end
    if ns.Fire then ns.Fire("CatalogResumed") end
end

------------------------------------------------------------
-- 初始化（登入流程叫一次）
------------------------------------------------------------
local initialized = false
function C.Init()
    if initialized then return end
    initialized = true

    -- 事件處理器只做「標髒＋下一幀重讀」：事件可能在暴雪的 secure 流程裡同步派送，
    -- 在那裡跑我們的 Lua 會染到它（見 wow-121-addon-code-in-secure-stack）
    local pendingReason
    local function Later(reason)
        dirty = true
        if pendingReason then return end
        pendingReason = reason
        ns.Defer(function()
            local r = pendingReason
            pendingReason = nil
            C.Refresh(r)
        end)
    end

    local E = ns.Events
    E.Register("COOLDOWN_VIEWER_DATA_LOADED", "catalog", function() Later("data") end)
    E.Register("COOLDOWN_VIEWER_TABLE_HOTFIXED", "catalog", function() Later("hotfix") end)
    E.Register("COOLDOWN_VIEWER_SPELL_OVERRIDE_UPDATED", "catalog", function() Later("override") end)
    E.Register("PLAYER_SPECIALIZATION_CHANGED", "catalog", function() Later("spec") end, "player")
    -- 學會／忘掉技能、換裝備：暴雪那邊也會重建清單（isKnown 會變）
    E.Register("SPELLS_CHANGED", "catalog", function() Later("spells") end)
    E.Register("PLAYER_EQUIPMENT_CHANGED", "catalog", function() Later("equipment") end)
    E.Register("TRAIT_CONFIG_UPDATED", "catalog", function() Later("talents") end)

    if EventRegistry and EventRegistry.RegisterCallback then
        local owner = {}
        pcall(EventRegistry.RegisterCallback, EventRegistry, "CooldownViewerSettings.OnShow",
            function() ns.Defer(C.OnSettingsShow) end, owner)
        pcall(EventRegistry.RegisterCallback, EventRegistry, "CooldownViewerSettings.OnHide",
            function() ns.Defer(C.OnSettingsHide) end, owner)
    end

    -- 登入當下面板就開著（極少見）也要對得上
    local settings = _G.CooldownViewerSettings
    if settings and settings.IsShown then
        local ok, shown = pcall(settings.IsShown, settings)
        if ok and Plain(shown) then paused = true end
    end

    C.Refresh("init")
end
