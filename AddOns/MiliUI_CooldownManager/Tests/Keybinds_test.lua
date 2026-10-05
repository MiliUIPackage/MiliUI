------------------------------------------------------------
-- Core/Keybinds.lua 的離線自我測試（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Keybinds_test.lua
--
-- 覆蓋：綁定字串縮寫（修飾鍵、滑鼠鍵、數字鍵盤、特殊鍵、減號鍵）、動作條格 → 指令名
-- （主動作條翻頁／變形、左下右下右側、動作條 6–8、不收的頁）、同一個法術多格時的優先序、
-- 覆寫法術優先、物品掃格子、快取與清快取；按鍵鏡射（綁定指令參數 → 格號全表、格號登記／撤銷／整張重建、
-- 按下／放開的狀態機、2 秒保險、載具與寵物對戰、掛勾只掛一次）；閃光跟著 Masque 皮的遮罩。
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."
local PATH = here .. "/../Core/Keybinds.lua"

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

local env = setmetatable({}, { __index = _G })
env._G = env
local bindings = {}
local page, bonus = 1, 0
local spellSlots = {}
local actions = {}
local findCalls = 0
env.GetBindingKey = function(cmd) return bindings[cmd] end
env.GetBonusBarOffset = function() return bonus end
env.C_ActionBar = {
    GetActionBarPage = function() return page end,
    FindSpellActionButtons = function(id) findCalls = findCalls + 1; return spellSlots[id] end,
}
env.GetActionInfo = function(slot)
    local a = actions[slot]
    if a then return a[1], a[2] end
