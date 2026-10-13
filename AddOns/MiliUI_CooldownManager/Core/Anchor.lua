------------------------------------------------------------
-- 錨到外部的框：單位框與具名框（H4）
--
-- anchor.to 除了條／面板的 key，多兩種值（⚠ **存檔內容，之後不能改名**）：
--   "unit:player"｜"unit:target"｜"unit:focus"｜"unit:pet"｜"unit:targettarget"｜"unit:focustarget"
--                                              現在載入的那支單位框（提供者表依序找第一個存在的）
--   "frame:<全域框名>"                          任意具名框（"frame:" 後面空白＝還沒填名字，當作解析不到）
-- anchor.fallback = { point, x, y }：第一次選外部目標時記下的「自己在畫面上的位置」（同 pos 的語意）。
-- **解析不到時照 fallback（沒有就照 pos）貼 UIParent**——不是沒有錨點、不會消失。
--
--   A.IsExternal(to)          是不是外部目標的字串（"unit:" 或 "frame:" 開頭）
--   A.Parse(to)               → "unit", "player"｜"frame", "名字"｜nil
--   A.Candidates(to)          → 依序要試的全域名清單（unit 照提供者表；frame 就是那一個名字）
--   A.Resolve(to)             → frame 或 nil, 解析到的名字（有快取）
--   A.CheckName(name)         → ok, why（"empty"｜"own"｜"missing"｜"notframe"），設定頁的輸入框即時驗證用
--   A.Invalidate()            快取作廢（ADDON_LOADED／PLAYER_ENTERING_WORLD：單位框插件可能比我們晚載入）
--   A.Fallback(bar)           → point, x, y：解析不到時要貼的位置（fallback ＞ pos ＞ CENTER 0,0）
--   A.Unresolved(bar)         這條的 anchor.to 是外部目標、而且現在解析不到
--   A.Label(to)               顯示用的名字（玩家框架／目標框架／專注目標框架／寵物框架／目標的目標框架／
--                             專注目標的目標框架／框名）
--   A.Provider(to)            解析到的框屬於哪一家（MiliUI／EllesmereUI／ElvUI／MSUF／Blizzard）（A.PROVIDERS 那一行的 name），查不到回 nil；
--                             錨定視窗的灰字「目前接到：家名（框名）」用。家名是提供者表的資料，不從框名前綴猜
--
-- 「框存在」只看 _G[name] 是不是一個可以當錨點的物件（GetObjectType 讀得到、有 GetPoint 這類區域方法、
-- 不是 forbidden）。**不讀它的位置、大小、可見度**：單位框沒有目標時被 RegisterUnitWatch 藏起來，
-- 藏著的框照樣有矩形、照樣錨得上去，不算解析不到（條不會因為換目標而跳位置）。
--
-- 我們自己的條容器（MiliUICDM_Bar_*）不收：要跟著自己的條請選條本身（才會參與排開、才擋得了環）。
-- 外部框不會反過來錨在我們身上（就算會，SetPoint 撞上「錨在依賴自己的框上」時 Bars 會退回 fallback）。
--
-- 保護傳遞（寫進 README）：保護是從保護框往「它的父層」與「它錨著的框」傳，不是往「錨著它的框」傳
-- （warcraft.wiki.gg「Secure Execution and Tainting」：Control restrictions on protected frames are also
-- applied to their parents and any frames they are anchored to）。我們的容器錨**到** secure 單位按鈕上，
-- 容器本身不會因此變成保護框；容器的寫入照舊全走 ns.Write（真的被保護時會記帳到脫戰）。
------------------------------------------------------------
local _, ns = ...

ns.Anchor = ns.Anchor or {}
local A = ns.Anchor

