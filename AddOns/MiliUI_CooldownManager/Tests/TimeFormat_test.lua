------------------------------------------------------------
-- Core/Text.lua 倒數時間格式的離線自我測試（不進 TOC，遊戲不會載入）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/TimeFormat_test.lua
--
-- 規則格式器是 C 端的，這裡照暴雪 API 文件（NumericRuleFormatterSharedDocumentation）的語意寫一顆假的
-- 來「印」：挑門檻 ≤ x 的最後一段 → 規則層照 step／rounding 取 → min／max → 每個 component 先 div、
-- 再 mod、再照它自己的 step／rounding 取 → 套 format（%d 截掉小數，同 C 端轉整數）。
-- 文件沒講 div 的商是整數還是帶小數 ⇒ 兩種解讀各跑一次，結果要一樣。
--
-- 覆蓋：分鐘格式（1:59 要印 2m、不是 1m：2026-10-21 玩家回報；90 秒起印秒數、升位那一秒不閃 91；
-- 5401 起印時）、分:秒格式（2:00 以內 1:59、1:00、59；2:01 起回到分鐘格式 3m、時：2026-10-21 玩家回報）、
-- 有小數段時整數段往下取的升位點、
-- 低秒變色只包秒數段、快取依時間格式分開、TimeFormat 逐格退主題（條自己的倒數表只存了幾格）。
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

