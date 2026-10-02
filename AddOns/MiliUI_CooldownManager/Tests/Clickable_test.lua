------------------------------------------------------------
-- Core/Clickable.lua 的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Clickable_test.lua
--
-- 做法：載進自己的環境表。Resolve 另外載一份到**完全沒有 stub** 的環境裡跑，確認它是純函式
-- （偷用任何 WoW 全域都會當場 nil 報錯）。其餘部分 stub CreateFrame／InCombatLockdown 與 ns 的
-- Write／Events／Bars／Decorate／DB／Catalog／Viewers，Write 記下每一筆（框、key）。
--
-- 覆蓋：Resolve 每一列（含秘密值 sentinel）、Describe、Place 的三種簽章去重（同 rect 同動作不寫、
-- 只換動作只寫 action、只換 rect 只寫 place、沒有動作寫 Hide）、EndBar 收多的、Release 清簽章、
-- 戰鬥中不建鈕（pending → 脫戰 Request）、鈕只掛 OnEnter／OnLeave、hover 轉給 Decorate。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local PATH = here .. "/../Core/Clickable.lua"

local passed, failed = 0, 0
local function check(name, cond, detail)
    if cond then
        passed = passed + 1
    else
        failed = failed + 1
        print("FAIL  " .. name .. (detail and ("  (" .. tostring(detail) .. ")") or ""))
    end
end
local function eq(name, got, want)
    check(name, got == want, "got " .. tostring(got) .. ", want " .. tostring(want))
end

local function Load(env, ns)
    local chunk, err
    if setfenv then
        chunk, err = loadfile(PATH)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(PATH, "t", env)
    end
    assert(chunk, err)
    chunk("MiliUI_CooldownManager", ns)
end

-- 秘密值 sentinel：ns.IsSecret 只對它回 true。它是一張表，任何比較／算術都會照常（測試裡不會炸），
-- 所以「沒先擋就拿去用」會表現成錯的回傳值而不是例外
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local function IsSecret(v) return rawequal(v, SECRET) end

------------------------------------------------------------
-- 1. Resolve：純函式（沒有任何 stub 的環境）
------------------------------------------------------------
do
    local bare = setmetatable({}, { __index = _G })
    local ns0 = { IsSecret = IsSecret }
    Load(bare, ns0)
    local R = ns0.Clickable.Resolve

    local a = R({ kind = "spell", spellID = 12345 })
    eq("自訂法術 type", a and a.type, "spell")
    eq("自訂法術 spell＝基底 id", a and a.spell, 12345)
    eq("自訂法術 沒有 item", a and a.item, nil)

    a = R({ kind = "item", itemID = 211880 })
    eq("自訂物品 type", a and a.type, "item")
    eq("自訂物品 item＝item:<id>", a and a.item, "item:211880")
    eq("自訂物品 沒有 slot", a and a.slot, nil)

    a = R({ kind = "slot", slot = 13 })
    eq("飾品欄 type", a and a.type, "item")
    eq("飾品欄 slot", a and a.slot, 13)
    a = R({ kind = "slot", slot = 14 })
    eq("飾品欄 2", a and a.slot, 14)

    eq("光環格 → nil", R({ kind = "aura", spellID = 774 }), nil)

    a = R({ kind = "blizzard", spellID = 31884 })
    eq("暴雪法術 type", a and a.type, "spell")
    eq("暴雪法術 spell", a and a.spell, 31884)
    a = R({ kind = "blizzard", equipSlot = 13 })
    eq("暴雪裝備欄 type", a and a.type, "item")
    eq("暴雪裝備欄 slot", a and a.slot, 13)
    a = R({ kind = "blizzard", equipSlot = 14, spellID = 999 })
    eq("暴雪裝備欄＋法術：裝備欄優先", a and a.slot, 14)
    eq("暴雪裝備欄＋法術：不寫 spell", a and a.spell, nil)
    eq("暴雪增益類來源 → nil", R({ kind = "blizzard", aura = true, spellID = 31884 }), nil)
    eq("暴雪物品冷卻類別 → nil", R({ kind = "blizzard", category = true, spellID = 2 }), nil)
    eq("暴雪什麼都沒有 → nil", R({ kind = "blizzard" }), nil)

    -- 秘密值
    eq("秘密 spellID → nil", R({ kind = "spell", spellID = SECRET }), nil)
    eq("秘密 itemID → nil", R({ kind = "item", itemID = SECRET }), nil)
    eq("秘密 slot → nil", R({ kind = "slot", slot = SECRET }), nil)
    eq("秘密 kind → nil", R({ kind = SECRET, spellID = 1 }), nil)
    eq("暴雪秘密 spellID → nil", R({ kind = "blizzard", spellID = SECRET }), nil)
    eq("暴雪秘密 equipSlot 不退去用法術", R({ kind = "blizzard", equipSlot = SECRET, spellID = 5 }), nil)
    eq("暴雪秘密 aura → nil", R({ kind = "blizzard", aura = SECRET, spellID = 5 }), nil)

    -- 壞資料
    eq("nil → nil", R(nil), nil)
    eq("不是表 → nil", R("spell"), nil)
    eq("不認得的 kind → nil", R({ kind = "macro", spellID = 1 }), nil)
    eq("spellID 0 → nil", R({ kind = "spell", spellID = 0 }), nil)
    eq("spellID 負數 → nil", R({ kind = "spell", spellID = -3 }), nil)
    eq("spellID 小數 → nil", R({ kind = "spell", spellID = 1.5 }), nil)
    eq("spellID 字串 → nil", R({ kind = "spell", spellID = "123" }), nil)
    eq("slot 20 → nil", R({ kind = "slot", slot = 20 }), nil)
    eq("暴雪 equipSlot 超出 → 退去用法術", (R({ kind = "blizzard", equipSlot = 99, spellID = 7 }) or {}).spell, 7)