-- 單位框提供者：一行一家，依序試（本套組 → 其他單位框插件（EllesmereUI、ElvUI、MSUF）→ 暴雪），第一個存在的贏。
-- 名字是各家單位框的全域框名（資料，不是程式）；**unit 的 key（player…）是存檔內容，不能改名**
A.PROVIDERS = {
    { name = "MiliUI", frames = {
        player = "MiliUIUF_Player", target = "MiliUIUF_Target", focus = "MiliUIUF_Focus",
        pet = "MiliUIUF_Pet", targettarget = "MiliUIUF_TargetTarget", focustarget = "MiliUIUF_FocusTarget" } },
    { name = "EllesmereUI", frames = {
        player = "EllesmereUIUnitFrames_Player", target = "EllesmereUIUnitFrames_Target",
        focus = "EllesmereUIUnitFrames_Focus", pet = "EllesmereUIUnitFrames_Pet",
        targettarget = "EllesmereUIUnitFrames_TargetTarget", focustarget = "EllesmereUIUnitFrames_FocusTarget" } },
    { name = "ElvUI", frames = {
        player = "ElvUF_Player", target = "ElvUF_Target", focus = "ElvUF_Focus",
        pet = "ElvUF_Pet", targettarget = "ElvUF_TargetTarget", focustarget = "ElvUF_FocusTarget" } },
    -- 框名＝它 TOC 的 X-MSUF-UnitFrames-Prefix（MSUF）＋ "_" ＋ 小寫 unit
    { name = "MSUF", frames = {
        player = "MSUF_player", target = "MSUF_target", focus = "MSUF_focus",
        pet = "MSUF_pet", targettarget = "MSUF_targettarget", focustarget = "MSUF_focustarget" } },
    { name = "Blizzard", frames = {
        player = "PlayerFrame", target = "TargetFrame", focus = "FocusFrame",
        pet = "PetFrame", targettarget = "TargetFrameToT", focustarget = "FocusFrameToT" } },
}
-- 設定頁下拉的順序
A.UNITS = { "player", "target", "focus", "pet", "targettarget", "focustarget" }

