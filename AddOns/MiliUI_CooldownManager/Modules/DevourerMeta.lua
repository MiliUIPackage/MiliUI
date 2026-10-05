------------------------------------------------------------
-- 噬滅（噬魂者 1480）的虛空化身計時＋崩陷之星計數
--
-- 掛在資源條的靈魂碎片列（DevourerFragments）上的兩段字，跟列的數字 row.text 同一個 textFrame：
--   row.metaTime    這次虛空化身持續多久（**正數計時**：1217607 沒有持續時間，化身撐到撐不住為止，沒有「剩幾秒」）
--   row.metaStars   這次化身裡成功施放了幾顆崩陷之星（1221150）
-- 平常 SetText("")、化身中才有字；碎片數字 row.text 永遠置中、不受影響（使用者 2026-10-06 拍板：不提供「取代碎片數字」）。
-- 不另開一列、不改面板高度：資源條往上長、上面疊施法條與增益圖示，化身進出時改高度會在戰鬥中整疊跳動。
--
-- 設定（resources.metaTime.* ／ resources.metaStars.*，全域、所有專精共用；只有 1480 讀得到。nil ＝ 預設，不遷移）：
--   enabled  顯示（預設開）
--   side     LEFT／RIGHT（預設計時右、崩陷之星左）。兩段同一邊 ⇒ 並排：計時在最外側、崩陷之星在內側、中間 4px
--   x, y     位移微調（-50～50）；離列邊的內縮固定 4px
--   font／size／outline   nil ＝ 跟隨這一列的數字（R.StyleFor 的 textFont／textSize／描邊）
--   color    顏色（含透明度；預設白／淡紫）
--   format   計時才有：mss（0:23）／sec（23）
--   prefix, prefixText    崩陷之星才有：none／icon（法術圖示，跟字一樣高）／text（自訂文字）
--   hold, holdSec         化身結束後保留 N 秒（預設關、3 秒）；兩段各自
--   rules    門檻規則 { { cmp, value, color?, size?, sound? }, … }，由上而下第一條成立的生效，最多 6 條
--            （設定頁寫入前過 DM.CleanRules；引擎照樣逐條驗，壞的當不成立）
--
-- 訊號（全部是明文，見 .claude/notes/wow-121-secret-values.md）：
--   * 化身：C_UnitAuras.GetPlayerAuraBySpellID(1217607) **有沒有表**（碎片列本來就靠它換上限）。
--     不讀光環的 duration／expirationTime（12.1 秘密）；false→true 記 GetTime()。登入／reload 時已在化身中
--     ⇒ 從現在起算（同 VoidChimes）。
--   * 崩陷之星：UNIT_SPELLCAST_SUCCEEDED（RegisterUnitEvent 綁 player：C 層濾掉別人的施法，也不必拿可能是
--     秘密字串的 unit token 比對），spellID == 1221150 而且在化身中 ⇒ +1；進化身歸零。比對前先 ns.IsSecret，
--     秘密就略過那一次（安靜漏數，/mcdm debug 記「略過秘密」）。參數形狀照 VoidChimes 相容兩種：
--     (unit, castGUID, spellID)／(unit, spellID)。
--   * 跳字：共用資源條的 0.1 秒 ticker（R.ArmTicker）；整數秒變了才 SetText、才重評規則。
--
-- 規則音效：命中的規則從「不是這條」變成「這條」而且這條有 sound ⇒ 播一次（ns.Sound.PlayNamed，
-- 總開關／聲道／讀取畫面靜音／節流照音效那套）。進化身時規則狀態清掉 ⇒「≥ 0」這種一進化身就成立的規則
-- 會在進化身那一刻響。化身結束的保留期間字停在最後的值、外觀保留、不再響。
--
-- 預覽：設定視窗開著或暴雪編輯模式中（ns.EditMode.Editing()）、而且沒在化身裡，兩段顯示預覽值（0:23、3）
-- 並照預覽值跑一次規則（換色換字級看得到，音效不響）。預覽值固定，沒有設定。
--
-- 這支放狀態機與純函式（Tests/DevourerMeta_test.lua 測），畫字也在這裡；Modules/Resources.lua 在排版、
-- 重畫、ticker、事件幾個點呼叫進來。
------------------------------------------------------------
local _, ns = ...

