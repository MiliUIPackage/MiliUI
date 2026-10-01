------------------------------------------------------------
-- 可點擊的自訂圖示群組：每一格上面蓋一顆透明的 secure 鈕
--
--   ns.Clickable.Enabled(key)               這條要不要蓋鈕（DB.BarClickable 的唯一出口）
--   ns.Clickable.Describe(e)                Bars 的一格 entry → 明文描述表（讀 Catalog／Viewers）
--   ns.Clickable.Resolve(desc)              純函式：描述表 → { type, spell|item|slot } 或 nil
--   ns.Clickable.Place(key, c, i, r, e)     Flush 的放格迴圈每格叫一次
--   ns.Clickable.EndBar(key, used)          這一輪用不到的鈕收起來
--   ns.Clickable.Release(key)               關掉可點擊／刪群組：全部收起來、脫離錨點
--   ns.Clickable.ReleaseAll()               還給暴雪（Bars.ReleaseAll）時全部收
--
-- 為什麼是「蓋一顆鈕」：
--   * 戰鬥中施放只能靠 SecureActionButtonTemplate —— 屬性在戰鬥外寫好、戰鬥中由引擎處理點擊，
--     我們的 Lua 一行施法 API 都不碰。
--   * 暴雪的 item 不能變成按鈕（不能 SetParent、不能寫欄位、不能加模板）；自製的圖示框每次重排都
--     SetPoint／SetSize／Show，換成 secure 模板戰鬥中就動不了。所以鈕是**另外一顆**，parent 與
--     錨點都是條的容器，座標跟那一格的 rect 一樣。
--   * 鈕錨在容器上 ⇒ 容器（與它錨定鏈上游的容器）變成隱式保護框。Bars 對容器的寫入本來就走
--     ns.Write（光環格的持有框早就造成同樣的狀況），這裡對鈕的每一筆結構寫入也一律走 ns.Write，
--     而且用簽章去重：沒變就不寫 ⇒ 戰鬥中重排沒有保護呼叫。
--   * 可點擊的條**強制固定格位**（Bars 的 fixed）：格子在戰鬥中不能動，鈕才跟得上。
--
-- 規矩：
--   * 鈕只掛 OnEnter／OnLeave（轉給 Decorate 的滑鼠提示）。**不准** PreClick／PostClick／OnMouseDown／
--     OnClick —— 同一次點擊派送裡排在 secure 動作前面的插件 Lua 會把那次施放一起染髒。
--   * 寫進屬性的 id 一律先過 ns.IsSecret（秘密值 ⇒ 當沒有動作，那一格的鈕收起來）。
--   * 鈕只在戰鬥外建；戰鬥中缺鈕 ⇒ 記 pending，PLAYER_REGEN_ENABLED 一次性要求那條重排補建。
--   * 鈕身上不寫任何 Lua 欄位（模板的 OnClick 是暴雪的碼）：狀態（簽章、rec）放在本檔的弱鍵表。
--   * 編輯模式中全部收起來（不然 strata 高的群組，鈕會蓋在選取框上面、拖曳變施放）。
--
-- 動作：
--   自訂法術   type=spell、spell=基底 id（對基底 id 施放，引擎自己換成覆寫後的法術；覆寫戰鬥中會變、屬性卻鎖著）
--   自訂物品   type=item、item="item:<id>"（照身分不照包包格，套組慣例）
--   飾品欄     type=item、slot=13／14（現在裝在那一格的那件）
--   暴雪 item  有 equipSlot ⇒ type=item、slot；否則 spellID ⇒ type=spell（基底 id）
--   光環格、增益類來源、物品冷卻類別（藥水那種一格代表一整類）、占位格、讀不到 ⇒ nil（不蓋鈕）
------------------------------------------------------------
local _, ns = ...

ns.Clickable = {}
local CK = ns.Clickable

local LEVEL_ABOVE = 40          -- 自製圖示框 +2、overlay +12、發光 +14；暴雪 item 的 overlay 是 item 層級 +10
local MAX_SLOT = 19             -- 裝備欄位 1–19

local pools = {}                -- key → { list = { [i] = 鈕 }, released = bool }
local state = setmetatable({}, { __mode = "k" })   -- 鈕 → { rec, placeSig, actionSig, shown }
local pending = {}              -- key → true：戰鬥中缺鈕，脫戰要重排
CK.created = 0

local function IsSecret(v)
    return ns.IsSecret ~= nil and ns.IsSecret(v) and true or false
end

-- 明文正整數；秘密值先擋（秘密值連跟 nil 比都會拋錯，所以 IsSecret 一定排第一）
local function Id(v)
    if IsSecret(v) then return nil end
    if type(v) ~= "number" or v <= 0 or v ~= math.floor(v) then return nil end
    return v
end

