------------------------------------------------------------
-- Core/Keybinds.lua 的離線自我測試（不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/Keybinds_test.lua
--
-- 覆蓋：綁定字串縮寫（修飾鍵、滑鼠鍵、數字鍵盤、特殊鍵、減號鍵）、動作條格 → 指令名
-- （主動作條翻頁／變形、左下右下右側、動作條 6–8、不收的頁）、同一個法術多格時的優先序、
-- 覆寫法術優先、物品掃格子、快取與清快取。
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
env.C_Timer = { After = function() end }

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

print(("Keybinds_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