end
local timers = {}
env.C_Timer = { After = function(sec, fn) timers[#timers + 1] = { sec = sec, fn = fn } end }
local hooks = {}
env.hooksecurefunc = function(name, fn) hooks[name] = (hooks[name] or 0) + 1 end
local vehicle, petBattle = false, false
env.HasVehicleActionBar = function() return vehicle end
env.HasOverrideActionBar = function() return false end
env.C_PetBattles = { IsInBattle = function() return petBattle end }
env.ActionButtonDown, env.ActionButtonUp = function() end, function() end
env.MultiActionButtonDown, env.MultiActionButtonUp = function() end, function() end

local ns = { IsSecret = function() return false end, Events = { Register = function() end } }
local chunk, err
if setfenv then
    chunk, err = loadfile(PATH)
    if chunk then setfenv(chunk, env) end
else
    chunk, err = loadfile(PATH, "t", env)
end
assert(chunk, err)
chunk("MiliUI_CooldownManager", ns)
local K = ns.Keybinds

------------------------------------------------------------
-- 1. 縮寫
------------------------------------------------------------
local cases = {
    { "1", "1" }, { "Q", "Q" }, { "SHIFT-1", "s1" }, { "CTRL-SHIFT-Q", "csQ" }, { "ALT-CTRL-SHIFT-E", "acsE" },
    { "BUTTON4", "M4" }, { "ALT-BUTTON5", "aM5" }, { "MIDDLEMOUSE", "M3" }, { "MOUSEWHEELUP", "WU" },
    { "SHIFT-MOUSEWHEELDOWN", "sWD" }, { "NUMPAD5", "N5" }, { "CTRL-NUMPAD0", "cN0" }, { "NUMPADPLUS", "N+" },
    { "SPACE", "Sp" }, { "F11", "F11" }, { "CTRL--", "c-" }, { "-", "-" }, { "SHIFT-=", "s=" },
    { "PAGEUP", "PU" }, { "META-A", "mA" },
}
for _, c in ipairs(cases) do eq("Abbrev " .. c[1], K.Abbrev(c[1]), c[2]) end
eq("Abbrev nil", K.Abbrev(nil), nil)
eq("Abbrev 空字串", K.Abbrev(""), nil)

------------------------------------------------------------
-- 2. 格 → 指令
------------------------------------------------------------
local function cmd(slot, p) return (K.CommandForSlot(slot, p)) end
eq("slot 1 主動作條", cmd(1, 1), "ACTIONBUTTON1")
eq("slot 12 主動作條", cmd(12, 1), "ACTIONBUTTON12")
eq("slot 13 第二頁（沒翻頁時是備援）", cmd(13, 1), "ACTIONBUTTON1")
eq("slot 13 翻到第二頁", select(2, K.CommandForSlot(13, 2)), 0)
eq("slot 1 翻到第二頁時是備援", select(2, K.CommandForSlot(1, 2)), 2)
eq("slot 25 右側", cmd(25, 1), "MULTIACTIONBAR3BUTTON1")
eq("slot 48 右側第二條", cmd(48, 1), "MULTIACTIONBAR4BUTTON12")
eq("slot 49 右下", cmd(49, 1), "MULTIACTIONBAR2BUTTON1")
eq("slot 61 左下", cmd(61, 1), "MULTIACTIONBAR1BUTTON1")
eq("slot 72 左下最後", cmd(72, 1), "MULTIACTIONBAR1BUTTON12")
eq("slot 145 動作條 6", cmd(145, 1), "MULTIACTIONBAR5BUTTON1")
eq("slot 160 動作條 7", cmd(160, 1), "MULTIACTIONBAR6BUTTON4")
eq("slot 180 動作條 8", cmd(180, 1), "MULTIACTIONBAR7BUTTON12")
local DRUID = K.BONUS_PAGES.DRUID
eq("slot 75 變形那頁（德魯伊沒變形）是備援", (K.CommandForSlot(75, 1, DRUID)), "ACTIONBUTTON3")
eq("slot 75 德魯伊沒變形時 rank 2", select(2, K.CommandForSlot(75, 1, DRUID)), 2)
eq("slot 75 沒有變形頁的職業不收（那是快捷列插件的頁）", cmd(75, 1), nil)
eq("slot 85 盜賊只有潛行頁：第 8 頁不收", (K.CommandForSlot(85, 1, K.BONUS_PAGES.ROGUE)), nil)
eq("slot 75 盜賊潛行頁是備援", (K.CommandForSlot(75, 1, K.BONUS_PAGES.ROGUE)), "ACTIONBUTTON3")
eq("slot 75 變形成第 7 頁", cmd(75, 7), "ACTIONBUTTON3")
eq("slot 75 變形成第 7 頁時 rank 0", select(2, K.CommandForSlot(75, 7)), 0)
eq("slot 110 第 10 頁（德魯伊沒變形）是備援", (K.CommandForSlot(110, 1, DRUID)), "ACTIONBUTTON2")
eq("slot 3 變形成第 7 頁時是備援", select(2, K.CommandForSlot(3, 7)), 2)
eq("slot 121 載具那頁不收", cmd(121, 1), nil)
eq("slot 0 不收", cmd(0, 1), nil)
eq("slot nil 不收", cmd(nil, 1), nil)

------------------------------------------------------------
-- 3. 多格：主動作條目前那頁優先、其次側邊、最後備援；沒綁鍵的跳過
------------------------------------------------------------
bindings = {
    ACTIONBUTTON3 = "3", MULTIACTIONBAR1BUTTON2 = "SHIFT-2", MULTIACTIONBAR3BUTTON1 = "CTRL-1",
}
eq("側邊與主條都有 ⇒ 主條", K.FromSlots({ 62, 3 }), "3")
eq("只有側邊", K.FromSlots({ 62 }), "s2")
eq("兩條側邊 ⇒ 格號小的", K.FromSlots({ 62, 25 }), "c1")
eq("格子沒綁鍵 ⇒ 下一格", K.FromSlots({ 4, 62 }), "s2")
eq("都沒綁 ⇒ nil", K.FromSlots({ 4, 5 }), nil)
bonus = 1          -- 變形：主條顯示第 7 頁（73–84）
bindings.ACTIONBUTTON5 = "5"
eq("變形時第 7 頁的格子優先", K.FromSlots({ 3, 77 }), "5")
eq("變形時只在第 1 頁的技能照樣有鍵", K.FromSlots({ 3 }), "3")
bonus = 0
ns.playerClass = "DRUID"   -- 變形頁的備援只有德魯伊／盜賊（K.BONUS_PAGES）
eq("人形時第 1 頁與第 7 頁都有 ⇒ 第 1 頁", K.FromSlots({ 77, 3 }), "3")
eq("人形時只在第 7 頁的技能照樣有鍵", K.FromSlots({ 77 }), "5")
eq("人形時側邊勝過第 7 頁的備援", K.FromSlots({ 77, 62 }), "s2")
ns.playerClass = "MAGE"
eq("沒有變形頁的職業：第 7 頁的格子不算（快捷列插件的頁）", K.FromSlots({ 77 }), nil)
ns.playerClass = nil

------------------------------------------------------------
-- 4. 法術／物品查詢與快取
------------------------------------------------------------
spellSlots[100] = { 3 }
spellSlots[101] = { 62 }
eq("基礎法術", K.TextForSpell(100), "3")
eq("覆寫法術優先", K.TextForSpell(100, 101), "s2")
spellSlots[102] = nil
eq("覆寫找不到 ⇒ 退回基礎", K.TextForSpell(100, 102), "3")
local calls = findCalls
eq("快取", K.TextForSpell(100), "3")
eq("快取命中不再問", findCalls, calls)
eq("沒放在任何格", K.TextForSpell(999), nil)
local calls2 = findCalls
K.TextForSpell(999)
eq("「沒有」也快取", findCalls, calls2)
actions[25] = { "item", 5512 }
actions[26] = { "spell", 5512 }
eq("物品掃格子", K.TextForItem(5512), "c1")
eq("物品不在動作條", K.TextForItem(1), nil)
check("CacheSize", K.CacheSize() > 0)

------------------------------------------------------------
-- 以增益取代（P7）：頂著核心技能那一格的增益（rec.replacing）不畫按鍵；條本身照舊
------------------------------------------------------------
do
    local savedSetting, savedDB = ns.Setting, ns.DB
    ns.Setting = function(_, path) if path == "keybind.enabled" then return true end end
    ns.DB = { BarTable = function() return { kind = "icons", source = "essential" } end }
    local hidden, text = false, nil
    local fs = { SetText = function(_, t) text = t end, Hide = function() hidden = true end }
    local rec = { overlay = {}, keyFS = fs, keySig = "old", replacing = 102, cooldownID = 301 }
    K.Apply({}, rec, "essential")
    eq("取代中：按鍵文字收起來", rec.keySig, "off")
    check("取代中：藏起來、字清掉", hidden and text == "")
    check("NoKeybind：核心技能條照舊要畫", not K.NoKeybind("essential"))
    ns.Setting, ns.DB = savedSetting, savedDB
end

------------------------------------------------------------
-- 逐法術「隱藏按鍵文字」（H）：樣式與隱藏都從 Text.SpellText(barKey, id, "keybind") 拿（合併只在那一支）
------------------------------------------------------------
do
    local savedSetting, savedDB, savedText = ns.Setting, ns.DB, ns.Text
    ns.Setting = function(_, path) if path == "keybind.enabled" then return true end end
    ns.DB = { BarTable = function() return { kind = "icons", source = "essential" } end }
    local asked
    ns.Text = { SpellText = function(bk, id, sec) asked = { bk, id, sec }; return { size = 14 }, true, {} end }
    local hidden, text = false, nil
    local fs = { SetText = function(_, t) text = t end, Hide = function() hidden = true end }
    local rec = { overlay = {}, keyFS = fs, keySig = "old", cooldownID = 302 }
    K.Apply({}, rec, "essential")
    check("問的是這一條、這一招、按鍵那一段", asked and asked[1] == "essential" and asked[2] == 302 and asked[3] == "keybind")
    eq("這一招隱藏按鍵文字 ⇒ 收起來", rec.keySig, "off")
    check("隱藏 ⇒ 藏起來、字清掉", hidden and text == "")
    ns.Setting, ns.DB, ns.Text = savedSetting, savedDB, savedText
end


------------------------------------------------------------
-- 按鍵鏡射（F2）
------------------------------------------------------------
-- 1) 綁定指令參數 → 格號：全表。框名 ↔ 指令前綴照 Bindings_Standard.xml（MULTIACTIONBAR<k>BUTTON<n> 叫
--    MultiActionButtonDown("<框名>", n)），框名 ↔ actionpage 照 MultiActionBars.xml
local BAR_CMD = {
    MultiBarBottomLeft = { 6, "MULTIACTIONBAR1BUTTON" }, MultiBarBottomRight = { 5, "MULTIACTIONBAR2BUTTON" },
    MultiBarRight = { 3, "MULTIACTIONBAR3BUTTON" }, MultiBarLeft = { 4, "MULTIACTIONBAR4BUTTON" },
    MultiBar5 = { 13, "MULTIACTIONBAR5BUTTON" }, MultiBar6 = { 14, "MULTIACTIONBAR6BUTTON" },
    MultiBar7 = { 15, "MULTIACTIONBAR7BUTTON" },
}
local nBars = 0
for name in pairs(K.PRESS_BAR_PAGE) do
    nBars = nBars + 1
    check("PRESS_BAR_PAGE 只有已知的框名 " .. name, BAR_CMD[name] ~= nil)
end
eq("PRESS_BAR_PAGE 七條", nBars, 7)
for name, def in pairs(BAR_CMD) do
    local page, prefix = def[1], def[2]
    eq("PRESS_BAR_PAGE " .. name, K.PRESS_BAR_PAGE[name], page)
    eq("MULTI 同一張對照 " .. name, K.MULTI[page], prefix)
    for id = 1, 12 do
        local slot = K.SlotFromButton(name, id, 1)
        eq(("SlotFromButton %s %d"):format(name, id), slot, (page - 1) * 12 + id)
        -- 反過來：那一格的綁定指令就是這顆鍵
        eq(("格號回指令 %s %d"):format(name, id), (K.CommandForSlot(slot, 1)), prefix .. id)
    end
    eq("主動作條翻頁不影響其他條 " .. name, K.SlotFromButton(name, 3, 7), (page - 1) * 12 + 3)
end
for _, pg in ipairs({ 1, 2, 7, 8, 9, 10 }) do
    for id = 1, 12 do
        eq(("SlotFromButton 主動作條 第%d頁 %d"):format(pg, id), K.SlotFromButton(nil, id, pg), (pg - 1) * 12 + id)
    end
end
eq("SlotFromButton 主動作條 mainPage nil ＝ 第 1 頁", K.SlotFromButton(nil, 5, nil), 5)
eq("SlotFromButton 不認得的框名", K.SlotFromButton("StanceBar", 1, 1), nil)
eq("SlotFromButton 寵物條", K.SlotFromButton("PetActionBar", 1, 1), nil)
eq("SlotFromButton id 0", K.SlotFromButton(nil, 0, 1), nil)
eq("SlotFromButton id 13", K.SlotFromButton("MultiBarLeft", 13, 1), nil)
eq("SlotFromButton id 小數", K.SlotFromButton(nil, 1.5, 1), nil)
eq("SlotFromButton id nil", K.SlotFromButton(nil, nil, 1), nil)
eq("SlotFromButton id 字串數字", K.SlotFromButton("MultiBarRight", "2", 1), 26)

-- 2) 登記／撤銷：K.Apply 放格時登記（跟按鍵文字的開關無關）
local function FakeTex()
    local t = { shown = false, shows = 0, hides = 0 }
    function t:SetTexture() end
    function t:SetAllPoints() end
    function t:SetBlendMode(m) self.blend = m end
    function t:SetVertexColor(r, g, b, a) self.a = a end
    function t:Show() self.shown = true; self.shows = self.shows + 1 end
    function t:Hide() self.shown = false; self.hides = self.hides + 1 end
    function t:IsShown() return self.shown end
    return t