ns.DevourerMeta = {}
local DM = ns.DevourerMeta

local RC = ns.ResCond

DM.META_AURA   = 1217607         -- 虛空化身（增益本身，沒有持續時間）
DM.STAR_SPELL  = 1221150         -- 崩陷之星
DM.ROW_KEY     = "DevourerFragments"
DM.MAX_RULES   = 6
DM.EDGE_INSET  = 4               -- 離列邊
DM.PAIR_GAP    = 4               -- 同一邊並排時兩段的間距
DM.OFFSET_MIN, DM.OFFSET_MAX = -50, 50
DM.SIZE_MIN, DM.SIZE_MAX     = 6, 40
DM.HOLD_MIN, DM.HOLD_MAX     = 1, 10
DM.VALUE_MAX = { time = 600, stars = 99 }   -- 門檻數值的上限（秒／顆）
DM.WHICH = { "time", "stars" }
DM.FIELD = { time = "metaTime", stars = "metaStars" }

-- 預覽值（固定；測試會改）
DM.preview = { time = 23, stars = 3 }

local DEFAULTS = {
    time  = { enabled = true, side = "RIGHT", x = 0, y = 0, color = { r = 1, g = 1, b = 1, a = 1 },
              format = "mss", hold = false, holdSec = 3 },
    stars = { enabled = true, side = "LEFT", x = 0, y = 0, color = { r = 0.75, g = 0.6, b = 1, a = 1 },
              prefix = "icon", prefixText = "", hold = false, holdSec = 3 },
}
DM.DEFAULTS = DEFAULTS

local SIDES   = { LEFT = true, RIGHT = true }
local FORMATS = { mss = true, sec = true }
local PREFIXES = { none = true, icon = true, text = true }

------------------------------------------------------------
-- 設定讀取（純函式；cfg ＝ resources 的原表）
------------------------------------------------------------
local function Own(cfg, which)
    local t = type(cfg) == "table" and cfg[DM.FIELD[which]]
    return type(t) == "table" and t or nil
end
DM.Own = Own

local function Clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

-- 一個欄位的有效值：存的值過驗證，不合法／沒存退回預設。
-- font／size／outline 沒有預設（nil ＝ 跟隨這一列的數字），由 DM.TextStyle 解
function DM.Get(cfg, which, field)
    local d = DEFAULTS[which]
    if not d then return nil end
    local own = Own(cfg, which)
    local v = own and own[field]
    if field == "enabled" or field == "hold" then
        if type(v) == "boolean" then return v end
        return d[field]
    elseif field == "side" then
        return SIDES[v] and v or d.side
    elseif field == "x" or field == "y" then
        v = tonumber(v)
        return v and Clamp(math.floor(v + 0.5), DM.OFFSET_MIN, DM.OFFSET_MAX) or 0
    elseif field == "holdSec" then
        v = tonumber(v)
        return v and Clamp(math.floor(v + 0.5), DM.HOLD_MIN, DM.HOLD_MAX) or d.holdSec
    elseif field == "format" then
        if which ~= "time" then return nil end
        return FORMATS[v] and v or d.format
    elseif field == "prefix" then
        if which ~= "stars" then return nil end
        return PREFIXES[v] and v or d.prefix
    elseif field == "prefixText" then
        if which ~= "stars" then return nil end
        return type(v) == "string" and v or d.prefixText
    elseif field == "color" then
        return RC.ValidColor(v) or d.color
    elseif field == "size" then
        v = tonumber(v)
        return v and Clamp(math.floor(v + 0.5), DM.SIZE_MIN, DM.SIZE_MAX) or nil
    elseif field == "rules" then
        return type(v) == "table" and v or nil
    end
    return v
end

