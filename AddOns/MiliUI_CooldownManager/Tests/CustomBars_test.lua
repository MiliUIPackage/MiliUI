------------------------------------------------------------
-- Modules/CustomBars.lua（自訂列）的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/CustomBars_test.lua
--
-- 覆蓋：
--   1. 預設值與面板登記（profile.custombars 錨在資源條上方、resources.customBars 空表、PANEL_KEYS／ConfigTable／
--      DefaultFor、成環判斷）
--   2. 清單：List／Add／Find／Remove（清空拿掉專精鍵）／Move（拖曳排序的插入語意）／NewEntry
--   3. 每一列的設定解成生效值（CB.Style：預設、夾範圍、壞資料、光環才有層數與出現／消失音效、冷卻才有冷卻好了）
--   4. 規劃（CB.Plan：壞資料、enabled = false、沒學會的冷卻法術不建、光環類不問學沒學）
--   5. 排版：PanelHeight（0 列收合）、RowOffsets、Grow（往上／往下長）、Geometry（圖示左右無、太窄）、NameWidth
--   6. 冷卻列的明文旗標：CooldownState（GCD、沒在冷卻、在冷卻、讀不到、秘密值）、ChargeState、CooldownAlpha
--   7. 光環類交給 AuraBar 的 spec（unit／filter、秒數位置與低秒變色、層數不給格式器、「只在生效時顯示」把
--      暗底、名字、圖示建進按鈕子樹）與簽章（影響外觀的設定一變就換容器、同設定同簽章）
--   8. 音效登記（CB.SoundWantsOf）
------------------------------------------------------------
local here = (arg and arg[0] or ""):match("^(.*)[/\\][^/\\]*$") or "."

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

------------------------------------------------------------
-- 環境
------------------------------------------------------------
local SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
local env = setmetatable({}, { __index = _G })
env._G = env
env.UnitName = function() return "米利" end
env.GetRealmName = function() return "世界之樹" end
env.InCombatLockdown = function() return false end
env.GetSpecialization = function() return 1 end
env.GetSpecializationInfo = function(i) return 60 + i end
env.UnitClass = function() return "聖騎士", "PALADIN", 2 end
env.GetLocale = function() return "zhTW" end
env.CreateFrame = function()
    local f = {}
    function f:RegisterEvent() end
    function f:UnregisterEvent() end
    function f:SetScript() end
    return f
end
env.Enum = { CompressionMethod = { Deflate = 1 }, StatusBarTimerDirection = { ElapsedTime = 0, RemainingTime = 1 } }

local ns = {
    playerClass = "PALADIN",
    L = setmetatable({}, { __index = function(_, k) return k end }),
    IsSecret = function(v) return v == SECRET end,
    RegisterCallback = function() end,
    Fire = function() end,
    Events = { Register = function() end, Unregister = function() end },
    ReportError = function(e) print("ReportError: " .. tostring(e)) end,
}

local function Load(rel)
    local path = here .. "/../" .. rel
    local chunk, err
    if setfenv then
        chunk, err = loadfile(path)
        if chunk then setfenv(chunk, env) end
    else
        chunk, err = loadfile(path, "t", env)
    end
    assert(chunk, err)
    chunk("MiliUI_CooldownManager", ns)
end

Load("Core/DB.lua")
Load("Modules/AuraBar.lua")
Load("Modules/CustomBars.lua")
local DB, AB, CB = ns.DB, ns.AuraBar, ns.CustomBars

------------------------------------------------------------
-- 1. 預設值與面板登記
------------------------------------------------------------
local p = DB.BuildDefaults().profile
ns.profile = p
local c = p.custombars
check("預設：有 profile.custombars", type(c) == "table")
check("預設：錨在資源條上方（BOTTOM → TOP）", type(c.anchor) == "table" and c.anchor.to == "resources"
    and c.anchor.point == "BOTTOM" and c.anchor.relPoint == "TOP" and c.anchor.x == 0 and c.anchor.y == 1)