end
local texMade = 0
local function FakeOverlay()
    return { CreateTexture = function() texMade = texMade + 1; return FakeTex() end,
             CreateFontString = function() return { SetText = function() end, Hide = function() end } end }
end
local press = { flash = true, alpha = 0.5, kind = "icons", keybind = false, source = "essential" }
local savedSetting, savedDB = ns.Setting, ns.DB
ns.Setting = function(_, path)
    if path == "icon.pressFlash" then return press.flash end
    if path == "icon.pressFlashAlpha" then return press.alpha end
    if path == "kind" then return press.kind end
    if path == "keybind.enabled" then return press.keybind end
end
ns.DB = { BarTable = function() return { kind = press.kind, source = press.source } end }
local function count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

spellSlots[700] = { 5, 63 }               -- 主動作條第 5 格＋左下第 3 格
spellSlots[701] = { 63 }                  -- 覆寫法術也在左下第 3 格（去重）
spellSlots[710] = { 5 }                   -- 另一招也放在第 5 格（同一格兩個格子都登記）
local recA = { overlay = FakeOverlay(), custom = true, kind = "spell", spellID = 700, overrideID = 701 }
local recB = { overlay = FakeOverlay(), custom = true, kind = "spell", spellID = 710 }
K.Apply({}, recA, "essential")
K.Apply({}, recB, "essential")
check("掛勾：第一次有條要用才掛、四支各一次", hooks.ActionButtonDown == 1 and hooks.ActionButtonUp == 1
    and hooks.MultiActionButtonDown == 1 and hooks.MultiActionButtonUp == 1)