------------------------------------------------------------
-- 純函式
------------------------------------------------------------
-- 經過秒數 → 字：mss → "%d:%02d"、sec → "%d"；負數夾 0、小數捨去
function DM.FormatElapsed(sec, fmt)
    sec = tonumber(sec) or 0
    if sec < 0 then sec = 0 end
    sec = math.floor(sec)
    if fmt == "sec" then return ("%d"):format(sec) end
    return ("%d:%02d"):format(math.floor(sec / 60), sec % 60)
end

function DM.NewState()
    return {
        inMeta = false, since = nil, endSec = nil, stars = 0,
        hold = { time = nil, stars = nil },          -- 保留到什麼時候（GetTime）；nil ＝ 沒在保留
        lastRule = { time = nil, stars = nil },      -- 上一次命中的規則索引（音效的邊緣判斷）
        counted = 0, skipped = 0,                    -- /mcdm debug：計了幾顆、略過幾次秘密 spellID
    }
end

-- 換專精、列被關、資源條關掉：整個狀態重設（debug 計數留著）
function DM.ResetState(s)
    s.inMeta, s.since, s.endSec, s.stars = false, nil, nil, 0
    s.hold.time, s.hold.stars = nil, nil
    s.lastRule.time, s.lastRule.stars = nil, nil
end

-- 化身進出。holdTime／holdStars ＝ 那一段開了「保留 N 秒」時的秒數（沒開 nil）。
-- 回傳 "enter"／"exit"／nil（沒變）
function DM.Transition(s, inMeta, now, holdTime, holdStars)
    inMeta = inMeta and true or false
    if inMeta == s.inMeta then return nil end
    s.inMeta = inMeta
    if inMeta then
        s.since, s.endSec, s.stars = now, nil, 0
        s.hold.time, s.hold.stars = nil, nil
        s.lastRule.time, s.lastRule.stars = nil, nil
        return "enter"
    end
    s.endSec = s.since and math.max(0, math.floor(now - s.since)) or 0
    s.since = nil
    s.hold.time = holdTime and (now + holdTime) or nil
    s.hold.stars = holdStars and (now + holdStars) or nil
    return "exit"
end

-- 保留期過了的清掉；回傳有沒有清
function DM.Expire(s, now)
    local changed = false
    for _, which in ipairs(DM.WHICH) do
        local t = s.hold[which]
        if t and now >= t then
            s.hold[which] = nil
            changed = true
        end
    end
    return changed
end

-- ticker 要不要跑：化身中，或還有保留沒清（清掉那一下要再畫一次，所以看「有沒有值」不看過期沒）
function DM.NeedsTick(s)
    return s.inMeta or s.hold.time ~= nil or s.hold.stars ~= nil
end

-- 一段現在的狀態與值：mode ＝ "live"（化身中）／"hold"（保留中）／nil（不顯示）
function DM.Value(s, which, now)
    if s.inMeta then
        if which == "time" then return "live", math.max(0, math.floor(now - (s.since or now))) end
        return "live", s.stars
    end
    if s.hold[which] then
        if which == "time" then return "hold", s.endSec or 0 end
        return "hold", s.stars
    end
    return nil, nil
end

-- 施法事件的參數形狀（照 VoidChimes）：(unit, castGUID, spellID)，第二個參數是數字時當 spellID
function DM.CastSpellID(a2, a3)
    if type(a2) == "number" then return a2 end
    return a3
end

-- 崩陷之星計數：秘密 spellID 略過（不比較），別的法術不計，化身外不計。回傳有沒有 +1
function DM.CountCast(s, spellID, isSecret)
    if spellID == nil then return false end
    if isSecret and isSecret(spellID) then
        s.skipped = s.skipped + 1
        return false
    end
    if spellID ~= DM.STAR_SPELL then return false end
    if not s.inMeta then return false end
    s.stars = s.stars + 1
    s.counted = s.counted + 1
    return true
end