-- 從提供者表展開：unit → 依序要試的框名；框名 → 家名
A.UNIT_PROVIDERS = {}
A.FRAME_PROVIDER = {}
for _, u in ipairs(A.UNITS) do
    local list = {}
    for _, prov in ipairs(A.PROVIDERS) do
        local name = prov.frames[u]
        if name then
            list[#list + 1] = name
            A.FRAME_PROVIDER[name] = prov.name
        end
    end
    A.UNIT_PROVIDERS[u] = list
end

A.OWN_PREFIX = "MiliUICDM_Bar_"

-- 全域表：遊戲裡是 _G；離線測試換成假表
A.G = _G

local cache = {}          -- to → frame｜false
A.gen = 0                 -- 每次作廢 +1（設定頁拿來判斷要不要重畫）

function A.IsExternal(to)
    if type(to) ~= "string" then return false end
    return to:sub(1, 5) == "unit:" or to:sub(1, 6) == "frame:"
end

function A.Parse(to)
    if type(to) ~= "string" then return nil end
    if to:sub(1, 5) == "unit:" then
        local u = to:sub(6)
        if A.UNIT_PROVIDERS[u] then return "unit", u end
        return nil
    end
    if to:sub(1, 6) == "frame:" then
        return "frame", (to:sub(7):gsub("^%s+", ""):gsub("%s+$", ""))
    end
    return nil
end

function A.Candidates(to)
    local kind, arg = A.Parse(to)
    if kind == "unit" then return A.UNIT_PROVIDERS[arg] end
    if kind == "frame" and arg ~= "" then return { arg } end
    return {}
end

local function IsSecret(v)
    return ns.IsSecret and ns.IsSecret(v) or false
end

-- 可以當錨點的物件：GetObjectType 讀得到字串、有區域的錨點方法（字型物件 GameFontNormal 之類也在 _G 裡、
-- 也有 GetObjectType，但錨不上去）、不是 forbidden
local function Anchorable(obj)
    if type(obj) ~= "table" then return false end
    if type(obj.GetObjectType) ~= "function" or type(obj.GetPoint) ~= "function" then return false end
    local ok, t = pcall(obj.GetObjectType, obj)
    if not ok or IsSecret(t) or type(t) ~= "string" then return false end
    if type(obj.IsForbidden) == "function" then
        local fok, forbidden = pcall(obj.IsForbidden, obj)
        if not fok or IsSecret(forbidden) or forbidden then return false end
    end
    return true
end
A.Anchorable = Anchorable

local function Own(name)
    return type(name) == "string" and name:sub(1, #A.OWN_PREFIX) == A.OWN_PREFIX
end

function A.CheckName(name)
    if type(name) ~= "string" then return false, "empty" end
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if name == "" then return false, "empty" end
    if Own(name) then return false, "own" end
    local G = A.G or {}
    local obj = rawget(G, name)
    if obj == nil then return false, "missing" end
    if not Anchorable(obj) then return false, "notframe" end
    return true
end

function A.Resolve(to)
    local hit = cache[to]
    if hit ~= nil then
        if hit then return hit[1], hit[2] end
        return nil
    end
    local G = A.G or {}
    local found, foundName
    for _, name in ipairs(A.Candidates(to)) do
        if not Own(name) then
            local obj = rawget(G, name)
            if obj ~= nil and Anchorable(obj) then
                found, foundName = obj, name
                break
            end
        end
    end
    cache[to] = found and { found, foundName } or false
    return found, foundName
end

function A.Invalidate()
    for k in pairs(cache) do cache[k] = nil end
    A.gen = A.gen + 1
end

-- 顯示用的名字（設定頁下拉、編輯模式提示）
function A.Label(to)
    local L = ns.L
    local kind, arg = A.Parse(to)
    if kind == "unit" then
        if arg == "player" then return L["Player frame"] end
        if arg == "target" then return L["Target frame"] end
        if arg == "pet" then return L["Pet frame"] end
        if arg == "targettarget" then return L["Target of target frame"] end
        if arg == "focustarget" then return L["Focus target frame"] end
        return L["Focus frame"]
    end
    if kind == "frame" then
        if arg ~= "" then return arg end
        return L["Frame by name"]
    end
    return tostring(to)
end

-- 解析到的框是哪一家的（單位框才有；具名框剛好填了某家的框名也照表回）。解析不到回 nil
function A.Provider(to)
    local _, name = A.Resolve(to)
    if not name then return nil end
    return A.FRAME_PROVIDER[name]
end

-- 解析不到時的位置：anchor.fallback ＞ pos ＞ 畫面中央
function A.Fallback(bar)
    local a = type(bar) == "table" and bar.anchor
    local fb = type(a) == "table" and type(a.fallback) == "table" and a.fallback
    local p = fb or (type(bar) == "table" and type(bar.pos) == "table" and bar.pos) or {}
    return p.point or "CENTER", tonumber(p.x) or 0, tonumber(p.y) or 0
end

-- 這條（或面板）的 anchor.to 是外部目標、而且現在解析不到
function A.Unresolved(bar)
    local a = type(bar) == "table" and bar.anchor
    if type(a) ~= "table" or not A.IsExternal(a.to) then return false end
    return A.Resolve(a.to) == nil
end

------------------------------------------------------------
-- 作廢與重貼：單位框插件晚載入、讀取畫面之後重新找一次。結果有變（多了／少了／換了一支）才請 Bars 重套結構
------------------------------------------------------------
local last = {}           -- to → 上一次解析到的框（false ＝ 解析不到）

local function UsedTargets()
    local out = {}
    local p = ns.profile
    if type(p) ~= "table" then return out end
    local function Add(t)
        local a = type(t) == "table" and t.anchor
        if type(a) == "table" and A.IsExternal(a.to) then out[a.to] = true end
    end
    for _, bar in pairs(type(p.bars) == "table" and p.bars or {}) do Add(bar) end
    for _, k in ipairs(ns.DB and ns.DB.PANEL_ORDER or {}) do Add(p[k]) end
    -- 獨立擺放的資源列（"res:<key>"）也可以錨外部框
    if ns.DB and ns.DB.DetachedKeys then
        for _, k in ipairs(ns.DB.DetachedKeys(p)) do Add(ns.DB.ConfigTable(k)) end
    end
    return out
end

-- 回傳 true ＝ 有外部目標的解析結果變了
function A.Recheck()
    A.Invalidate()
    local changed = false
    for to in pairs(UsedTargets()) do
        local f = A.Resolve(to) or false
        if last[to] ~= f then
            last[to] = f
            changed = true
        end
    end
    return changed
end

local pending = false
local function Soon()
    if pending then return end
    pending = true
    ns.Defer(function()
        pending = false
        if A.Recheck() and ns.Bars and ns.Bars.RequestAll then ns.Bars.RequestAll("structure") end
        if ns.Fire then ns.Fire("AnchorTargetsChanged") end
    end)
end
A.Soon = Soon

if ns.Events and ns.Events.Register then
    ns.Events.Register("ADDON_LOADED", "anchor_ext", Soon)
    ns.Events.Register("PLAYER_ENTERING_WORLD", "anchor_ext", Soon)
end