------------------------------------------------------------
-- 判準
------------------------------------------------------------
function CK.Enabled(key)
    local DB = ns.DB
    return (DB and DB.BarClickable and DB.BarClickable(key)) and true or false
end

------------------------------------------------------------
-- Resolve：純函式，不碰任何 WoW 全域（離線測試直接餵描述表）
--
--   { kind = "spell", spellID }                    → { type = "spell", spell = id }
--   { kind = "item",  itemID }                     → { type = "item",  item = "item:<id>" }
--   { kind = "slot",  slot }                       → { type = "item",  slot = n }
--   { kind = "aura" }                              → nil
--   { kind = "blizzard", aura, category, equipSlot, spellID }
--        aura／category 為真 ⇒ nil；equipSlot 優先（飾品的使用效果不在法術書裡，對它施放法術放不出來）
------------------------------------------------------------
function CK.Resolve(desc)
    if type(desc) ~= "table" then return nil end
    local kind = desc.kind
    if IsSecret(kind) or type(kind) ~= "string" then return nil end
    if kind == "spell" then
        local id = Id(desc.spellID)
        return id and { type = "spell", spell = id } or nil
    elseif kind == "item" then
        local id = Id(desc.itemID)
        return id and { type = "item", item = "item:" .. id } or nil
    elseif kind == "slot" then
        local s = Id(desc.slot)
        return (s and s <= MAX_SLOT) and { type = "item", slot = s } or nil
    elseif kind == "blizzard" then
        -- 判不出來就不蓋：秘密的裝備欄位也不能退去用法術（那是裝備，對它施放法術放不出來）
        if IsSecret(desc.aura) or IsSecret(desc.category) or IsSecret(desc.equipSlot) then return nil end
        if desc.aura or desc.category then return nil end
        local s = Id(desc.equipSlot)
        if s and s <= MAX_SLOT then return { type = "item", slot = s } end
        local id = Id(desc.spellID)
        return id and { type = "spell", spell = id } or nil
    end
    return nil
end

------------------------------------------------------------
-- Describe：Bars 的一格 entry → 描述表（自訂：e.crec；暴雪：e.item＋e.rec；占位：e.placeholder）
------------------------------------------------------------
function CK.Describe(e)
    if type(e) ~= "table" or e.placeholder then return nil end
    local crec = e.crec
    if crec then
        return { kind = crec.kind, spellID = crec.spellID, itemID = crec.itemID, slot = crec.slot }
    end
    if not e.item then return nil end
    local C = ns.Catalog
    local info = C and C.Info(e.id)
    if type(info) ~= "table" then return nil end
    local auraKind = ns.Viewers and ns.Viewers.AURA_KIND or {}
    local src = C.SourceOf and C.SourceOf(e.id)
    local home = e.rec and e.rec.barKey
    return {
        kind      = "blizzard",
        aura      = ((src and auraKind[src]) or (home and auraKind[home])) and true or false,
        category  = info.spellCategoryID ~= nil,
        equipSlot = info.equipSlot,
        spellID   = info.spellID,
    }
end

-- 這一格的提示要找哪個 rec（Decorate 的 overlay 掛在它身上）
local function RecOf(e)
    if e.crec then return e.crec end
    return e.rec
end

------------------------------------------------------------
-- 鈕
------------------------------------------------------------
local function OnEnter(self)
    local s = state[self]
    local D = ns.Decorate
    if s and s.rec and D and D.HoverEnter then D.HoverEnter(s.rec) end
end

local function OnLeave(self)
    local s = state[self]
    local D = ns.Decorate
    if s and s.rec and D and D.HoverLeave then D.HoverLeave(s.rec) end
end

local function ArmRegen()
    ns.Events.Register("PLAYER_REGEN_ENABLED", "clickable", function()
        ns.Events.Unregister("PLAYER_REGEN_ENABLED", "clickable")
        local keys = pending
        pending = {}
        for key in pairs(keys) do
            if ns.Bars and ns.Bars.Request then ns.Bars.Request(key, "layout") end
        end
    end)
end

local function Pool(key)
    local pool = pools[key]
    if not pool then
        pool = { list = {}, released = true }
        pools[key] = pool
    end
    return pool
end

-- 只在戰鬥外建；戰鬥中回 nil 並記 pending
local function Create(key, c, i)
    if InCombatLockdown() then
        pending[key] = true
        ArmRegen()
        return nil
    end
    local b = CreateFrame("Button", "MiliUICDM_Click_" .. key .. "_" .. i, c, "SecureActionButtonTemplate")
    -- 兩邊都註冊：引擎照 ActionButtonUseKeyDown 決定哪一邊施放，只響一次（套組慣例）
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:EnableMouse(true)
    b:SetMouseMotionEnabled(true)              -- 它在最上層時，hover 由它轉給 Decorate 的提示
    b:SetScript("OnEnter", OnEnter)
    b:SetScript("OnLeave", OnLeave)
    b:Hide()
    state[b] = { shown = false }
    CK.created = CK.created + 1
    return b