-- 規則求值：第一條成立的索引或 nil。cmp 不在白名單、value 不是數字的規則當不成立（不報錯）。
-- 值是我們自己算的明文（經過秒數、顆數）
function DM.MatchRule(rules, value)
    if type(rules) ~= "table" or type(value) ~= "number" then return nil end
    local ops = RC.CMP_OPS
    for i = 1, math.min(#rules, DM.MAX_RULES) do
        local r = rules[i]
        if type(r) == "table" then
            local op = ops[r.cmp]
            local v = r.value
            if op and type(v) == "number" and op(value, v) then return i end
        end
    end
    return nil
end

-- 音效的邊緣：命中的規則換了（含 nil → 某條）就記下；回傳「該不該響」（換到一條規則上才響）
function DM.RuleEdge(s, which, idx)
    if s.lastRule[which] == idx then return false end
    s.lastRule[which] = idx
    return idx ~= nil
end

-- 規則表的清理（設定頁寫入前）：丟掉 cmp 不在白名單、value 非數字的；顏色壞了只丟顏色；
-- 字級夾在 6～40；音效只收非空字串；截 6 條、順序不變。回傳新表（原表不動）
function DM.CleanRules(rules)
    local out = {}
    if type(rules) ~= "table" then return out end
    for _, r in ipairs(rules) do
        if #out >= DM.MAX_RULES then break end
        if type(r) == "table" and RC.CMP_OPS[r.cmp] and tonumber(r.value) then
            local e = { cmp = r.cmp, value = tonumber(r.value) }
            local c = RC.ValidColor(r.color)
            if c then e.color = { r = c.r, g = c.g, b = c.b, a = tonumber(c.a) or 1 } end
            local sz = tonumber(r.size)
            if sz then e.size = Clamp(math.floor(sz + 0.5), DM.SIZE_MIN, DM.SIZE_MAX) end
            if type(r.sound) == "string" and r.sound ~= "" then e.sound = r.sound end
            out[#out + 1] = e
        end
    end
    return out
end

-- 位置：→ point, relTo（"row"／"time"）, relPoint, dx（不含玩家的位移）。
-- 崩陷之星跟計時同一邊而且計時開著 ⇒ 貼在計時的內緣（計時在最外側）
function DM.AnchorFor(which, timeSide, starsSide, timeOn)
    local side = which == "time" and timeSide or starsSide
    if side ~= "LEFT" then side = "RIGHT" end
    local sign = side == "LEFT" and 1 or -1
    if which == "stars" and timeOn and timeSide == starsSide then
        return side, "time", (side == "LEFT") and "RIGHT" or "LEFT", sign * DM.PAIR_GAP
    end
    return side, "row", side, sign * DM.EDGE_INSET
end

------------------------------------------------------------
-- 執行期
------------------------------------------------------------
local state = DM.NewState()
DM.state = state

local function Cfg() return ns.Resources and ns.Resources.Cfg() end

-- 顯示用的名字：法術名是官方譯名（載入當下讀不到就退回語系字串，下次再問）
local function SpellName(id, fallback)
    local fn = C_Spell and C_Spell.GetSpellName
    if fn then
        local ok, n = pcall(fn, id)
        if ok and type(n) == "string" and n ~= "" and not ns.IsSecret(n) then return n end
    end
    return fallback
end
function DM.MetaName() return SpellName(DM.META_AURA, ns.L["Void Metamorphosis"]) end
function DM.StarName() return SpellName(DM.STAR_SPELL, ns.L["Collapsing Star"]) end

local function ReadMeta()
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not get then return false end
    local ok, a = pcall(get, DM.META_AURA)
    return ok and a ~= nil
end

local function Holds(cfg)
    local t = DM.Get(cfg, "time", "hold") and DM.Get(cfg, "time", "holdSec") or nil
    local st = DM.Get(cfg, "stars", "hold") and DM.Get(cfg, "stars", "holdSec") or nil
    return t, st
end

-- 讀化身狀態、走狀態機；需要跳字就把 ticker 叫起來。回傳 Transition 的結果
function DM.Sync(now)
    now = now or GetTime()
    local tr = DM.Transition(state, ReadMeta(), now, Holds(Cfg()))
    if DM.NeedsTick(state) and ns.Resources and ns.Resources.ArmTicker then ns.Resources.ArmTicker() end
    return tr
end

function DM.Reset()
    DM.ResetState(state)
end

-- 施法事件（Resources.lua 的 OnEvent 轉來；只在有靈魂碎片列時註冊）。回傳計數有沒有變
function DM.OnSpellcast(_, a2, a3)
    local id = DM.CastSpellID(a2, a3)
    if id == nil then return false end
    if ns.IsSecret(id) then
        state.skipped = state.skipped + 1
        return false
    end
    if id ~= DM.STAR_SPELL then return false end
    -- 化身的 UNIT_AURA 還在下一幀的佇列裡時，先把狀態對齊再數（VoidChimes 的 wasInMeta 是同步更新的）
    DM.Sync(GetTime())
    return DM.CountCast(state, id, ns.IsSecret)
end

-- 崩陷之星的圖示（明文才收；讀到一次就記住）
local starIcon
local function StarIcon()
    if starIcon then return starIcon end
    local fn = C_Spell and C_Spell.GetSpellTexture
    if not fn then return nil end
    local ok, t = pcall(fn, DM.STAR_SPELL)
    if ok and t ~= nil and not ns.IsSecret(t) then starIcon = t end
    return starIcon
end

local function Text(which, value, cfg)
    if which == "time" then return DM.FormatElapsed(value, DM.Get(cfg, "time", "format")) end
    local p = DM.Get(cfg, "stars", "prefix")
    if p == "icon" then
        local tex = StarIcon()
        -- 高度 0 ＝ 跟字一樣高（規則換字級時跟著變）；裁掉圖示的外框
        if tex then return ("|T%s:0:0:0:0:64:64:5:59:5:59|t %d"):format(tostring(tex), value) end
    elseif p == "text" then
        local t = DM.Get(cfg, "stars", "prefixText")
        if t ~= "" then return t .. " " .. value end
    end
    return tostring(value)
end

-- 一段的基本外觀（跟隨 ＝ 這一列的數字）：→ 字型 token, 字級, 描邊
function DM.TextStyle(cfg, which, rowCfg)
    local own = Own(cfg, which)
    local M = ns.Media
    local font = own and own.font
    if type(font) ~= "string" or font == "" or font == M.INHERIT then
        font = M.ElementFont(type(rowCfg) == "table" and rowCfg.textFont or nil, ns.Setting(nil, "font"))
    end
    local size = DM.Get(cfg, which, "size") or tonumber(type(rowCfg) == "table" and rowCfg.textSize) or 10
    local outline = own and own.outline
    if not (type(outline) == "string" and M.OUTLINES[outline]) then
        outline = ns.Resources.TextOutline(rowCfg)
    end
    return font, size, outline
end

local function MakeFS(row)
    local fs = row.textFrame:CreateFontString(nil, "OVERLAY")
    -- ⚠ 先給字型才能 SetText
    ns.Media.SetPixelFont(fs, 10, "OUTLINE")
    fs:SetDrawLayer("OVERLAY", 7)
    fs:SetText("")
    return fs
end

-- 收起（這一列換成別的資源）
function DM.Hide(row)
    for _, k in ipairs({ "metaTime", "metaStars" }) do
        local fs = row[k]
        if fs then
            fs:SetText("")
            fs:Hide()
            fs.mVal, fs.mMode, fs.mRule = nil, nil, nil
        end
    end
end

-- 排版（Relayout 每次重排都叫）：字型、位置、顯示與否；快取全部作廢，下一次 Paint 重畫
--   rowCfg ＝ 這一列的外觀（R.StyleFor 的代理表，跟隨用）；cfg ＝ resources 原表
function DM.Layout(row, rowCfg, cfg)
    if not row.metaTime then
        row.metaTime, row.metaStars = MakeFS(row), MakeFS(row)
    end
    local timeOn, timeSide = DM.Get(cfg, "time", "enabled"), DM.Get(cfg, "time", "side")
    local starsSide = DM.Get(cfg, "stars", "side")
    -- 字型忽略父層縮放（SetPixelFont）⇒ 位移也要換成它自己的單位（同字級的乘法）
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    for _, which in ipairs(DM.WHICH) do
        local fs = which == "time" and row.metaTime or row.metaStars
        local font, size, outline = DM.TextStyle(cfg, which, rowCfg)
        fs.mFont, fs.mSize, fs.mOutline = font, size, outline
        fs.mColor = DM.Get(cfg, which, "color")
        ns.Media.SetPixelFont(fs, size, outline, font)
        local c = fs.mColor
        fs:SetTextColor(c.r, c.g, c.b, tonumber(c.a) or 1)
        local point, rel, relPoint, dx = DM.AnchorFor(which, timeSide, starsSide, timeOn)
        fs:ClearAllPoints()
        fs:SetPoint(point, rel == "time" and row.metaTime or row.textFrame, relPoint,
            (dx + DM.Get(cfg, which, "x")) * scale, DM.Get(cfg, which, "y") * scale)
        fs:SetJustifyH(point)
        fs:SetText("")
        fs.mVal, fs.mMode, fs.mRule = nil, nil, nil
        fs:SetShown(DM.Get(cfg, which, "enabled") and true or false)
    end
end

local NO_RULE = {}

-- 規則外觀：命中的規則換了才動（顏色、字級；同字型同描邊）。沒命中退回這段的基本外觀
local function ApplyRule(fs, rule)
    local want = rule or NO_RULE
    if fs.mRule == want then return end
    fs.mRule = want
    local c = (rule and RC.ValidColor(rule.color)) or fs.mColor
    local sz = rule and tonumber(rule.size)
    if sz then sz = Clamp(math.floor(sz + 0.5), DM.SIZE_MIN, DM.SIZE_MAX) else sz = fs.mSize end
    ns.Media.SetPixelFont(fs, sz, fs.mOutline, fs.mFont)
    fs:SetTextColor(c.r, c.g, c.b, tonumber(c.a) or 1)
end

local function Previewing()
    return ns.EditMode and ns.EditMode.Editing and ns.EditMode.Editing() or false
end

-- 重畫兩段（值變了才 SetText、才重評規則）
function DM.Paint(row, now)
    if not row.metaTime then return end
    local cfg = Cfg()
    now = now or GetTime()
    DM.Expire(state, now)
    local preview = not DM.NeedsTick(state) and Previewing()
    for _, which in ipairs(DM.WHICH) do
        local fs = which == "time" and row.metaTime or row.metaStars
        if fs:IsShown() then
            local mode, value = DM.Value(state, which, now)
            if not mode and preview then mode, value = "preview", DM.preview[which] end
            if not mode then
                if fs.mMode ~= nil then
                    fs:SetText("")
                    fs.mMode, fs.mVal = nil, nil
                end
            elseif value ~= fs.mVal or mode ~= fs.mMode then
                fs.mVal, fs.mMode = value, mode
                local rules = DM.Get(cfg, which, "rules")
                local idx = DM.MatchRule(rules, value)
                -- 音效只在真的化身中（保留期間、預覽不響）
                if mode == "live" and DM.RuleEdge(state, which, idx) then
                    local snd = rules[idx].sound
                    if type(snd) == "string" and snd ~= "" and ns.Sound and ns.Sound.PlayNamed then
                        ns.Sound.PlayNamed(snd, "meta:" .. which .. ":" .. idx)
                    end
                end
                ApplyRule(fs, idx and rules[idx] or nil)
                fs:SetText(Text(which, value, cfg))
            end
        end
    end
end

-- 碎片列的重畫（UNIT_AURA 等都會走到）：先對齊化身狀態再畫
function DM.Update(row)
    local now = GetTime()
    DM.Sync(now)
    DM.Paint(row, now)
end

function DM.DebugLine()
    local s = state
    local now = GetTime()
    local live = s.inMeta and DM.FormatElapsed(now - (s.since or now), "mss") or "否"
    return ("  虛空化身：%s  崩陷之星：計 %d、略過秘密 %d（這次 %d 顆）  保留 計時 %s／星 %s  規則 計時 %s／星 %s")
        :format(live, s.counted, s.skipped, s.stars,
                s.hold.time and ("%.1f"):format(s.hold.time - now) or "-",
                s.hold.stars and ("%.1f"):format(s.hold.stars - now) or "-",
                tostring(s.lastRule.time or "-"), tostring(s.lastRule.stars or "-"))
end
