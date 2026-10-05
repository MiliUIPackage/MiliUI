------------------------------------------------------------
-- 噬滅的虛空化身計時＋崩陷之星計數（Modules/DevourerMeta.lua；不進 TOC）
--
--   lua  AddOns/MiliUI_CooldownManager/Tests/DevourerMeta_test.lua
--
-- 覆蓋：
--   1. FormatElapsed：0、59、60、61、600、負數、小數 × 兩種格式
--   2. Transition：進入歸零記起點、持續不動、離開（hold 開／關、兩段各自）、hold 過期、reload 已在化身中、NeedsTick
--   3. 崩陷之星：化身外不計、化身中 +1、秘密 spellID 略過、別的 spellID 不計、進化身歸零、參數形狀
--   4. MatchRule：六種比較、第一條成立優先、空表、壞規則當不成立、超過 6 條的不看
--   5. 規則音效的邊緣（RuleEdge ＋ 實際 Paint）：同一條持續成立不重響、換到另一條響新的、離開再回來再響、
--      hold 期間不響、預覽不響、整數秒沒變不重畫
--   6. CleanRules：截 6 條、丟壞資料、保留順序、原表不動
--   7. 位置：兩段同一邊時的並排順序、不同邊各自錨、計時關掉時星回到列邊；Layout 的位移換算
--   8. 設定讀取的預設值與驗證；跟隨列數字的字型／字級／描邊
--   9. 資源條接線：WantedEvents 只在有噬靈魂碎片列時要施法事件（非 1480 不註冊）、R.CleanMetaRules 轉手
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
local now = 100
local auras = {}
local env = setmetatable({}, { __index = _G })
env._G = env
env.GetTime = function() return now end
env.C_UnitAuras = { GetPlayerAuraBySpellID = function(id) return auras[id] end }
env.C_Spell = {
    GetSpellName = function(id) return "S" .. id end,
    GetSpellTexture = function() return 12345 end,
    GetSpellCastCount = function() return 0 end,
}
env.UIParent = { GetEffectiveScale = function() return 0.5 end }
env.InCombatLockdown = function() return false end
env.UnitPower = function() return 0 end
env.UnitPowerMax = function() return 0 end
env.CreateFrame = function()
    local f = {}
    function f:RegisterEvent() end
    function f:RegisterUnitEvent() end
    function f:UnregisterEvent() end
    function f:SetScript() end
    return f
end
env.Enum = { PowerType = { Mana = 0, Rage = 1, Focus = 2, Energy = 3, ComboPoints = 4, Runes = 5, RunicPower = 6,
                           SoulShards = 7, LunarPower = 8, HolyPower = 9, Maelstrom = 11, Chi = 12, Insanity = 13,
                           ArcaneCharges = 16, Fury = 17, Essence = 19 } }