eq("登記：第 5 格兩顆", count(K.slotOwners[5]), 2)
eq("登記：第 63 格一顆（覆寫與基礎去重）", count(K.slotOwners[63]), 1)
check("按鍵文字關著也登記（沒建字串）", recA.keyFS == nil and count(K.slotOwners[63]) == 1)
eq("還沒按過不建貼圖", texMade, 0)
K.Apply({}, recA, "essential")
eq("重複 Apply 不重複登記", count(K.slotOwners[5]), 2)
K.Apply({}, recB, "essential")
check("掛勾不重掛", hooks.ActionButtonDown == 1)

-- 3) 按下／放開
page, bonus = 1, 0
K.OnPress(nil, 5, true)
check("按下：兩顆都亮", recA.pressTex and recA.pressTex.shown and recB.pressTex and recB.pressTex.shown)
eq("貼圖 ADD", recA.pressTex.blend, "ADD")
eq("透明度照條層", recA.pressTex.a, 0.5)
eq("保險計時 2 秒", timers[#timers].sec, 2)
K.OnPress(nil, 5, false)
check("放開：都收", not recA.pressTex.shown and not recB.pressTex.shown)
K.OnPress("MultiBarBottomLeft", 3, true)
check("左下第 3 格：只有 A 亮", recA.pressTex.shown and not recB.pressTex.shown)
K.OnPress("MultiBarBottomLeft", 3, false)
check("左下放開", not recA.pressTex.shown)
-- 同一顆 A 兩格同時按住：放開一格還亮著，兩格都放開才收
K.OnPress(nil, 5, true)
K.OnPress("MultiBarBottomLeft", 3, true)
K.OnPress(nil, 5, false)
check("兩格按住放開一格：A 還亮、B 收", recA.pressTex.shown and not recB.pressTex.shown)
K.OnPress("MultiBarBottomLeft", 3, false)
check("兩格都放開：A 收", not recA.pressTex.shown)
-- 翻頁：主動作條第 2 頁的第 5 鍵是第 17 格，不是這兩顆
page = 2
K.OnPress(nil, 5, true)
check("翻到第 2 頁：第 5 鍵不亮第 5 格", not recA.pressTex.shown and not recB.pressTex.shown)
K.OnPress(nil, 5, false)
page = 1
-- 按下時在第 1 頁、放開前變形（頁變了）：放開照樣收按下時亮的那幾顆
K.OnPress(nil, 5, true)
bonus = 1
K.OnPress(nil, 5, false)
check("按下後變形再放開：照樣收", not recA.pressTex.shown and not recB.pressTex.shown)
bonus = 0
-- 漏了 Up 又按一次：先收上一次（不疊計數）
K.OnPress(nil, 5, true)
K.OnPress(nil, 5, true)
K.OnPress(nil, 5, false)
check("漏 Up 再按：放開一次就收", not recA.pressTex.shown and (recA.pressN or 0) == 0)

-- 4) 2 秒保險：放開事件漏掉
timers = {}
K.OnPress(nil, 5, true)
check("保險前亮著", recA.pressTex.shown)
eq("排了一個保險計時", #timers, 1)
timers[1].fn()
check("2 秒保險：收掉", not recA.pressTex.shown and not recB.pressTex.shown)
eq("保險收完沒有按住的鍵", count(K.held), 0)
-- 保險計時到之前已經放開又重按：舊的保險不收新的那次
timers = {}
K.OnPress(nil, 5, true)
K.OnPress(nil, 5, false)
K.OnPress(nil, 5, true)
timers[1].fn()
check("舊保險不收新的按下", recA.pressTex.shown)
timers[2].fn()
check("新保險照收", not recA.pressTex.shown)

-- 5) 秘密值、載具、寵物對戰
local savedSecret = ns.IsSecret
ns.IsSecret = function(v) return v == "SECRET" end
K.OnPress(nil, "SECRET", true)
check("秘密參數：忽略", not recA.pressTex.shown)
K.OnPress("SECRET", 3, true)
check("秘密框名：忽略", not recA.pressTex.shown)
ns.IsSecret = savedSecret
vehicle = true
K.OnPress(nil, 5, true)
check("載具：主動作條的鍵不閃", not recA.pressTex.shown)
K.OnPress("MultiBarBottomLeft", 3, true)
check("載具：側邊條照閃", recA.pressTex.shown)
K.OnPress("MultiBarBottomLeft", 3, false)
vehicle = false
petBattle = true
K.OnPress("MultiBarBottomLeft", 3, true)
check("寵物對戰：不閃", not recA.pressTex.shown)
petBattle = false

-- 6) 停放、關掉、以增益取代、長條類／增益圖示列
K.OnPress(nil, 5, true)
K.OnParked(recA)
check("停放：收掉閃光", not recA.pressTex.shown)
eq("停放：撤銷登記", count(K.slotOwners[5]), 1)
eq("停放：左下那格整格清掉", K.slotOwners[63], nil)
K.OnPress(nil, 5, false)
eq("停放後放開不出錯、計數不為負", recA.pressN, 0)
K.Apply({}, recA, "essential")
eq("重新放格：再登記", count(K.slotOwners[5]), 2)
press.alpha = 0.2
K.Apply({}, recA, "essential")
eq("透明度改了：已建的貼圖跟著換", recA.pressTex.a, 0.2)
press.alpha = 0.5
recA.replacing = 999
K.Apply({}, recA, "essential")
eq("以增益取代中：撤銷", count(K.slotOwners[5]), 1)
recA.replacing = nil
press.source = "buffs"
K.Apply({}, recA, "tracked")
eq("增益圖示列：不登記", count(K.slotOwners[5]), 1)
press.source, press.kind = "custom", "bars"
K.Apply({}, recA, "g1")
eq("長條類：不登記", count(K.slotOwners[5]), 1)
press.source, press.kind = "essential", "icons"
press.flash = false
K.Apply({}, recB, "essential")
eq("關掉：撤銷", K.slotOwners[5], nil)
check("全部撤銷後掛勾第一行就走", next(K.slotOwners) == nil)
K.OnPress(nil, 5, true)
check("沒有登記：按了不亮", not recB.pressTex.shown)
press.flash = true