local RD = { Nearest = 0, Up = 1, Down = 2 }
local made = 0
local env = setmetatable({}, { __index = _G })
env.Enum = { NumericRuleFormatRounding = RD }
env.C_StringUtil = { CreateNumericRuleFormatter = function()
    made = made + 1
    local f = { rules = {} }
    function f.AddBreakpoint(self, rule) self.rules[#self.rules + 1] = rule end
    return f
end }

local profile
local ns = {}
function ns.Setting(barKey, path)
    local function Dig(t)
        for seg in path:gmatch("[^%.]+") do
            if type(t) ~= "table" then return nil end
            t = t[seg]
        end
        return t
    end
    if barKey and barKey ~= "theme" then
        local bar = profile.bars[barKey]
        if bar and bar.follow and bar.follow.text == false then
            local v = Dig(bar.text)
            if v ~= nil then return v end
        end
    end
    return Dig(profile.theme)
end

local function Load(path)
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

Load(here .. "/../Core/Text.lua")
local T = ns.Text

------------------------------------------------------------
-- 假的規則格式器求值
------------------------------------------------------------
local intQuotient = false        -- div 的商：false ＝ 帶小數，true ＝ 取整數（兩種解讀都要對）

local function Round(v, step, mode)
    if not step then return v end
    local q = v / step
    if mode == RD.Up then q = math.ceil(q - 1e-9)
    elseif mode == RD.Down then q = math.floor(q + 1e-9)
    else q = math.floor(q + 0.5) end
    return q * step
end

local function Print(fmt, x)
    local rule
    for i, r in ipairs(fmt.rules) do
        if i > 1 then assert(r.threshold > fmt.rules[i - 1].threshold, "門檻要遞增") end
        if x >= r.threshold then rule = r end
    end
    if not rule then return nil end
    local v = Round(x, rule.step, rule.rounding)
    if rule.min and v < rule.min then v = rule.min end
    if rule.max and v > rule.max then v = rule.max end
    local vals = {}
    if rule.components then
        for _, c in ipairs(rule.components) do
            local cv = v
            if c.div then
                cv = cv / c.div
                if intQuotient then cv = math.floor(cv + 1e-9) end
            end
            if c.mod then cv = cv % c.mod end
            vals[#vals + 1] = Round(cv, c.step, c.rounding)
        end
    else
        vals[1] = v
    end
    local args, i = {}, 0
    for spec in rule.format:gmatch("%%[%d%.]*[df]") do
        i = i + 1
        local a = vals[i]
        if spec:sub(-1) == "d" then a = math.floor(a + 1e-9) end
        args[i] = a
    end
    return rule.format:format(table.unpack(args, 1, i))
end

local function Expect(label, fmt, cases)
    for _, iq in ipairs({ false, true }) do
        intQuotient = iq
        for _, c in ipairs(cases) do
            eq(("%s：%s 秒（商%s）"):format(label, tostring(c[1]), iq and "取整" or "帶小數"), Print(fmt, c[1]), c[2])
        end
    end
    intQuotient = false
end

------------------------------------------------------------
-- 1. 分鐘格式
------------------------------------------------------------
local fMin = T.CountdownFormatter({ decimalsBelow = 0, lowColorOn = false }, "minutes")
check("分鐘格式建得起來", fMin ~= nil)
Expect("分鐘", fMin, {
    { 0.3, "1" }, { 5, "5" }, { 59.2, "60" }, { 60, "60" }, { 89.2, "90" }, { 90, "90" },
    { 90.5, "2m" },                -- 往上取時 (90, 91) 顯示的是 91 ⇒ 已經算分鐘段，不閃 91
    { 91, "2m" }, { 119, "2m" }, { 119.5, "2m" }, { 120, "2m" },   -- 1:59 印 2m（以前截成 1m）
    { 120.2, "3m" }, { 180, "3m" }, { 3600, "60m" }, { 5400, "90m" },
    { 5400.5, "2h" }, { 7200, "2h" }, { 7200.5, "3h" },
})

-- 有小數段：整數段往下取 ⇒ 改印分的點照字面（91）；改印時看分鐘數（原始秒數進位）會不會超過 90，不印 91m
local fMinDec = T.CountdownFormatter({ decimalsBelow = 3, lowColorOn = false }, "minutes")
Expect("分鐘＋小數", fMinDec, {
    { 2.55, "2.5" }, { 3.2, "3" }, { 59.9, "59" }, { 90.9, "90" }, { 91, "2m" }, { 119.9, "2m" },
    { 5400, "90m" }, { 5400.9, "2h" },
})

------------------------------------------------------------
-- 2. 分:秒（預設，DB v13 起）
------------------------------------------------------------
local fMs = T.CountdownFormatter({ decimalsBelow = 0, lowColorOn = false }, "mmss")
check("分:秒建得起來", fMs ~= nil and fMs ~= fMin)
Expect("分:秒", fMs, {
    { 0.3, "1" }, { 58.5, "59" }, { 59, "59" },
    { 59.5, "1:00" },              -- 往上取時 (59, 60) 顯示的是 60 ⇒ 已經是 1:00，不閃 60
    { 60, "1:00" }, { 61.2, "1:02" }, { 90, "1:30" }, { 119, "1:59" }, { 119.5, "2:00" }, { 120, "2:00" },
    { 120.5, "3m" },               -- 往上取時 (120, 121) 顯示的是 2:01 ⇒ 已經回到分鐘格式，不閃 2:01
    { 121, "3m" }, { 180, "3m" }, { 180.5, "4m" }, { 600, "10m" }, { 3599, "60m" }, { 5400, "90m" },
    { 5400.5, "2h" }, { 7200.5, "3h" },
})

local fMsDec = T.CountdownFormatter({ decimalsBelow = 3, lowColorOn = false }, "mmss")
Expect("分:秒＋小數", fMsDec, {
    { 2.55, "2.5" }, { 3.2, "3" }, { 59.9, "59" }, { 60, "1:00" }, { 60.9, "1:00" }, { 119.9, "1:59" },
    { 120, "2:00" }, { 120.9, "2:00" }, { 121, "3m" }, { 5400, "90m" }, { 5400.9, "2h" },
})

-- 表上的 timeFormat（沒另外給時讀它）
eq("沒給第二個參數 ⇒ 讀表上的", T.CountdownFormatter({ decimalsBelow = 0, lowColorOn = false, timeFormat = "mmss" }), fMs)
eq("第二個參數蓋過表上的", T.CountdownFormatter({ decimalsBelow = 0, lowColorOn = false, timeFormat = "mmss" }, "minutes"), fMin)
eq("不認得的值 ⇒ 預設分:秒", T.CountdownFormatter({ decimalsBelow = 0, lowColorOn = false }, "hhmmss"), fMs)
eq("表上跟參數都沒有 ⇒ 預設分:秒", T.CountdownFormatter({ decimalsBelow = 0, lowColorOn = false }), fMs)

------------------------------------------------------------
-- 3. 低秒變色只包秒數段
------------------------------------------------------------
local fLow = T.CountdownFormatter({ decimalsBelow = 0, lowColorOn = true, lowBelow = 5, lowColor = { r = 1, g = 0, b = 0 } }, "mmss")
Expect("分:秒＋低秒變色", fLow, {
    { 4.2, "|cffff00005|r" }, { 5, "5" }, { 59, "59" }, { 60, "1:00" }, { 150, "3m" },
})

------------------------------------------------------------
-- 4. 增益持續時間、不帶色碼的版本
------------------------------------------------------------
local fBuff = T.BuffFormatter({ buffDecimalsBelow = 0, buffLowColor = false }, nil, "mmss")
eq("增益：同值共用冷卻那一顆", fBuff, fMs)
Expect("增益（分:秒）", fBuff, { { 119, "1:59" }, { 45, "45" }, { 150, "3m" } })
local pMin, pMs = T.PlainFormatter(0), T.PlainFormatter(0, "mmss")
check("不帶色碼：兩種格式各一顆", pMin and pMs and pMin ~= pMs)
Expect("不帶色碼（沒給格式 ⇒ 分鐘：長條、層數列）", pMin, { { 119, "2m" } })
eq("不帶色碼：明給分鐘跟沒給同一顆", T.PlainFormatter(0, "minutes"), pMin)
eq("不帶色碼：壞值 ⇒ 預設分:秒", T.PlainFormatter(0, "hhmmss"), pMs)
Expect("不帶色碼（分:秒）", pMs, { { 119, "1:59" }, { 150, "3m" } })
local n0 = made
T.PlainFormatter(0, "mmss")
T.CountdownFormatter({ decimalsBelow = 0, lowColorOn = false }, "mmss")
eq("快取：同值不重建", made, n0)

------------------------------------------------------------
-- 5. 這一條生效的時間格式：逐格退主題
------------------------------------------------------------
profile = {
    theme = { cooldownText = { size = 16, timeFormat = "mmss" } },
    bars = {
        follow  = { follow = { text = true }, text = { cooldownText = { timeFormat = "minutes" } } },
        partial = { follow = { text = false }, text = { cooldownText = { size = 20 } } },   -- 條自己只存了字級
        own     = { follow = { text = false }, text = { cooldownText = { timeFormat = "minutes" } } },
    },
}
eq("主題", T.TimeFormat("theme"), "mmss")
eq("跟隨主題的條（自己存的不算）", T.TimeFormat("follow"), "mmss")
eq("條自己只存了幾格 ⇒ 時間格式退主題", T.TimeFormat("partial"), "mmss")
eq("條自己存了", T.TimeFormat("own"), "minutes")
profile.theme.cooldownText.timeFormat = nil
eq("沒有這欄 ⇒ 預設分:秒", T.TimeFormat("theme"), "mmss")
eq("TimeFormatOf：壞值 ⇒ 預設分:秒", T.TimeFormatOf(42), "mmss")

print(("TimeFormat_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