end

local function SetShown(b, s, show)
    if s.shown == show then return end
    s.shown = show
    ns.Write(b, function(f)
        if show then f:Show() else f:Hide() end
    end, "shown")
end

-- 編輯模式中鈕一律收起來：群組 strata 比 MEDIUM 高（或暴雪的選取框模板建不出來、用自製的那顆）時，
-- 鈕會蓋在選取框上面，拖曳變成施放。進出編輯模式要求可點擊的條重排（戰鬥中進出 ⇒ 寫入照 ns.Write 記帳到脫戰）
local function Editing()
    return ns.EditMode ~= nil and ns.EditMode.active == true
end

function CK.Place(key, c, i, r, e)
    if not (key and c and i and r) then return end
    local pool = Pool(key)
    local b = pool.list[i]
    local action = (not Editing()) and CK.Resolve(CK.Describe(e)) or nil
    if not action then
        -- 沒有動作的格不留鈕（留著沒屬性的鈕會搶走 hover，光環格的暴雪提示就出不來）
        if b then
            local s = state[b]
            s.rec = nil
            SetShown(b, s, false)
        end
        return
    end
    if not b then
        b = Create(key, c, i)
        if not b then return end
        pool.list[i] = b
    end
    pool.released = false
    local s = state[b]
    s.rec = RecOf(e)

    local x, y, w, h = r.x, r.y, r.w, r.h
    local level = ((c.GetFrameLevel and c:GetFrameLevel()) or 1) + LEVEL_ABOVE
    local placeSig = table.concat({ tostring(c), tostring(x), tostring(y), tostring(w), tostring(h), tostring(level) }, "|")
    if s.placeSig ~= placeSig then
        s.placeSig = placeSig
        ns.Write(b, function(f)
            if f:GetParent() ~= c then f:SetParent(c) end
            f:SetFrameLevel(level)
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
            f:SetSize(w, h)
        end, "place")
    end

    local t, sp, it, sl = action.type, action.spell, action.item, action.slot
    local actionSig = table.concat({ tostring(t), tostring(sp), tostring(it), tostring(sl) }, "|")
    if s.actionSig ~= actionSig then
        s.actionSig = actionSig
        -- 四個每次都全寫（沒有的寫 nil 清掉）：換種類時不會留著上一種的屬性
        ns.Write(b, function(f)
            f:SetAttribute("type", t)
            f:SetAttribute("spell", sp)
            f:SetAttribute("item", it)
            f:SetAttribute("slot", sl)
        end, "action")
    end

    SetShown(b, s, true)
end

function CK.EndBar(key, used)
    local pool = pools[key]
    if not pool then return end
    used = tonumber(used) or 0
    for i, b in pairs(pool.list) do
        if i > used then
            local s = state[b]
            s.rec = nil
            SetShown(b, s, false)
        end
    end
end

-- 全部收起來並脫離錨點（簽章清空：下次再開要全寫）。已經收過的不再排寫入
function CK.Release(key)
    local pool = pools[key]
    if not pool or pool.released then return end
    pool.released = true
    pending[key] = nil
    for _, b in pairs(pool.list) do
        local s = state[b]
        s.rec, s.placeSig, s.actionSig, s.shown = nil, nil, nil, false
        ns.Write(b, function(f)
            f:Hide()
            f:ClearAllPoints()
        end, "shown")
    end
end

function CK.ReleaseAll()
    for key in pairs(pools) do CK.Release(key) end
end

-- 進出編輯模式：有鈕的條重排一次（Place 照 Editing() 收／放）
local function OnEditModeChanged()
    if not (ns.Bars and ns.Bars.Request) then return end
    for key, pool in pairs(pools) do
        if not pool.released then ns.Bars.Request(key, "layout") end
    end
end
CK.OnEditModeChanged = OnEditModeChanged
if ns.RegisterCallback then ns.RegisterCallback("EditModeChanged", "clickable", OnEditModeChanged) end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
function CK.Counts()
    local n = { buttons = 0, shown = 0, bars = 0, pending = 0 }
    for _, pool in pairs(pools) do
        n.bars = n.bars + 1
        for _, b in pairs(pool.list) do
            n.buttons = n.buttons + 1
            if state[b] and state[b].shown then n.shown = n.shown + 1 end
        end
    end
    for _ in pairs(pending) do n.pending = n.pending + 1 end
    return n
end

-- 測試用：某條第 i 顆鈕與它的狀態
function CK.Button(key, i)
    local pool = pools[key]
    local b = pool and pool.list[i]
    return b, b and state[b]
end