-- 7) RefreshAll 整張重建（動作條變了：第 5 格的法術搬到第 6 格）
K.Apply({}, recA, "essential")
K.Apply({}, recB, "essential")
local placed = { recA, recB }
ns.profile = { bars = { essential = {} } }
ns.Bars = { ForEachClaimed = function(_, fn) for _, r in ipairs(placed) do fn({}, r) end end }
spellSlots[700] = { 6 }
spellSlots[710] = { 6 }
local oldTable = K.slotOwners
K.RefreshAll()
check("RefreshAll：換一張新表", K.slotOwners ~= oldTable)
eq("RefreshAll：舊格清掉", K.slotOwners[5], nil)
eq("RefreshAll：新格兩顆", count(K.slotOwners[6]), 2)
-- Invalidate：有登記時排一次 RefreshAll
timers = {}
K.Invalidate()
eq("Invalidate：排一次重建", #timers, 1)
eq("Invalidate：0.2 秒合併", timers[1].sec, 0.2)
ns.Bars, ns.profile = nil, nil
ns.Setting, ns.DB = savedSetting, savedDB

------------------------------------------------------------
-- 8. 閃光跟著 Masque 皮的形狀（F）：從被套皮的 Icon 讀遮罩、在 overlay 上自己建一張掛到閃光上；
--    沒交給 Masque 不讀不建、換皮重讀、拿掉、讀不到 ⇒ 方形
------------------------------------------------------------
do
    local chunk2
    if setfenv then
        chunk2 = assert(loadfile(here .. "/../Core/MasqueShape.lua"))
        setfenv(chunk2, env)
    else
        chunk2 = assert(loadfile(here .. "/../Core/MasqueShape.lua", "t", env))
    end
    chunk2("MiliUI_CooldownManager", ns)

    local masks = 0
    local function MaskTex()
        masks = masks + 1
        local m = { shown = true }
        function m:SetTexture(f) self.file, self.atlas = f, nil end
        function m:SetAtlas(a) self.atlas, self.file = a, nil end
        function m:ClearAllPoints() self.point = nil end
        function m:SetSize(w, h) self.w, self.h = w, h end
        function m:SetPoint(...) self.point = { ... } end
        function m:Show() self.shown = true end
        function m:Hide() self.shown = false end
        return m
    end
    local function Overlay()
        local ov = FakeOverlay()
        ov.CreateTexture = function()
            local t = FakeTex()
            t.masks = {}
            function t:AddMaskTexture(m) self.masks[#self.masks + 1] = m end
            function t:RemoveMaskTexture(m)
                for i, x in ipairs(self.masks) do if x == m then table.remove(self.masks, i) break end end
            end
            return t
        end
        ov.CreateMaskTexture = function() return MaskTex() end
        return ov
    end
    -- 被套皮的按鈕：Icon 錨按鈕中心 32×32；皮的遮罩錨 Icon 中心偏 (1,-1)、30×30、插件貼圖（檔案編號負數）
    local reads = 0
    local function Region(w, h, point, maskOf)
        local r = { w = w, h = h, point = point }
        function r:GetNumPoints() return 1 end
        function r:GetPoint() return (table.unpack or unpack)(self.point) end
        function r:GetWidth() return self.w end
        function r:GetHeight() return self.h end
        function r:GetTexCoord() return 0, 0, 0, 1, 1, 0, 1, 1 end
        function r:GetNumMaskTextures() reads = reads + 1; return maskOf and #maskOf or 0 end
        function r:GetMaskTexture(i) return maskOf[i] end
        return r
    end
    local btn = {}
    local skinMasks = {}
    local icon = Region(32, 32, { "CENTER", btn, "CENTER", 0, 0 }, skinMasks)
    btn.Icon = icon
    local sm = Region(30, 30, { "CENTER", icon, "CENTER", 1, -1 })
    sm.GetTextureFileID = function() return -5272 end
    skinMasks[1] = sm

    local gen, avail = 0, 0
    local savedM = ns.Masque
    ns.Masque = { Available = function() avail = avail + 1; return true end, Generation = function() return gen end }

    -- 沒交給 Masque：不問 Masque、不讀、不建
    local ovN = Overlay()
    local rn = { overlay = ovN, glowW = 36, glowH = 36 }
    K.PressTexture(rn, ovN, 0.5)
    check("沒交出去：不問 Masque、不讀、不建遮罩", avail == 0 and reads == 0 and masks == 0 and rn.pressMask == nil)

    local ov = Overlay()
    local rec = { overlay = ov, msqSkinned = true, msqButton = btn, glowW = 36, glowH = 36, msqSize = "36x36" }
    local t = K.PressTexture(rec, ov, 0.5)
    local m = t.masks[1]
    check("圓形皮：閃光掛上自己建的遮罩", m ~= nil and masks == 1 and rec.pressMask and rec.pressMask.on)
    eq("遮罩：負的檔案編號照收", m and m.file, -5272)
    check("遮罩：同一個矩形（30、相對中心 1,-1、錨 overlay）", m and m.w == 30 and m.point[2] == ov and m.point[4] == 1 and m.point[5] == -1)
    local r0 = reads
    K.PressTexture(rec, ov, 0.5)
    eq("再按：快取（不重讀）", reads, r0)
    eq("再按：不多掛", #t.masks, 1)
    gen = gen + 1
    sm.w = 28
    K.PressTexture(rec, ov, 0.5)
    check("換皮（Generation 變）：重讀、重用同一張遮罩", reads > r0 and masks == 1 and #t.masks == 1 and t.masks[1] == m and m.w == 28)
    -- 群組停用／換回米利：拿掉遮罩
    rec.msqSkinned = false
    K.PressTexture(rec, ov, 0.5)
    check("沒交出去了：遮罩拿掉（閃光回方形）", #t.masks == 0 and rec.pressMask == nil and not m.shown)
    -- 方形皮（沒有遮罩）：照舊方形、讀過就記
    rec.msqSkinned = true
    skinMasks[1] = nil
    gen = gen + 1
    K.PressTexture(rec, ov, 0.5)
    check("方形皮：沒有遮罩", #t.masks == 0 and rec.pressMask and not rec.pressMask.on)
    local r1 = reads
    K.PressTexture(rec, ov, 0.5)
    eq("方形皮：讀過就記", reads, r1)
    -- 讀到一半出錯：方形、不報錯
    icon.GetPoint = function() error("boom") end
    gen = gen + 1
    local ok = pcall(K.PressTexture, rec, ov, 0.5)
    check("讀不到：不報錯、方形", ok and #t.masks == 0)
    -- 長條：不做
    local rb = { overlay = Overlay(), msqSkinned = true, msqButton = btn, barGeometry = {}, glowW = 36, glowH = 36 }
    local av0 = avail
    K.PressTexture(rb, rb.overlay, 0.5)
    eq("長條：不問 Masque", avail, av0)
    ns.Masque = savedM
end

print(("Keybinds_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