end

------------------------------------------------------------
-- 2. 其餘：stub 環境
------------------------------------------------------------
local combat = false
local created = {}

local function NewFrame(kind, name, parent, template)
    local f = {
        kind = kind, name = name, parent = parent, template = template,
        scripts = {}, attrs = {}, points = {}, shown = true, level = 1,
        calls = { SetPoint = 0, ClearAllPoints = 0, SetSize = 0, SetAttribute = 0, Show = 0, Hide = 0, SetParent = 0 },
    }
    function f:RegisterForClicks(...) self.clicks = { ... } end
    function f:EnableMouse(on) self.mouse = on end
    function f:SetMouseMotionEnabled(on) self.motion = on end
    function f:SetScript(k, fn) self.scripts[k] = fn end
    function f:Show() self.calls.Show = self.calls.Show + 1; self.shown = true end
    function f:Hide() self.calls.Hide = self.calls.Hide + 1; self.shown = false end
    function f:IsShown() return self.shown end
    function f:GetParent() return self.parent end
    function f:SetParent(p) self.calls.SetParent = self.calls.SetParent + 1; self.parent = p end
    function f:SetFrameLevel(l) self.level = l end
    function f:GetFrameLevel() return self.level end
    function f:ClearAllPoints() self.calls.ClearAllPoints = self.calls.ClearAllPoints + 1; self.points = {} end
    function f:SetPoint(...) self.calls.SetPoint = self.calls.SetPoint + 1; self.points[#self.points + 1] = { ... } end
    function f:SetSize(w, h) self.calls.SetSize = self.calls.SetSize + 1; self.w, self.h = w, h end
    function f:SetAttribute(k, v) self.calls.SetAttribute = self.calls.SetAttribute + 1; self.attrs[k] = v end
    function f:GetAttribute(k) return self.attrs[k] end
    created[#created + 1] = f
    return f
end

local env = setmetatable({}, { __index = _G })
env.InCombatLockdown = function() return combat end
env.CreateFrame = NewFrame

local writes = {}
local handlers = {}
local requests = {}
local hovers = {}
local clickableBars = { g1 = true, g2 = true }
local info = {
    [101] = { spellID = 31884, equipSlot = nil },
    [102] = { equipSlot = 13, spellID = 555 },
    [103] = { spellID = 2, spellCategoryID = 4 },
    [104] = { spellID = 1044 },
}
local source = { [101] = "essential", [102] = "essential", [103] = "utility", [104] = "buffs" }

local ns = {
    IsSecret = IsSecret,
    Write = function(frame, fn, key)
        writes[#writes + 1] = { frame = frame, key = key }
        fn(frame)
        return true
    end,
    Events = {
        Register = function(event, key, fn) handlers[event .. "/" .. key] = fn end,
        Unregister = function(event, key) handlers[event .. "/" .. key] = nil end,
    },
    Bars = { Request = function(key, level) requests[#requests + 1] = key .. ":" .. level end },
    Decorate = {
        HoverEnter = function(rec) hovers[#hovers + 1] = "enter:" .. tostring(rec.name) end,
        HoverLeave = function(rec) hovers[#hovers + 1] = "leave:" .. tostring(rec.name) end,
    },
    DB = { BarClickable = function(key) return clickableBars[key] == true end },
    Catalog = {
        Info = function(id) return info[id] end,
        SourceOf = function(id) return source[id] end,
    },
    Viewers = { AURA_KIND = { buffs = true, buffbars = true } },
}
Load(env, ns)
local CK = ns.Clickable

local function W() local n = #writes; writes = {}; return n end
local function Keys()
    local out = {}
    for _, w in ipairs(writes) do out[#out + 1] = w.key end
    writes = {}
    return table.concat(out, ",")
end

-- Enabled
eq("Enabled 走 DB.BarClickable（是）", CK.Enabled("g1"), true)
eq("Enabled 走 DB.BarClickable（否）", CK.Enabled("essential"), false)

-- Describe
do
    local d = CK.Describe({ id = "c:1", crec = { kind = "spell", spellID = 100 } })
    eq("Describe 自訂 kind", d and d.kind, "spell")
    eq("Describe 自訂 spellID", d and d.spellID, 100)
    eq("Describe 占位 → nil", CK.Describe({ id = 104, item = {}, placeholder = true }), nil)
    eq("Describe 缺框 → nil", CK.Describe({ id = 101 }), nil)
    d = CK.Describe({ id = 101, item = {}, rec = { barKey = "essential" } })
    eq("Describe 暴雪 kind", d and d.kind, "blizzard")
    eq("Describe 暴雪 spellID", d and d.spellID, 31884)
    eq("Describe 暴雪 aura=false", d and d.aura, false)
    d = CK.Describe({ id = 104, item = {}, rec = { barKey = "buffs" } })
    eq("Describe 增益來源 aura=true", d and d.aura, true)
    eq("增益來源解不出動作", CK.Resolve(d), nil)
    d = CK.Describe({ id = 101, item = {}, rec = { barKey = "buffbars" } })
    eq("Describe item 在增益檢視器 aura=true", d and d.aura, true)
    d = CK.Describe({ id = 103, item = {}, rec = { barKey = "utility" } })
    eq("Describe 物品冷卻類別 category=true", d and d.category, true)
    eq("物品冷卻類別解不出動作", CK.Resolve(d), nil)
    d = CK.Describe({ id = 102, item = {}, rec = { barKey = "essential" } })
    eq("暴雪飾品 → slot", (CK.Resolve(d) or {}).slot, 13)
    eq("Describe 不認得的 id → nil", CK.Describe({ id = 999, item = {} }), nil)
end

local c = NewFrame("Frame", "MiliUICDM_Bar_g1", nil)
c.level = 5
local recA = { name = "A" }
local function SpellE(id, rec) return { id = "c:1", crec = { kind = "spell", spellID = id, name = rec and rec.name, overlay = true } } end
local R1 = { x = 0, y = 0, w = 36, h = 36 }

------------------------------------------------------------
-- 3. Place：第一次全寫
------------------------------------------------------------
writes = {}
CK.Place("g1", c, 1, R1, SpellE(100, recA))
local b, s = CK.Button("g1", 1)
check("建了鈕", b ~= nil)
eq("模板", b and b.template, "SecureActionButtonTemplate")
eq("名字", b and b.name, "MiliUICDM_Click_g1_1")
eq("parent 是容器", b and b.parent, c)
eq("兩邊都註冊點擊", b and b.clicks and table.concat(b.clicks, ","), "AnyDown,AnyUp")
eq("收滑鼠移動", b and b.motion, true)
do
    local only = true
    for k in pairs(b.scripts) do
        if k ~= "OnEnter" and k ~= "OnLeave" then only = false end
    end
    check("鈕只掛 OnEnter／OnLeave", only)
    check("OnEnter 有掛", b.scripts.OnEnter ~= nil)
    check("沒有 PreClick／OnClick／OnMouseDown", not (b.scripts.PreClick or b.scripts.PostClick or b.scripts.OnClick or b.scripts.OnMouseDown))
end
eq("第一次：place＋action＋shown", Keys(), "place,action,shown")
eq("層級＝容器＋40", b.level, 45)
local p = b.points[1]
eq("錨點 TOPLEFT", p and p[1], "TOPLEFT")
eq("錨在容器", p and p[2], c)
eq("y 取負", p and p[5], -0)
eq("尺寸", b.w, 36)
eq("type", b.attrs.type, "spell")
eq("spell", b.attrs.spell, 100)
eq("item 清空", b.attrs.item, nil)
eq("顯示", b.shown, true)
eq("鈕身上沒有 rec 欄位（狀態在弱鍵表）", rawget(b, "rec"), nil)

------------------------------------------------------------
-- 4. 去重
------------------------------------------------------------
CK.Place("g1", c, 1, R1, SpellE(100, recA))
eq("同 rect 同動作：不寫", W(), 0)

CK.Place("g1", c, 1, R1, SpellE(200, recA))
eq("只換動作：只寫 action", Keys(), "action")
eq("換了 spell", b.attrs.spell, 200)

CK.Place("g1", c, 1, R1, { id = "c:2", crec = { kind = "item", itemID = 5512 } })
eq("換成物品：只寫 action", Keys(), "action")
eq("type item", b.attrs.type, "item")
eq("item:<id>", b.attrs.item, "item:5512")
eq("spell 清掉", b.attrs.spell, nil)

CK.Place("g1", c, 1, R1, { id = "c:3", crec = { kind = "slot", slot = 14 } })
eq("換成飾品欄：只寫 action", Keys(), "action")
eq("slot", b.attrs.slot, 14)
eq("item 清掉", b.attrs.item, nil)

local R2 = { x = 37, y = 0, w = 36, h = 36 }
CK.Place("g1", c, 1, R2, { id = "c:3", crec = { kind = "slot", slot = 14 } })
eq("只換 rect：只寫 place", Keys(), "place")
eq("新的 x", b.points[1] and b.points[1][4], 37)

------------------------------------------------------------
-- 5. 沒有動作 ⇒ Hide（一次）；有動作 ⇒ Show 回來
------------------------------------------------------------
CK.Place("g1", c, 1, R2, { id = "c:4", crec = { kind = "aura", spellID = 774 } })
eq("光環格：寫 Hide", Keys(), "shown")
eq("鈕藏起來", b.shown, false)
CK.Place("g1", c, 1, R2, { id = "c:4", crec = { kind = "aura", spellID = 774 } })
eq("光環格第二次：不寫", W(), 0)
local nBefore = #created
CK.Place("g1", c, 2, R1, { id = "c:5", crec = { kind = "aura", spellID = 774 } })
eq("沒有動作的新格：不建鈕", #created, nBefore)
eq("沒有動作的新格：不寫", W(), 0)
CK.Place("g1", c, 1, R2, { id = "c:3", crec = { kind = "slot", slot = 14 } })
eq("動作回來：只寫 Show", Keys(), "shown")
eq("鈕顯示", b.shown, true)
CK.Place("g1", c, 1, R2, { id = 104, item = {}, rec = { barKey = "buffs" }, placeholder = true })
eq("占位格：寫 Hide", Keys(), "shown")
CK.Place("g1", c, 1, R2, { id = 101, item = {}, rec = { barKey = "essential", name = "blz" } })
eq("暴雪法術：action＋shown", Keys(), "action,shown")
eq("暴雪法術 spell", b.attrs.spell, 31884)

------------------------------------------------------------
-- 6. hover 轉給 Decorate
------------------------------------------------------------
hovers = {}
b.scripts.OnEnter(b)
b.scripts.OnLeave(b)
eq("hover 轉給 Decorate（暴雪 rec）", table.concat(hovers, ","), "enter:blz,leave:blz")
CK.Place("g1", c, 1, R2, { id = "c:4", crec = { kind = "aura" } })
writes = {}
hovers = {}
b.scripts.OnEnter(b)
eq("藏起來的鈕沒有 rec：不轉", #hovers, 0)

------------------------------------------------------------
-- 7. EndBar 收多的
------------------------------------------------------------
CK.Place("g1", c, 1, R1, SpellE(100, recA))
CK.Place("g1", c, 2, R2, SpellE(101, recA))
CK.Place("g1", c, 3, { x = 74, y = 0, w = 36, h = 36 }, SpellE(102, recA))
writes = {}
local b2 = CK.Button("g1", 2)
local b3 = CK.Button("g1", 3)
CK.EndBar("g1", 2)
eq("EndBar：只收第 3 顆", Keys(), "shown")
eq("第 3 顆藏起來", b3.shown, false)
eq("第 2 顆還在", b2.shown, true)
CK.EndBar("g1", 2)
eq("EndBar 第二次：不寫", W(), 0)
CK.EndBar("nope", 0)
eq("EndBar 沒有池子：不炸不寫", W(), 0)

------------------------------------------------------------
-- 8. Release：全部 Hide＋ClearAllPoints、清簽章；第二次 no-op；再開要全寫
------------------------------------------------------------
local clearsBefore = b.calls.ClearAllPoints
CK.Release("g1")
eq("Release：三顆都寫", W(), 3)
eq("Release：藏起來", b.shown, false)
eq("Release：脫離錨點", b.calls.ClearAllPoints, clearsBefore + 1)
eq("Release：錨點清空", #b.points, 0)
local _, s1 = CK.Button("g1", 1)
eq("Release：place 簽章清空", s1.placeSig, nil)
eq("Release：action 簽章清空", s1.actionSig, nil)
CK.Release("g1")
eq("Release 第二次：不寫", W(), 0)
CK.Release("never")
eq("Release 沒有池子：不寫", W(), 0)
CK.Place("g1", c, 1, R1, SpellE(100, recA))
eq("Release 之後再開：全寫", Keys(), "place,action,shown")
eq("Release 之後再開：又錨上", #b.points, 1)

------------------------------------------------------------
-- 9. 戰鬥中不建鈕：pending → 脫戰 Request
------------------------------------------------------------
combat = true
nBefore = #created
CK.Place("g2", c, 1, R1, SpellE(100, recA))
eq("戰鬥中：不建鈕", #created, nBefore)
check("戰鬥中：等脫戰", handlers["PLAYER_REGEN_ENABLED/clickable"] ~= nil)
eq("戰鬥中：一筆都不寫", W(), 0)
eq("Counts pending", CK.Counts().pending, 1)
combat = false
handlers["PLAYER_REGEN_ENABLED/clickable"]()
eq("脫戰：要求那條重排", table.concat(requests, ","), "g2:layout")
check("脫戰：一次性（反註冊）", handlers["PLAYER_REGEN_ENABLED/clickable"] == nil)
CK.Place("g2", c, 1, R1, SpellE(100, recA))
check("脫戰重排：補建", (CK.Button("g2", 1)) ~= nil)

-- 戰鬥中已有鈕：照樣經 ns.Write（由它決定記帳），簽章照樣去重
combat = true
writes = {}
CK.Place("g2", c, 1, R1, SpellE(100, recA))
eq("戰鬥中已有鈕、沒變：不寫", W(), 0)
CK.Place("g2", c, 1, R1, SpellE(300, recA))
eq("戰鬥中已有鈕、換動作：交給 ns.Write", Keys(), "action")
combat = false

------------------------------------------------------------
-- 10. 編輯模式：鈕收起來；離開後重排放回來
------------------------------------------------------------
writes = {}
ns.EditMode = { active = true }
local bE = CK.Button("g2", 1)
CK.Place("g2", c, 1, R1, SpellE(300, recA))
eq("編輯模式：寫 Hide", Keys(), "shown")
eq("編輯模式：鈕藏起來", bE.shown, false)
requests = {}
CK.OnEditModeChanged()
check("進出編輯模式：有鈕的條要求重排", table.concat(requests, ","):find("g2:layout", 1, true) ~= nil)
ns.EditMode.active = false
CK.Place("g2", c, 1, R1, SpellE(300, recA))
eq("離開編輯模式：只寫 Show", Keys(), "shown")
eq("離開編輯模式：鈕顯示", bE.shown, true)
ns.EditMode = nil

------------------------------------------------------------
-- 11. ReleaseAll
------------------------------------------------------------
writes = {}
CK.ReleaseAll()
local g1Shown, g2Shown = (CK.Button("g1", 1)).shown, (CK.Button("g2", 1)).shown
eq("ReleaseAll：g1 收", g1Shown, false)
eq("ReleaseAll：g2 收", g2Shown, false)

------------------------------------------------------------
-- 12. 帶替代品的自訂物品：鈕跟著解析後的 rec.itemID（不是主的）；換了只寫 action
------------------------------------------------------------
do
    -- 主 241308 包包裡沒有、替代品 241309 有：Custom 已經把 rec.itemID 換成 241309
    local crec = { kind = "item", itemID = 241309, name = "藥水",
                   entry = { kind = "item", itemID = 241308, alts = { 241309 } } }
    local d = CK.Describe({ id = "c:5", crec = crec })
    eq("Describe 物品取解析後的 itemID", d and d.itemID, 241309)
    eq("Resolve 物品 → item:<解析後>", (CK.Resolve(d) or {}).item, "item:241309")
    clickableBars.g3 = true
    writes = {}
    CK.Place("g3", c, 1, R1, { id = "c:5", crec = crec })
    local b3 = CK.Button("g3", 1)
    eq("替代品：屬性是解析後的那件", b3 and b3.attrs.item, "item:241309")
    writes = {}
    crec.itemID = 241308                 -- 包包裡又有主的了
    CK.Place("g3", c, 1, R1, { id = "c:5", crec = crec })
    eq("換回主的：只寫 action", Keys(), "action")
    eq("換回主的：屬性跟著換", b3 and b3.attrs.item, "item:241308")
end

print(("Clickable_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