local played = {}
local editing = false
local resCfg = {}
local ns = {
    playerClass = "DEMONHUNTER",
    L = setmetatable({}, { __index = function(_, k) return k end }),
    IsSecret = function(v) return v == SECRET end,
    Setting = function() return "GENERAL" end,
    RegisterCallback = function() end,
    ReportError = function(e) print("ReportError: " .. tostring(e)) end,
}
ns.Media = {
    INHERIT = "INHERIT",
    OUTLINES = { [""] = true, OUTLINE = true, THICKOUTLINE = true },
    ElementFont = function(own, general)
        if type(own) == "string" and own ~= "" and own ~= "INHERIT" then return own end
        return general
    end,
    SetPixelFont = function(fs, size, flags, token) fs.font = { size = size, flags = flags, token = token } end,
}
ns.Sound = { PlayNamed = function(name, key) played[#played + 1] = name .. "@" .. key; return true end }
ns.EditMode = { Editing = function() return editing end }

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

Load("Modules/ResourceConditions.lua")
Load("Modules/DevourerMeta.lua")
local DM = ns.DevourerMeta
local isSecret = ns.IsSecret

-- 資源條的替身（DevourerMeta 執行期只用這幾支）；第 9 節換成真的 Modules/Resources.lua
local armed = 0
ns.Resources = {
    Cfg = function() return resCfg end,
    ArmTicker = function() armed = armed + 1 end,
    TextOutline = function(rowCfg) return (type(rowCfg) == "table" and rowCfg.rowOutline) or "THEME" end,
    StyleFor = function(cfg) return cfg end,
}

------------------------------------------------------------
-- 1. FormatElapsed
------------------------------------------------------------
eq("mss 0", DM.FormatElapsed(0, "mss"), "0:00")
eq("mss 59", DM.FormatElapsed(59, "mss"), "0:59")
eq("mss 60", DM.FormatElapsed(60, "mss"), "1:00")
eq("mss 61", DM.FormatElapsed(61, "mss"), "1:01")
eq("mss 600", DM.FormatElapsed(600, "mss"), "10:00")
eq("mss 負數夾 0", DM.FormatElapsed(-5, "mss"), "0:00")
eq("mss 小數捨去", DM.FormatElapsed(23.9, "mss"), "0:23")
eq("沒給格式 ＝ mss", DM.FormatElapsed(23), "0:23")
eq("sec 0", DM.FormatElapsed(0, "sec"), "0")
eq("sec 59", DM.FormatElapsed(59, "sec"), "59")
eq("sec 60", DM.FormatElapsed(60, "sec"), "60")
eq("sec 61", DM.FormatElapsed(61, "sec"), "61")
eq("sec 600", DM.FormatElapsed(600, "sec"), "600")
eq("sec 負數夾 0", DM.FormatElapsed(-1, "sec"), "0")

------------------------------------------------------------
-- 2. Transition
------------------------------------------------------------
do
    local s = DM.NewState()
    eq("一開始不在化身", s.inMeta, false)
    eq("一開始不跑 ticker", DM.NeedsTick(s), false)
    eq("沒變 ⇒ nil", DM.Transition(s, false, 10), nil)
    s.stars = 7
    s.lastRule.time, s.lastRule.stars = 2, 1
    eq("進入", DM.Transition(s, true, 10), "enter")
    eq("進入記起點", s.since, 10)
    eq("進入歸零星數", s.stars, 0)
    eq("進入清規則狀態（計時）", s.lastRule.time, nil)
    eq("進入清規則狀態（星）", s.lastRule.stars, nil)
    eq("化身中跑 ticker", DM.NeedsTick(s), true)
    eq("持續不動", DM.Transition(s, true, 15), nil)
    eq("持續中起點不變", s.since, 10)
    local m, v = DM.Value(s, "time", 33.7)
    eq("化身中計時 mode", m, "live")
    eq("化身中計時值（整數秒）", v, 23)
    s.stars = 4
    -- 離開：計時沒開 hold、星開 3 秒
    eq("離開", DM.Transition(s, false, 40, nil, 3), "exit")
    eq("離開清起點", s.since, nil)
    eq("離開記最後秒數", s.endSec, 30)
    eq("計時沒開 hold", s.hold.time, nil)
    eq("星 hold 到 43", s.hold.stars, 43)
    eq("離開後計時不顯示", (DM.Value(s, "time", 41)), nil)
    m, v = DM.Value(s, "stars", 41)
    eq("保留中星 mode", m, "hold")
    eq("保留中星值", v, 4)
    eq("保留中還要 ticker", DM.NeedsTick(s), true)
    eq("沒過期不清", DM.Expire(s, 42.9), false)
    eq("過期清掉", DM.Expire(s, 43), true)
    eq("過期後星不顯示", (DM.Value(s, "stars", 43)), nil)
    eq("過期清完不要 ticker", DM.NeedsTick(s), false)

    -- 兩段都開 hold、各自秒數
    DM.Transition(s, true, 100)
    DM.Transition(s, false, 130, 5, 2)
    eq("兩段各自 hold（計時）", s.hold.time, 135)
    eq("兩段各自 hold（星）", s.hold.stars, 132)
    DM.Expire(s, 133)
    eq("星先過期", s.hold.stars, nil)
    eq("計時還在保留", s.hold.time, 135)
    m, v = DM.Value(s, "time", 133)
    eq("保留中計時停在最後的值", v, 30)
    -- 保留中又進化身：保留清掉、重新數
    DM.Transition(s, true, 134)
    eq("再進化身清保留", s.hold.time, nil)
    eq("再進化身重記起點", s.since, 134)

    -- reload 時已在化身中：新狀態 ＋ 第一次看到 inMeta ＝ 從現在起算
    local r = DM.NewState()
    eq("reload 已在化身中 ⇒ enter", DM.Transition(r, true, 500), "enter")
    eq("reload 從現在起算", (select(2, DM.Value(r, "time", 500))), 0)

    -- ResetState：整個重設（debug 計數留著）
    r.counted, r.skipped, r.stars = 3, 2, 3
    DM.ResetState(r)
    eq("重設離開化身", r.inMeta, false)
    eq("重設星數", r.stars, 0)
    eq("重設不動 debug 計數", r.counted, 3)
end

------------------------------------------------------------
-- 3. 崩陷之星
------------------------------------------------------------
do
    local s = DM.NewState()
    eq("化身外不計", DM.CountCast(s, DM.STAR_SPELL, isSecret), false)
    eq("化身外星數 0", s.stars, 0)
    DM.Transition(s, true, 1)
    eq("化身中 +1", DM.CountCast(s, DM.STAR_SPELL, isSecret), true)
    eq("化身中星數 1", s.stars, 1)
    eq("別的法術不計", DM.CountCast(s, 12345, isSecret), false)
    eq("秘密略過", DM.CountCast(s, SECRET, isSecret), false)
    eq("秘密記一次略過", s.skipped, 1)
    eq("秘密不加星", s.stars, 1)
    eq("nil 不計", DM.CountCast(s, nil, isSecret), false)
    DM.CountCast(s, DM.STAR_SPELL, isSecret)
    eq("兩顆", s.stars, 2)
    eq("debug 計數", s.counted, 2)
    DM.Transition(s, false, 5)
    DM.Transition(s, true, 6)
    eq("進化身歸零", s.stars, 0)
    -- 參數形狀：(unit, castGUID, spellID)／(unit, spellID)
    eq("三個參數取第三個", DM.CastSpellID("Cast-3-xxx", 1221150), 1221150)
    eq("第二個是數字就用它", DM.CastSpellID(1221150, nil), 1221150)
    eq("秘密 spellID 原樣交回（再由 CountCast 略過）", DM.CastSpellID("guid", SECRET), SECRET)
end

-- 執行期的施法事件：化身的 UNIT_AURA 還沒處理就施法 ⇒ 先對齊狀態再數；秘密 spellID 不讀光環
do
    DM.Reset()
    auras = { [DM.META_AURA] = {} }
    now = 200
    eq("事件：化身中的崩陷之星", DM.OnSpellcast("player", "guid", DM.STAR_SPELL), true)
    eq("事件：對齊後進了化身", DM.state.inMeta, true)
    eq("事件：起點是現在", DM.state.since, 200)
    eq("事件：星數 1", DM.state.stars, 1)
    eq("事件：別的法術", DM.OnSpellcast("player", "guid", 99), false)
    local sk = DM.state.skipped
    eq("事件：秘密略過", DM.OnSpellcast("player", "guid", SECRET), false)
    eq("事件：秘密記一次", DM.state.skipped, sk + 1)
    auras = {}
    eq("事件：化身結束後施法不計", DM.OnSpellcast("player", DM.STAR_SPELL), false)
    eq("事件：對齊後離開化身", DM.state.inMeta, false)
    DM.Reset()
end

------------------------------------------------------------
-- 4. MatchRule
------------------------------------------------------------
do
    local function one(cmp, v, x) return DM.MatchRule({ { cmp = cmp, value = v } }, x) end
    eq(">= 成立", one(">=", 5, 5), 1)
    eq(">= 不成立", one(">=", 5, 4), nil)
    eq("> 成立", one(">", 5, 6), 1)
    eq("> 不成立", one(">", 5, 5), nil)
    eq("<= 成立", one("<=", 5, 5), 1)
    eq("<= 不成立", one("<=", 5, 6), nil)
    eq("< 成立", one("<", 5, 4), 1)
    eq("< 不成立", one("<", 5, 5), nil)
    eq("== 成立", one("==", 5, 5), 1)
    eq("== 不成立", one("==", 5, 6), nil)
    eq("~= 成立", one("~=", 5, 6), 1)
    eq("~= 不成立", one("~=", 5, 5), nil)
    local rules = { { cmp = ">=", value = 60 }, { cmp = ">=", value = 30 } }
    eq("第一條成立優先", DM.MatchRule(rules, 70), 1)
    eq("第二條", DM.MatchRule(rules, 45), 2)
    eq("都不成立", DM.MatchRule(rules, 10), nil)
    eq("空表", DM.MatchRule({}, 10), nil)
    eq("nil 表", DM.MatchRule(nil, 10), nil)
    eq("值不是數字", DM.MatchRule(rules, "10"), nil)
    eq("cmp 不在白名單當不成立", DM.MatchRule({ { cmp = "=>", value = 1 }, { cmp = ">=", value = 1 } }, 5), 2)
    eq("value 不是數字當不成立", DM.MatchRule({ { cmp = ">=", value = "1" }, { cmp = ">=", value = 1 } }, 5), 2)
    eq("壞列不是表", DM.MatchRule({ "x", { cmp = ">=", value = 0 } }, 5), 2)
    local many = {}
    for i = 1, 7 do many[i] = { cmp = "==", value = i } end
    eq("第 6 條還看", DM.MatchRule(many, 6), 6)
    eq("第 7 條不看", DM.MatchRule(many, 7), nil)
end

------------------------------------------------------------
-- 5. 規則音效的邊緣
------------------------------------------------------------
do
    local s = DM.NewState()
    eq("nil → 1 響", DM.RuleEdge(s, "time", 1), true)
    eq("1 持續不重響", DM.RuleEdge(s, "time", 1), false)
    eq("換到 2 響", DM.RuleEdge(s, "time", 2), true)
    eq("離開（nil）不響", DM.RuleEdge(s, "time", nil), false)
    eq("再回來響", DM.RuleEdge(s, "time", 2), true)
    eq("兩段各自（星）", DM.RuleEdge(s, "stars", 2), true)
end

-- 假的列與 FontString：實際跑 Layout ＋ Paint
local function FakeFS()
    local fs = { text = "", shown = true, points = {} }
    function fs:SetText(t) self.text = t; self.sets = (self.sets or 0) + 1 end
    function fs:SetTextColor(r, g, b, a) self.color = { r, g, b, a } end
    function fs:SetDrawLayer() end
    function fs:SetJustifyH(j) self.justify = j end
    function fs:ClearAllPoints() self.points = {} end
    function fs:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function fs:SetShown(v) self.shown = v and true or false end
    function fs:Show() self.shown = true end
    function fs:Hide() self.shown = false end
    function fs:IsShown() return self.shown end
    return fs
end
local function FakeRow()
    local row = {}
    row.textFrame = { CreateFontString = function() return FakeFS() end }
    return row
end

do
    DM.Reset()
    played = {}
    resCfg = {
        textSize = 12,
        metaTime = { rules = { { cmp = ">=", value = 60, color = { r = 1, g = 0, b = 0 }, size = 18, sound = "Alarm" },
                               { cmp = ">=", value = 0, sound = "Start" } } },
        metaStars = { prefix = "none", rules = { { cmp = ">=", value = 2, sound = "Two" }, { cmp = ">=", value = 1 } } },
    }
    local row = FakeRow()
    DM.Layout(row, resCfg, resCfg)
    local t, st = row.metaTime, row.metaStars
    eq("平常沒字（計時）", t.text, "")
    auras = { [DM.META_AURA] = {} }
    now = 1000
    DM.Update(row)
    eq("進化身那一刻 ≥0 響", played[1], "Start@meta:time:2")
    eq("星 0 顆沒有規則成立不響", #played, 1)
    eq("計時 0:00", t.text, "0:00")
    eq("星 0", st.text, "0")
    eq("進化身叫 ticker", armed > 0, true)
    local sets = t.sets
    now = 1000.5
    DM.Paint(row)
    eq("整數秒沒變不重畫", t.sets, sets)
    now = 1023
    DM.Paint(row)
    eq("跳到 0:23", t.text, "0:23")
    eq("同一條持續成立不重響", #played, 1)
    now = 1060
    DM.Paint(row)
    eq("換到第 1 條響", played[2], "Alarm@meta:time:1")
    eq("第 1 條換字級", t.font.size, 18)
    eq("第 1 條換色", t.color[1], 1)
    eq("第 1 條換色（綠 0）", t.color[2], 0)
    -- 崩陷之星：1 顆（第 2 條沒音效）、2 顆響
    DM.OnSpellcast("player", "g", DM.STAR_SPELL)
    DM.Paint(row)
    eq("星 1", st.text, "1")
    eq("沒音效的規則不響", #played, 2)
    DM.OnSpellcast("player", "g", DM.STAR_SPELL)
    DM.Paint(row)
    eq("星 2 響", played[3], "Two@meta:stars:1")
    -- 離開化身：計時開 hold 3 秒、星沒開
    resCfg.metaTime.hold, resCfg.metaTime.holdSec = true, 3
    auras = {}
    now = 1070
    DM.Update(row)
    eq("保留中計時停在最後的值", t.text, "1:10")
    eq("星沒開 hold ⇒ 清字", st.text, "")
    eq("保留中規則外觀保留（字級）", t.font.size, 18)
    eq("保留期間不響", #played, 3)
    now = 1073
    DM.Paint(row)
    eq("保留過期清字", t.text, "")
    eq("過期後不要 ticker", DM.NeedsTick(DM.state), false)
    -- 再進化身：規則狀態清掉 ⇒ ≥0 又響一次
    auras = { [DM.META_AURA] = {} }
    now = 1100
    DM.Update(row)
    eq("離開再回來再響", played[4], "Start@meta:time:2")
    eq("退回基本字級（跟隨列數字 12）", t.font.size, 12)
    -- 預覽：不在化身、設定開著 ⇒ 顯示預覽值、跑規則、不響
    auras = {}
    resCfg.metaTime.hold = false
    now = 1110
    DM.Update(row)
    eq("離開化身清字", t.text, "")
    editing = true
    DM.preview.time, DM.preview.stars = 75, 3
    DM.Paint(row)
    eq("預覽值（計時）", t.text, "1:15")
    eq("預覽值（星）", st.text, "3")
    eq("預覽照跑規則（字級）", t.font.size, 18)
    eq("預覽不響", #played, 4)
    editing = false
    DM.Paint(row)
    eq("預覽結束清字", t.text, "")
    -- 關掉的那段不畫
    resCfg.metaStars.enabled = false
    DM.Layout(row, resCfg, resCfg)
    eq("關掉的那段藏起來", st.shown, false)
    DM.Hide(row)
    eq("換成別的資源：收起來", t.shown, false)
    DM.Reset()
    DM.preview.time, DM.preview.stars = 23, 3
end

-- 星的前綴
do
    DM.Reset()
    resCfg = { metaStars = { prefix = "icon" } }
    local row = FakeRow()
    DM.Layout(row, resCfg, resCfg)
    auras = { [DM.META_AURA] = {} }
    now = 2000
    DM.Update(row)
    check("法術圖示前綴", row.metaStars.text:find("^|T12345:0") ~= nil, row.metaStars.text)
    check("圖示後面是顆數", row.metaStars.text:find("|t 0$") ~= nil, row.metaStars.text)
    resCfg.metaStars.prefix, resCfg.metaStars.prefixText = "text", "星"
    DM.Layout(row, resCfg, resCfg)
    DM.Paint(row)
    eq("文字前綴", row.metaStars.text, "星 0")
    resCfg.metaStars.prefixText = ""
    DM.Layout(row, resCfg, resCfg)
    DM.Paint(row)
    eq("文字前綴空白 ＝ 只印數字", row.metaStars.text, "0")
    resCfg.metaTime = { format = "sec" }
    now = 2042
    DM.Layout(row, resCfg, resCfg)
    DM.Paint(row)
    eq("計時 sec 格式", row.metaTime.text, "42")
    auras = {}
    DM.Reset()
end

------------------------------------------------------------
-- 6. CleanRules
------------------------------------------------------------
do
    local src = {
        { cmp = ">=", value = 60, color = { r = 1, g = 0, b = 0 }, size = 99, sound = "A" },
        { cmp = "=>", value = 1 },                         -- cmp 壞
        { cmp = ">", value = "abc" },                      -- value 壞
        "junk",
        { cmp = "<", value = "30", color = { r = "x" }, size = 2, sound = "" },
        { cmp = "==", value = 1 }, { cmp = "==", value = 2 }, { cmp = "==", value = 3 },
        { cmp = "==", value = 4 }, { cmp = "==", value = 5 },
    }
    local out = DM.CleanRules(src)
    eq("截 6 條", #out, 6)
    eq("順序（第 1 條）", out[1].value, 60)
    eq("字級夾上限", out[1].size, 40)
    eq("顏色留著", out[1].color and out[1].color.r, 1)
    eq("顏色補 alpha", out[1].color and out[1].color.a, 1)
    eq("顏色是複本", out[1].color ~= src[1].color, true)
    eq("音效留著", out[1].sound, "A")
    eq("字串數值轉數字", out[2].value, 30)
    eq("壞顏色只丟顏色", out[2].color, nil)
    eq("字級夾下限", out[2].size, 6)
    eq("空音效丟掉", out[2].sound, nil)
    eq("第 6 條是 == 4", out[6].value, 4)
    eq("原表不動", #src, 10)
    eq("nil ⇒ 空表", #DM.CleanRules(nil), 0)
    eq("R.CleanMetaRules 的形狀（空）", #DM.CleanRules({}), 0)
end

------------------------------------------------------------
-- 7. 位置
------------------------------------------------------------
do
    local p, rel, rp, dx = DM.AnchorFor("time", "RIGHT", "LEFT", true)
    eq("預設：計時貼右邊", p .. "/" .. rel .. "/" .. rp .. "/" .. dx, "RIGHT/row/RIGHT/-4")
    p, rel, rp, dx = DM.AnchorFor("stars", "RIGHT", "LEFT", true)
    eq("預設：星貼左邊", p .. "/" .. rel .. "/" .. rp .. "/" .. dx, "LEFT/row/LEFT/4")
    p, rel, rp, dx = DM.AnchorFor("stars", "RIGHT", "RIGHT", true)
    eq("同在右邊：星貼在計時左側", p .. "/" .. rel .. "/" .. rp .. "/" .. dx, "RIGHT/time/LEFT/-4")
    p, rel, rp, dx = DM.AnchorFor("time", "RIGHT", "RIGHT", true)
    eq("同在右邊：計時在最外側", p .. "/" .. rel .. "/" .. rp .. "/" .. dx, "RIGHT/row/RIGHT/-4")
    p, rel, rp, dx = DM.AnchorFor("stars", "LEFT", "LEFT", true)
    eq("同在左邊：星貼在計時右側", p .. "/" .. rel .. "/" .. rp .. "/" .. dx, "LEFT/time/RIGHT/4")
    p, rel = DM.AnchorFor("stars", "LEFT", "LEFT", false)
    eq("計時關掉：星回到列邊", rel, "row")
    p = DM.AnchorFor("time", "bogus", "LEFT", true)
    eq("壞值當右邊", p, "RIGHT")

    -- Layout：位移乘 UIParent 縮放（字型忽略父層縮放），同一邊時星錨在計時上
    resCfg = { metaTime = { side = "LEFT", x = 10, y = -2 }, metaStars = { side = "LEFT", x = 1 } }
    local row = FakeRow()
    DM.Layout(row, resCfg, resCfg)
    local tp = row.metaTime.points[1]
    eq("計時錨點", tp[1], "LEFT")
    eq("計時錨在 textFrame", tp[2], row.textFrame)
    eq("計時 x ＝ (4 + 10) × 0.5", tp[4], 7)
    eq("計時 y ＝ -2 × 0.5", tp[5], -1)
    local sp = row.metaStars.points[1]
    eq("星錨在計時上", sp[2], row.metaTime)
    eq("星貼計時右緣", sp[3], "RIGHT")
    eq("星 x ＝ (4 + 1) × 0.5", sp[4], 2.5)
    eq("對齊跟錨點同一邊", row.metaStars.justify, "LEFT")
end

------------------------------------------------------------
-- 8. 設定讀取
------------------------------------------------------------
do
    local c = {}
    eq("計時預設開", DM.Get(c, "time", "enabled"), true)
    eq("計時預設右", DM.Get(c, "time", "side"), "RIGHT")
    eq("星預設左", DM.Get(c, "stars", "side"), "LEFT")
    eq("計時預設格式", DM.Get(c, "time", "format"), "mss")
    eq("星沒有格式", DM.Get(c, "stars", "format"), nil)
    eq("星預設圖示前綴", DM.Get(c, "stars", "prefix"), "icon")
    eq("hold 預設關", DM.Get(c, "time", "hold"), false)
    eq("holdSec 預設 3", DM.Get(c, "stars", "holdSec"), 3)
    eq("計時預設白", DM.Get(c, "time", "color").g, 1)
    eq("字級沒存 ＝ nil（跟隨）", DM.Get(c, "time", "size"), nil)
    c.metaTime = { enabled = false, side = "UP", x = 99, holdSec = 0, size = 3, format = "x" }
    eq("關掉", DM.Get(c, "time", "enabled"), false)
    eq("壞 side 退回預設", DM.Get(c, "time", "side"), "RIGHT")
    eq("位移夾 50", DM.Get(c, "time", "x"), 50)
    eq("holdSec 夾 1", DM.Get(c, "time", "holdSec"), 1)
    eq("字級夾 6", DM.Get(c, "time", "size"), 6)
    eq("壞格式退回預設", DM.Get(c, "time", "format"), "mss")
    eq("cfg 不是表", DM.Get(nil, "stars", "side"), "LEFT")

    -- 跟隨列數字：字型／字級／描邊
    local rowCfg = { textFont = "RowFont", textSize = 14, rowOutline = "THICKOUTLINE" }
    local f, sz, ol = DM.TextStyle({}, "time", rowCfg)
    eq("跟隨列的字型", f, "RowFont")
    eq("跟隨列的字級", sz, 14)
    eq("跟隨列的描邊", ol, "THICKOUTLINE")
    f, sz, ol = DM.TextStyle({ metaTime = { font = "Mine", size = 20, outline = "" } }, "time", rowCfg)
    eq("自己的字型", f, "Mine")
    eq("自己的字級", sz, 20)
    eq("描邊「無」是有效值", ol, "")
    f = DM.TextStyle({ metaTime = { font = "INHERIT" } }, "time", {})
    eq("INHERIT ＋ 列沒挑 ⇒ 通用字型", f, "GENERAL")
    eq("列沒字級 ⇒ 10", select(2, DM.TextStyle({}, "stars", {})), 10)
end

------------------------------------------------------------
-- 9. 資源條接線（真的 Modules/Resources.lua）
------------------------------------------------------------
do
    local fakeRes = ns.Resources
    Load("Modules/Resources.lua")
    local R = ns.Resources
    local w = R.WantedEvents({ "Fury", "DevourerFragments" }, "DEMONHUNTER")
    eq("噬靈魂碎片列 ⇒ 註冊施法事件", w.UNIT_SPELLCAST_SUCCEEDED, true)
    eq("噬靈魂碎片列 ⇒ UNIT_AURA", w.UNIT_AURA, true)
    w = R.WantedEvents({ "Fury", "SoulFragments" }, "DEMONHUNTER")
    eq("復仇（581）不註冊施法事件", w.UNIT_SPELLCAST_SUCCEEDED, nil)
    w = R.WantedEvents({ "Fury" }, "DEMONHUNTER")
    eq("浩劫（577）不註冊施法事件", w.UNIT_SPELLCAST_SUCCEEDED, nil)
    w = R.WantedEvents({}, "DEMONHUNTER")
    eq("沒有列不註冊", w.UNIT_SPELLCAST_SUCCEEDED, nil)
    eq("只有 1480 的清單有噬靈魂碎片", table.concat(R.RawList("DEMONHUNTER", 1480, nil), ","), "Fury,DevourerFragments")
    eq("噬靈魂碎片帶 meta 旗標", R.Info("DevourerFragments").meta, true)
    eq("別的資源沒有 meta", R.Info("SoulFragments").meta, nil)
    local out = R.CleanMetaRules({ { cmp = ">=", value = 1 }, { cmp = "?", value = 1 } })
    eq("R.CleanMetaRules 轉手", #out, 1)
    eq("R.TextOutline 公開", type(R.TextOutline), "function")
    ns.Resources = fakeRes
end

print(("DevourerMeta_test: %d passed, %d failed"):format(passed, failed))
if failed > 0 then os.exit(1) end