check("預設：開、跟核心技能一起淡、自己的 pos、載入條件兩個都關", c.enabled == true and c.fadeWithEssential == true
    and type(c.pos) == "table" and c.pos.point == "CENTER"
    and c.loadConditions.hideMounted == false and c.loadConditions.onlyCombat == false)
check("預設：清單在資源條那張表、空的", type(p.resources.customBars) == "table" and next(p.resources.customBars) == nil)
check("面板登記", DB.IsPanel("custombars") and ns.PANEL_KEYS.custombars == true)
eq("ConfigTable 自訂列", DB.ConfigTable("custombars"), c)
local da = DB.DefaultFor("bar", "custombars", "anchor")
check("DefaultFor 自訂列：錨定預設是複本", type(da) == "table" and da.to == "resources" and da ~= c.anchor)
check("資源條 → 自訂列會成環", DB.AnchorWouldCycle("resources", "custombars"))
check("施法條 → 自訂列不會成環", not DB.AnchorWouldCycle("castbar", "custombars"))
do
    local at
    for i, k in ipairs(DB.PANEL_ORDER) do if k == "custombars" then at = i end end
    eq("面板順序：自訂列在自訂格子後面", DB.PANEL_ORDER[at - 1], "pips")
    eq("面板順序：自訂列在施法條前面", DB.PANEL_ORDER[at + 1], "castbar")
end

------------------------------------------------------------
-- 2. 清單
------------------------------------------------------------
local cfg = { }
eq("沒有清單：List 回 nil", CB.List(cfg, 65), nil)
eq("specID nil：List 回 nil", CB.List(cfg, nil, true), nil)
eq("Add 壞種類 → nil", CB.Add(cfg, 65, { kind = "charges", spellID = 1 }), nil)
eq("Add 沒法術 → nil", CB.Add(cfg, 65, { kind = "buff" }), nil)
eq("壞的 Add 不建表", cfg.customBars, nil)
eq("Add 第一筆", CB.Add(cfg, 65, CB.NewEntry("buff", 31884)), 1)
eq("Add 第二筆", CB.Add(cfg, 65, CB.NewEntry("cooldown", 642)), 2)
eq("Add 第三筆", CB.Add(cfg, 65, CB.NewEntry("debuff", 197277)), 3)
eq("Find 有", CB.Find(cfg, 65, "cooldown", 642), 2)
eq("Find 種類不同 ＝ 沒有", CB.Find(cfg, 65, "buff", 642), nil)
eq("Find 別的專精沒有", CB.Find(cfg, 66, "buff", 31884), nil)
eq("NewEntry 壞種類", CB.NewEntry("stacks", 1), nil)
check("NewEntry 預設開", CB.NewEntry("buff", 1).enabled == true)
local list = CB.List(cfg, 65)
check("Move：第 1 筆搬到最後", CB.Move(list, 1, 4) and list[1].spellID == 642 and list[3].spellID == 31884)
check("Move：放回原位不算", not CB.Move(list, 2, 2) and not CB.Move(list, 2, 3))
check("Move：最後一筆搬到最前", CB.Move(list, 3, 1) and list[1].spellID == 31884 and list[2].spellID == 642)
check("Move：壞參數", not CB.Move(list, 9, 1) and not CB.Move(nil, 1, 2))
check("Remove 中間", CB.Remove(cfg, 65, 2) and #CB.List(cfg, 65) == 2)
check("Remove 不存在", not CB.Remove(cfg, 65, 9) and not CB.Remove(cfg, 70, 1))
CB.Remove(cfg, 65, 1)
CB.Remove(cfg, 65, 1)
eq("刪光：專精鍵拿掉", cfg.customBars[65], nil)

------------------------------------------------------------
-- 3. 每一列的設定
------------------------------------------------------------
local s = CB.Style({ kind = "buff", spellID = 1 })
check("預設：光環類", s.aura and s.kind == "buff")
eq("預設高", s.height, CB.HEIGHT_DEFAULT)
check("預設：職業色、沒有自訂色", s.classColor == true and s.color == nil)
eq("預設圖示在左", s.icon, "left")
check("預設：名字顯示靠左", s.nameShow and s.namePoint == "LEFT")
check("預設：時間顯示靠右", s.timeShow and s.timePoint == "RIGHT")
eq("預設小數門檻", s.decimals, CB.DECIMALS_DEFAULT)
check("預設：層數顯示置中（光環類）", s.stacksShow and s.stacksPoint == "CENTER")
check("預設：低時間變色關、5 秒、紅", s.lowOn == false and s.lowBelow == 5 and s.lowColor.r == 1 and s.lowColor.g == 0.3)
check("預設：一直顯示、不反向", s.showWhen == "always" and s.reverse == false)
check("預設：文字大小照列高（高 − 4）", s.textSizeAuto and s.textSize == CB.HEIGHT_DEFAULT - 4)
check("預設：沒有音效", s.gainSound == nil and s.loseSound == nil and s.readySound == nil)

s = CB.Style({ kind = "cooldown", spellID = 1, height = 99, icon = "up", name = { show = false, point = "TOP" },
    time = { point = "CENTER", decimals = -3 }, stacks = { show = true }, low = { on = true, below = 500, color = { r = 0, g = 1 } },
    textSize = 2, showWhen = "nope", reverse = true, gainSound = "Ding", readySound = "Bell", classColor = false,
    color = { r = 2, g = 0.5, b = -1 } })
eq("高夾上限", s.height, CB.HEIGHT_MAX)
eq("圖示壞值 → 左", s.icon, "left")
check("名字關、壞位置 → 靠左", s.nameShow == false and s.namePoint == "LEFT")
eq("時間置中", s.timePoint, "CENTER")
eq("小數夾 0", s.decimals, 0)
check("冷卻類沒有層數", s.stacksShow == false)
check("低時間開、秒數夾上限、壞色退預設", s.lowOn and s.lowBelow == CB.LOW_MAX and s.lowColor.r == 1)
check("文字大小夾下限", not s.textSizeAuto and s.textSize == CB.TEXT_SIZE_MIN)
eq("顯示方式壞值 → 一直", s.showWhen, "always")
check("反向", s.reverse)
check("冷卻類：沒有出現音效、有冷卻好了", s.gainSound == nil and s.readySound == "Bell")
check("自訂色夾 0～1", not s.classColor and s.color.r == 1 and s.color.g == 0.5 and s.color.b == 0)
s = CB.Style({ kind = "debuff", spellID = 1, readySound = "Bell", loseSound = "Num", showWhen = "active", height = 1 })
check("光環類：沒有冷卻好了、有消失音效", s.readySound == nil and s.loseSound == "Num")
eq("生效時才顯示", s.showWhen, "active")
eq("高夾下限", s.height, CB.HEIGHT_MIN)
eq("低高度的自動字級最小 8", s.textSize, 8)
eq("空字串音效 ＝ 沒有", CB.Style({ kind = "buff", gainSound = "" }).gainSound, nil)
eq("壞資料不炸", CB.Style("x").kind, nil)

-- 填色
local r, g, b = CB.FillColor(CB.Style({ kind = "buff" }), 0.1, 0.2, 0.3)
check("職業色", r == 0.1 and g == 0.2 and b == 0.3)
r = CB.FillColor(CB.Style({ kind = "buff", classColor = false, color = { r = 0.9, g = 0.8, b = 0.7 } }), 0.1, 0.2, 0.3)
eq("自訂色", r, 0.9)
r = CB.FillColor(CB.Style({ kind = "buff", classColor = false }), 0.1, 0.2, 0.3)
eq("關了職業色卻沒存顏色 → 退回職業色", r, 0.1)

------------------------------------------------------------
-- 4. 規劃
------------------------------------------------------------
cfg = { customBars = { [65] = {
    { kind = "buff", spellID = 31884 },
    "壞掉的一筆",
    { kind = "cooldown", spellID = 642 },
    { kind = "cooldown", spellID = 999 },           -- 沒學會
    { kind = "debuff", spellID = 197277, enabled = false },
    { kind = "debuff", spellID = 1 },
    { kind = "charges", spellID = 5 },             -- 自訂格子的種類，不收
} } }
local asked = {}
local probe = { known = function(id) asked[id] = true; return id ~= 999 end }
local plans = CB.Plan(cfg, 65, probe)
eq("規劃：三列", #plans, 3)
check("規劃：順序照清單、index 是清單位置", plans[1].index == 1 and plans[2].index == 3 and plans[3].index == 6)
check("規劃：光環旗標", plans[1].aura and not plans[2].aura and plans[3].aura)
check("規劃：只問冷卻法術學沒學", asked[642] and asked[999] and not asked[31884] and not asked[1])
eq("規劃：沒有清單 → 空", #CB.Plan(cfg, 66, probe), 0)
eq("規劃：沒給 probe 一律建", #CB.Plan(cfg, 65), 4)

------------------------------------------------------------
-- 5. 排版
------------------------------------------------------------
eq("沒有列 → 高 0（收合）", CB.PanelHeight({}, 1), 0)
eq("一列", CB.PanelHeight({ 16 }, 1), 16)
eq("三列＋兩個列距", CB.PanelHeight({ 16, 10, 20 }, 2), 50)
eq("列距 -1（共用邊）", CB.PanelHeight({ 10, 10 }, -1), 19)
local off = CB.RowOffsets({ 16, 10, 20 }, 2)
check("RowOffsets", off[1] == 0 and off[2] == 18 and off[3] == 30)
eq("Grow：沒錨定往上", CB.Grow(false), "up")
eq("Grow：錨在上方往上", CB.Grow({ point = "BOTTOM", relPoint = "TOP" }), "up")
eq("Grow：錨在下方往下", CB.Grow({ point = "TOP", relPoint = "BOTTOM" }), "down")
eq("Grow：TOPLEFT→BOTTOMLEFT 也算下方", CB.Grow({ point = "TOPLEFT", relPoint = "BOTTOMLEFT" }), "down")
eq("Grow：置中對置中往上", CB.Grow({ point = "CENTER", relPoint = "CENTER" }), "up")

local geo = CB.Geometry(200, 16, "left", 1)
check("圖示在左：圖示 0..16、條從 17 起、寬 183", geo.iconX == 0 and geo.iconW == 16 and geo.barX == 17 and geo.barW == 183)
geo = CB.Geometry(200, 16, "right", 1)
check("圖示在右：條從 0 起、寬 183、圖示在 184", geo.barX == 0 and geo.barW == 183 and geo.iconX == 184 and geo.iconW == 16)
geo = CB.Geometry(200, 16, "none", 1)
check("沒有圖示：條滿版", geo.barX == 0 and geo.barW == 200 and geo.iconW == 0)
geo = CB.Geometry(10, 16, "left", 1)
eq("太窄：條至少 1", geo.barW, 1)

local st = CB.Style({ kind = "buff" })
eq("名字寬：時間在另一邊 ⇒ 讓出", CB.NameWidth(st, 106, 3), 100 * 0.62)
st = CB.Style({ kind = "cooldown", time = { show = false } })
eq("名字寬：另一邊沒東西 ⇒ 整條", CB.NameWidth(st, 106, 3), 100)
eq("名字寬：至少 1", CB.NameWidth(st, 2, 3), 1)

------------------------------------------------------------
-- 6. 冷卻列的明文旗標
------------------------------------------------------------
local isSecret = ns.IsSecret
eq("只是 GCD ⇒ idle（條不閃）", CB.CooldownState({ isOnGCD = true, isActive = true }, isSecret), "idle")
eq("沒在冷卻 ⇒ idle", CB.CooldownState({ isOnGCD = false, isActive = false }, isSecret), "idle")
eq("真的在冷卻 ⇒ active", CB.CooldownState({ isOnGCD = false, isActive = true }, isSecret), "active")
eq("旗標讀不到 ⇒ nil", CB.CooldownState({}, isSecret), nil)
eq("秘密值 ⇒ nil（不測秘密布林）", CB.CooldownState({ isOnGCD = SECRET, isActive = true }, isSecret), nil)
eq("不是表 ⇒ nil", CB.CooldownState(nil, isSecret), nil)
eq("充能：回充中", CB.ChargeState({ isActive = true }, isSecret), "active")
eq("充能：滿了", CB.ChargeState({ isActive = false }, isSecret), "idle")
eq("充能：秘密", CB.ChargeState({ isActive = SECRET }, isSecret), nil)
eq("一直顯示 ⇒ 1", CB.CooldownAlpha("always", "idle"), 1)
eq("生效時：在冷卻 ⇒ 1", CB.CooldownAlpha("active", "active"), 1)
eq("生效時：沒在冷卻 ⇒ 0", CB.CooldownAlpha("active", "idle"), 0)
eq("生效時：讀不到 ⇒ 交引擎（nil）", CB.CooldownAlpha("active", nil), nil)

------------------------------------------------------------
-- 7. 光環類的 spec 與簽章
------------------------------------------------------------
local look = { r = 1, g = 0.5, b = 0.2, alpha = 1, texture = "tex", bgTex = "bg", dim = { 0.1, 0.1, 0.1, 0.8 }, px = 1,
               edge = { 0, 0, 0, 1 }, font = "font.ttf", outline = "OUTLINE", sizePx = 12, padPx = 3, offY = 0,
               name = "復仇之怒", iconFile = 135875, nameWpx = 100 }
local function Plan1(entry) return CB.Plan({ customBars = { [1] = { entry } } }, 1)[1] end
local G = CB.Geometry(200, 16, "left", 1)
local buff = CB.AuraSpec(Plan1({ kind = "buff", spellID = 31884 }), look, G)
check("增益：player／HELPFUL／duration", buff.unit == "player" and buff.filter == "HELPFUL" and buff.kind == "duration"
    and buff.spellIDs[1] == 31884)
check("秒數：靠右、小數門檻、沒有低秒變色", buff.text and buff.text.point == "RIGHT" and buff.text.decimals == CB.DECIMALS_DEFAULT
    and buff.text.low == nil)
check("層數：置中、不給格式器", buff.count and buff.count.point == "CENTER" and buff.count.plain == true and buff.count.mode == "stacks")
check("一直顯示：沒有 inside、沒有 label（列上畫）", buff.inside == nil and buff.label == nil)
local debuff = CB.AuraSpec(Plan1({ kind = "debuff", spellID = 1, low = { on = true, below = 4, color = { r = 0, g = 1, b = 0 } },
    stacks = { show = false }, time = { show = true, point = "LEFT" }, showWhen = "active", icon = "right" }), look, G)
check("目標減益：target／HARMFUL|PLAYER", debuff.unit == "target" and debuff.filter == "HARMFUL|PLAYER")
check("低秒變色：門檻與顏色", debuff.text.low and debuff.text.low.below == 4 and debuff.text.low.g == 1)
eq("秒數靠左", debuff.text.point, "LEFT")
eq("層數關掉：沒有 count", debuff.count, nil)
check("只在生效時顯示：暗底建在按鈕裡、寬是條身", debuff.inside and debuff.inside.W == G.barW and debuff.inside.segments == false)
check("只在生效時顯示：名字與圖示也在按鈕裡", debuff.label and debuff.label.name == "復仇之怒" and debuff.label.icon == 135875
    and debuff.label.side == "right" and debuff.label.isize == G.H)
local noLabel = CB.AuraSpec(Plan1({ kind = "buff", spellID = 2, showWhen = "active", icon = "none", name = { show = false } }), look, G)
check("只在生效時顯示、沒名字沒圖示：不帶 label", noLabel.inside and noLabel.label == nil)
local timeOff = CB.AuraSpec(Plan1({ kind = "buff", spellID = 2, time = { show = false } }), look, G)
eq("時間關掉：沒有 text", timeOff.text, nil)

-- 簽章：影響外觀的設定一變就換容器；同設定同簽章
local function Sig(entry) return AB.Signature(CB.AuraSpec(Plan1(entry), look, G)) end
local base = { kind = "buff", spellID = 31884 }
eq("同設定同簽章", Sig(base), Sig({ kind = "buff", spellID = 31884 }))
check("秒數位置進簽章", Sig(base) ~= Sig({ kind = "buff", spellID = 31884, time = { point = "LEFT" } }))
check("小數門檻進簽章", Sig(base) ~= Sig({ kind = "buff", spellID = 31884, time = { decimals = 5 } }))
check("低秒變色進簽章", Sig(base) ~= Sig({ kind = "buff", spellID = 31884, low = { on = true } }))
check("低秒顏色進簽章", Sig({ kind = "buff", spellID = 31884, low = { on = true } })
    ~= Sig({ kind = "buff", spellID = 31884, low = { on = true, color = { r = 0, g = 0, b = 1 } } }))
check("層數位置進簽章", Sig(base) ~= Sig({ kind = "buff", spellID = 31884, stacks = { point = "LEFT" } }))
check("顯示方式進簽章", Sig(base) ~= Sig({ kind = "buff", spellID = 31884, showWhen = "active" }))
check("反向進簽章", Sig(base) ~= Sig({ kind = "buff", spellID = 31884, reverse = true }))
check("種類（unit／filter）進簽章", Sig(base) ~= Sig({ kind = "debuff", spellID = 31884 }))
check("生效時才顯示：名字位置進簽章", Sig({ kind = "buff", spellID = 1, showWhen = "active" })
    ~= Sig({ kind = "buff", spellID = 1, showWhen = "active", name = { point = "CENTER" } }))
check("生效時才顯示：圖示邊進簽章", Sig({ kind = "buff", spellID = 1, showWhen = "active" })
    ~= Sig({ kind = "buff", spellID = 1, showWhen = "active", icon = "right" }))
-- 舊的呼叫端（資源條的 auraTimer）沒帶新欄位：簽章一個字都不變
do
    local old = { kind = "duration", spellIDs = { 395296 }, max = 1, texture = "t", color = { r = 1, g = 1, b = 1 }, alpha = 1,
                  text = { font = "f", size = 10, outline = "OUTLINE", decimals = 5 } }
    local sig = AB.Signature(old)
    check("舊呼叫端：簽章沒有新段落", not sig:find("tp:") and not sig:find("low:") and not sig:find("lbl:") and not sig:find("cp:"))
end
check("LowCurve：門檻 0 ⇒ 不建", AB.LowCurve(0, 1, 0, 0) == nil)
eq("PadX", AB.PadX("LEFT", 3) .. "," .. AB.PadX("RIGHT", 3) .. "," .. AB.PadX("CENTER", 3), "3,-3,0")

------------------------------------------------------------
-- 8. 音效登記
------------------------------------------------------------
local wants = CB.SoundWantsOf(CB.Plan({ customBars = { [1] = {
    { kind = "buff", spellID = 10, gainSound = "Ding", loseSound = "Num" },
    { kind = "debuff", spellID = 20, gainSound = "Bell" },
    { kind = "cooldown", spellID = 30, readySound = "Bell", gainSound = "Ding" },
} } }, 1))
eq("音效：三筆（冷卻列不經 AddAuraSound）", #wants, 3)
check("音效：增益出現／消失 unit player", wants[1].what == "gain" and wants[1].unit == "player" and wants[1].spellID == 10
    and wants[2].what == "lose" and wants[2].name == "Num")
check("音效：目標減益 unit target", wants[3].unit == "target" and wants[3].spellID == 20 and wants[3].name == "Bell")
eq("音效：沒有規劃 ⇒ 空", #CB.SoundWantsOf(nil), 0)

print(("CustomBars_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
