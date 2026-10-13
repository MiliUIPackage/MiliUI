------------------------------------------------------------
-- 自訂列：玩家自己加的計時條，一條一列（獨立面板，容器 MiliUICDM_Bar_custombars）
--
-- 資料與樣式都借資源條的（同自訂格子）：
--   * 清單：profile.resources.customBars[specID]（每個專精一份，設定頁在資源條頁的「自訂列」分頁）
--   * 樣式：寬（0 ＝ 核心技能第一列）、材質、背景材質／透明度／自訂底色、填充透明度、邊框粗細／顏色、列距、
--     字型與描邊一律讀 profile.resources，不另開一組；高、顏色、圖示、文字、顯示方式、音效是每一列自己的
--   * 自己的只有 profile.custombars：enabled、pos、anchor、fadeWithEssential、loadConditions、strata
-- 預設錨在資源條上方（anchor BOTTOM → resources TOP）、往上長；施法條跟著核心技能上方，排開時自動排到
-- 自訂列外面（Core/Bars.lua 的 STACK_RANK 給 1.2，理由寫在那裡）。沒有任何一列時面板收合（不佔位，施法條貼回資源條）。
--
-- 三種列（entry.kind）：
--   buff      自身增益的剩餘時間：一顆單格 AuraContainer（Modules/AuraBar.lua 的 kind = "duration"），unit player、
--             filter HELPFUL、includeSpellIDs；條身交給按鈕的 SetDurationBar（RemainingTime ⇒ 往下縮）、秒數交給
--             SetDurationText、層數交給 SetApplicationCount（不給格式器：引擎 0／1 層不印字）
--   debuff    目標身上自己上的減益：同上，unit target、filter "HARMFUL|PLAYER"。容器只聽 UNIT_AURA，換目標不會
--             自己重掃 ⇒ PLAYER_TARGET_CHANGED 時叫 AuraBar.Refresh（UpdateAllAuras，暴雪開放給外部事件用的入口；
--             資源條的 Frozen 列同一招）
--   cooldown  法術冷卻：C_Spell.GetSpellCooldownDuration(id, true)（ignoreGCD）／有充能（maxCharges > 1）時
--             GetSpellChargeDuration 的 duration 物件交給 StatusBar:SetTimerDuration(RemainingTime) ＋ 一顆不畫扇形的
--             Cooldown（SetCooldownFromDurationObject）印秒數。只在 SPELL_UPDATE_COOLDOWN／CHARGES 時重取物件。
--             GCD：物件本來就不含 GCD，另外看 GetSpellCooldown 的明文 isOnGCD／isActive——只是 GCD、或沒在冷卻
--             ⇒ 餵零長度物件清空（條不閃）
--
-- 12.1 秘密值：光環在不在、剩餘時間、層數、冷卻剩餘，Lua 一個值都不讀不比較。
--   * 光環類全交給引擎：容器戰鬥中不建（記帳、PLAYER_REGEN_ENABLED 補）；樣式只能在 initializeFrame 裡烘 ⇒
--     影響外觀的設定全進簽章（AuraBar.Signature），換簽章換一顆容器，容器依簽章池化在列的持有框上
--   * 冷卻類只讀兩個明文旗標（isActive／isOnGCD；充能是 GetSpellCharges 的 isActive，NeverSecret），讀不到就
--     照樣把物件交出去；「只在生效時顯示」讀不到旗標時把 duration:IsZero() 的秘密布林餵 SetAlphaFromBoolean
--   * 低秒變色：光環類走 SetDurationText 的 textColor 色彩曲線；冷卻類走 Cooldown 的 SetCountdownFormatter
--     （格式字串包 |c 色碼，Core/Text.lua 同一條，會不會吃色碼待實機驗證）
--
-- 顯示方式（entry.showWhen）：
--   always   一直顯示：沒生效時畫空條（暗底＋邊框、圖示、名字都在列上，生效時引擎在上面畫填色與秒數）
--   active   只在生效時顯示：光環類整列（暗底、邊框、圖示、名字）建在按鈕子樹裡，按鈕只在有光環時顯示；
--            冷卻類照明文旗標 SetAlpha，讀不到交給引擎（SetAlphaFromBoolean）
--   不管哪一種都**佔位**：12.1 讀不到按鈕顯不顯示，面板高度只看有幾列。
--
-- 保護：AuraContainer 讓列與面板變保護框 ⇒ 戰鬥中不重排（記旗標、脫戰補），只重畫冷卻列的值。
-- 事件只在真的有那一種列時才註冊，處理器只標髒、下一幀做。
------------------------------------------------------------
local _, ns = ...

ns.CustomBars = {}
local CB = ns.CustomBars

local KEY = "custombars"
CB.KEY = KEY

local function Cfg() return ns.DB and ns.DB.ConfigTable(KEY) end
local function StyleCfg() return ns.DB and ns.DB.ConfigTable("resources") end
CB.Cfg, CB.StyleCfg = Cfg, StyleCfg

------------------------------------------------------------
-- 純函式：清單、每一列的設定、規劃、排版（離線測得到：Tests/CustomBars_test.lua）
--
--   resources.customBars[specID] = { entry, … }
--   entry = { kind = "buff"|"debuff"|"cooldown", spellID, enabled,
--             height,                        -- 沒存 ＝ HEIGHT_DEFAULT
--             classColor, color,             -- classColor 沒存＝職業色；false ＝ 用 color
--             icon = "left"|"right"|"none",  -- 沒存 ＝ left
--             name   = { show, point },      -- 沒存 ＝ 顯示、靠左
--             time   = { show, point, decimals },   -- 沒存 ＝ 顯示、靠右、低於 3 秒一位小數
--             stacks = { show, point },      -- 光環類才有；沒存 ＝ 顯示、置中
--             low    = { on, below, color }, -- 低時間文字變色；沒存 ＝ 關、5 秒、紅
--             textSize,                      -- 0／沒存 ＝ 照列高
--             showWhen = "always"|"active", reverse,
--             gainSound, loseSound,          -- 光環類（LSM 音效名或自訂語音代號）
--             readySound,                    -- 冷卻類
--             collapsed }                    -- 設定頁卡片摺疊（不影響畫面）
------------------------------------------------------------
local KINDS = { buff = true, debuff = true, cooldown = true }
CB.KINDS = KINDS
CB.KIND_ORDER = { "buff", "debuff", "cooldown" }
-- 光環類看誰、怎麼過濾
CB.AURA = {
    buff   = { unit = "player", filter = "HELPFUL" },
    debuff = { unit = "target", filter = "HARMFUL|PLAYER" },
}

CB.HEIGHT_MIN, CB.HEIGHT_MAX, CB.HEIGHT_DEFAULT = 4, 40, 16
CB.TEXT_SIZE_MIN, CB.TEXT_SIZE_MAX = 6, 30
CB.DECIMALS_MAX, CB.DECIMALS_DEFAULT = 10, 3
CB.LOW_MIN, CB.LOW_MAX, CB.LOW_DEFAULT = 1, 60, 5
CB.LOW_COLOR_DEFAULT = { r = 1, g = 0.3, b = 0.3 }
CB.TEXT_PAD = 3                  -- 靠邊的文字離條邊多遠（版面單位）
CB.SHOW_WHEN = { "always", "active" }
CB.POINTS = { "LEFT", "CENTER", "RIGHT" }
CB.ICON_SIDES = { "left", "right", "none" }
local POINT_OK = { LEFT = true, CENTER = true, RIGHT = true }
local ICON_OK = { left = true, right = true, none = true }

local function Clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function ValidRGB(c)
    if type(c) ~= "table" then return nil end
    local r, g, b = tonumber(c.r), tonumber(c.g), tonumber(c.b)
    if not (r and g and b) then return nil end
    return { r = Clamp(r, 0, 1), g = Clamp(g, 0, 1), b = Clamp(b, 0, 1) }
end

local function SoundName(v)
    if type(v) == "string" and v ~= "" then return v end
    return nil
end

-- 這個專精的清單；create ＝ 沒有就建（寫入用），否則沒有回 nil
function CB.List(cfg, specID, create)
    if type(cfg) ~= "table" or specID == nil then return nil end
    local all = cfg.customBars
    if type(all) ~= "table" then
        if not create then return nil end
        all = {}
        cfg.customBars = all
    end
    local list = all[specID]
    if type(list) ~= "table" then
        if not create then return nil end
        list = {}
        all[specID] = list
    end
    return list
end

-- 同一個專精裡已經有同種類、同法術的列 → 它的位置
function CB.Find(cfg, specID, kind, spellID)
    for i, e in ipairs(CB.List(cfg, specID) or {}) do
        if type(e) == "table" and e.kind == kind and e.spellID == spellID then return i end
    end
    return nil
end

function CB.Add(cfg, specID, entry)
    if type(entry) ~= "table" or not KINDS[entry.kind] or type(entry.spellID) ~= "number" then return nil end
    local list = CB.List(cfg, specID, true)
    if not list then return nil end
    list[#list + 1] = entry
    return #list
end

-- 刪掉第 i 筆；清單空了就把這個專精的鍵拿掉（存檔不留空表）
function CB.Remove(cfg, specID, i)
    local list = CB.List(cfg, specID)
    if not (list and type(i) == "number" and list[i] ~= nil) then return false end
    table.remove(list, i)
    if list[1] == nil then cfg.customBars[specID] = nil end
    return true
end

-- 第 from 筆搬到插入位置 to（1..n+1，「插在第 to 筆前面」；拖曳排序的語意）。沒動回 false
function CB.Move(list, from, to)
    if type(list) ~= "table" or list[from] == nil or type(to) ~= "number" then return false end
    if to == from or to == from + 1 then return false end
    local e = table.remove(list, from)
    if to > from then to = to - 1 end
    if to < 1 then to = 1 elseif to > #list + 1 then to = #list + 1 end
    table.insert(list, to, e)
    return true
end

-- 新增時的預設內容（設定頁驗證通過後建這一筆）
function CB.NewEntry(kind, spellID)
    if not KINDS[kind] or type(spellID) ~= "number" then return nil end
    return { kind = kind, spellID = spellID, enabled = true }
end

-- 一列的設定解成生效值（壞資料、沒存的退回預設；數字夾範圍）
function CB.Style(entry)
    local e = type(entry) == "table" and entry or {}
    local s = {}
    s.kind = KINDS[e.kind] and e.kind or nil
    s.aura = (s.kind == "buff" or s.kind == "debuff")
    s.height = Clamp(math.floor(tonumber(e.height) or CB.HEIGHT_DEFAULT), CB.HEIGHT_MIN, CB.HEIGHT_MAX)
    s.classColor = e.classColor ~= false
    s.color = ValidRGB(e.color)
    s.icon = ICON_OK[e.icon] and e.icon or "left"
    local n = type(e.name) == "table" and e.name or {}
    s.nameShow = n.show ~= false
    s.namePoint = POINT_OK[n.point] and n.point or "LEFT"
    -- 名字什麼時候出現：生效時（光環在、或冷卻中；預設）｜一直顯示
    s.nameWhen = (n.when == "always") and "always" or "active"
    local t = type(e.time) == "table" and e.time or {}
    s.timeShow = t.show ~= false
    s.timePoint = POINT_OK[t.point] and t.point or "RIGHT"
    s.decimals = Clamp(math.floor(tonumber(t.decimals) or CB.DECIMALS_DEFAULT), 0, CB.DECIMALS_MAX)
    local k = type(e.stacks) == "table" and e.stacks or {}
    s.stacksShow = s.aura and k.show ~= false
    s.stacksPoint = POINT_OK[k.point] and k.point or "CENTER"
    local lo = type(e.low) == "table" and e.low or {}
    s.lowOn = lo.on == true
    s.lowBelow = Clamp(math.floor(tonumber(lo.below) or CB.LOW_DEFAULT), CB.LOW_MIN, CB.LOW_MAX)
    s.lowColor = ValidRGB(lo.color) or { r = CB.LOW_COLOR_DEFAULT.r, g = CB.LOW_COLOR_DEFAULT.g, b = CB.LOW_COLOR_DEFAULT.b }
    local size = math.floor(tonumber(e.textSize) or 0)
    s.textSizeAuto = size <= 0
    if size <= 0 then
        s.textSize = Clamp(s.height - 4, 8, CB.TEXT_SIZE_MAX)
    else
        s.textSize = Clamp(size, CB.TEXT_SIZE_MIN, CB.TEXT_SIZE_MAX)
    end
    s.showWhen = (e.showWhen == "active") and "active" or "always"
    s.reverse = e.reverse == true
    s.gainSound = s.aura and SoundName(e.gainSound) or nil
    s.loseSound = s.aura and SoundName(e.loseSound) or nil
    s.readySound = (s.kind == "cooldown") and SoundName(e.readySound) or nil
    return s
end

-- 填色：職業色（classR/G/B 由呼叫端給）或自訂色
function CB.FillColor(s, cr, cg, cb)
    if s and not s.classColor and s.color then return s.color.r, s.color.g, s.color.b end
    return cr or 1, cg or 1, cb or 1
end

-- 這個專精實際要建哪些列。probe.known(spellID) → 冷卻列的法術學了沒（光環類不問：沒有光環 ＝ 空條）
-- 回傳 { { index, entry, kind, spellID, st, aura }, … }，順序照清單；壞資料、enabled = false、沒學會的冷卻法術都不建
function CB.Plan(cfg, specID, probe)
    local out = {}
    local list = CB.List(cfg, specID)
    if not list then return out end
    probe = probe or {}
    for i, e in ipairs(list) do
        if type(e) == "table" and KINDS[e.kind] and type(e.spellID) == "number" and e.enabled ~= false then
            local ok = true
            if e.kind == "cooldown" and probe.known then ok = probe.known(e.spellID) and true or false end
            if ok then
                local st = CB.Style(e)
                out[#out + 1] = { index = i, entry = e, kind = e.kind, spellID = e.spellID, st = st, aura = st.aura }
            end
        end
    end
    return out
end

-- 容器高度 ＝ 各列高加總＋列距（沒有列 ＝ 0：收合，施法條貼回資源條）
function CB.PanelHeight(heights, gap)
    if type(heights) ~= "table" or heights[1] == nil then return 0 end
    local sum = 0
    for _, h in ipairs(heights) do sum = sum + h end
    return sum + (#heights - 1) * (tonumber(gap) or 0)
end

-- 每一列離「錨點那一緣」多遠（第一列 0，往外累加：高＋列距）
function CB.RowOffsets(heights, gap)
    local out, y = {}, 0
    gap = tonumber(gap) or 0
    for i, h in ipairs(heights or {}) do
        out[i] = y
        y = y + h + gap
    end
    return out
end

-- 往哪邊長：錨在別人下方（本條 TOP 貼目標 BOTTOM）⇒ "down"（第一列在最上面、往下排）；
-- 其他（上方、沒錨定、照字面貼的組合）⇒ "up"（第一列在最下面、往上排）。跟 Layout.AnchorSide 同一套判斷
function CB.Grow(anchor)
    if type(anchor) ~= "table" then return "up" end
    local p, r = tostring(anchor.point or "TOP"), tostring(anchor.relPoint or "BOTTOM")
    if p:find("^TOP") and r:find("^BOTTOM") then return "down" end
    return "up"
end

-- 一列的橫向切法：圖示是邊長 H 的正方形，跟條身之間隔 gap。回傳 { barX, barW, iconX, iconW }（x 從列左緣量）
function CB.Geometry(W, H, icon, gap)
    W, H, gap = tonumber(W) or 0, tonumber(H) or 0, tonumber(gap) or 0
    local g = { barX = 0, barW = W, iconX = 0, iconW = 0, gap = gap, H = H }
    if icon == "left" or icon == "right" then
        g.iconW = H
        g.barW = W - H - gap
        if icon == "left" then
            g.iconX, g.barX = 0, H + gap
        else
            g.iconX, g.barX = W - H, 0
        end
    end
    if g.barW < 1 then g.barW = 1 end
    return g
end

-- 名字最多多寬：秒數／層數在另一邊時讓出約三分之一；跟名字同一邊就整條寬（玩家自己選了疊在一起）
function CB.NameWidth(s, barW, pad)
    local w = (tonumber(barW) or 0) - 2 * (tonumber(pad) or 0)
    if s and s.nameShow then
        local other = (s.timeShow and s.timePoint ~= s.namePoint) or (s.stacksShow and s.stacksPoint ~= s.namePoint)
        if other then w = w * 0.62 end
    end
    if w < 1 then w = 1 end
    return w
end

-- 冷卻列：GetSpellCooldown 的明文旗標 → "active"（真的在冷卻）｜"idle"（沒在冷卻、或只是 GCD）｜nil（讀不到）
-- isSecret(v)：呼叫端給的秘密值判斷（測試用 stub）。只認明文布林
function CB.CooldownState(info, isSecret)
    if type(info) ~= "table" then return nil end
    local gcd, active = info.isOnGCD, info.isActive
    if isSecret and (isSecret(gcd) or isSecret(active)) then return nil end
    if gcd == true then return "idle" end
    if active == false then return "idle" end
    if active == true then return "active" end
    return nil
end

-- 充能列：GetSpellCharges 的 isActive（NeverSecret；回充中）→ "active"｜"idle"｜nil
function CB.ChargeState(info, isSecret)
    if type(info) ~= "table" then return nil end
    local a = info.isActive
    if isSecret and isSecret(a) then return nil end
    if a == true then return "active" elseif a == false then return "idle" end
    return nil
end

-- 冷卻列這一次的透明度：數字 ＝ 直接 SetAlpha；nil ＝ Lua 決定不了，改交引擎（duration:IsZero → SetAlphaFromBoolean）
function CB.CooldownAlpha(showWhen, state)
    if showWhen ~= "active" then return 1 end
    if state == "active" then return 1 elseif state == "idle" then return 0 end
    return nil
end

-- 光環類交給 AuraBar.Apply 的 spec（look：Look() 解好的純數字與字串；g：CB.Geometry 的結果）
function CB.AuraSpec(plan, look, g)
    local st = plan.st
    local a = CB.AURA[plan.kind] or CB.AURA.buff
    local spec = {
        kind = "duration", unit = a.unit, filter = a.filter, spellIDs = { plan.spellID }, max = 1,
        texture = look.texture, color = { r = look.r, g = look.g, b = look.b }, alpha = look.alpha,
        reversed = st.reverse,
    }
    local off = { 0, look.offY or 0 }
    if st.timeShow then
        spec.text = { font = look.font, size = look.sizePx, outline = look.outline, decimals = st.decimals,
                      point = st.timePoint, pad = look.padPx, off = off }
        if st.lowOn then
            local c = st.lowColor
            spec.text.low = { below = st.lowBelow, r = c.r, g = c.g, b = c.b, a = 1 }
        end
    end
    if st.stacksShow then
        spec.count = { font = look.font, size = look.sizePx, outline = look.outline, mode = "stacks", plain = true,
                       point = st.stacksPoint, pad = look.padPx, off = off }
    end
    if st.showWhen ~= "active" and st.nameShow and st.nameWhen == "active" then
        -- 一直顯示的列、名字只在光環在時出現：名字單獨建在按鈕子樹裡（按鈕只在光環存在時顯示），圖示照舊畫在列上
        spec.label = { name = look.name, font = look.font, size = look.sizePx, outline = look.outline,
                       point = st.namePoint, pad = look.padPx, w = look.nameWpx, off = off }
    end
    if st.showWhen == "active" then
        -- 只在生效時顯示：暗底、邊框、名字、圖示全建在按鈕子樹裡
        spec.inside = { W = g.barW, H = g.H, n = 1, gap = 0, segW = g.barW, segments = false, reversed = st.reverse,
                        dim = look.dim, px = look.px, edge = look.edge, bgTex = look.bgTex }
        local hasIcon = st.icon ~= "none" and look.iconFile ~= nil
        if st.nameShow or hasIcon then
            spec.label = {
                name = st.nameShow and look.name or nil, font = look.font, size = look.sizePx, outline = look.outline,
                point = st.namePoint, pad = look.padPx, w = look.nameWpx, off = off,
                icon = hasIcon and look.iconFile or nil, side = st.icon, isize = g.H, gap = g.gap,
                border = look.px, edge = look.edge,
            }
        end
    end
    return spec
end

-- 光環類要登記的出現／消失音效（Core/Sound.lua 的 WantAuraSounds 收）：純函式版，吃 plans
function CB.SoundWantsOf(plans)
    local out = {}
    for _, p in ipairs(plans or {}) do
        local a = p.aura and CB.AURA[p.kind]
        if a then
            if p.st.gainSound then out[#out + 1] = { what = "gain", spellID = p.spellID, name = p.st.gainSound, unit = a.unit } end
            if p.st.loseSound then out[#out + 1] = { what = "lose", spellID = p.spellID, name = p.st.loseSound, unit = a.unit } end
        end
    end
    return out
end

------------------------------------------------------------
-- 遊戲裡的查詢
------------------------------------------------------------
local function Plain(v)
    if v == nil or ns.IsSecret(v) then return nil end
    return v
end

local function Known(id)
    local book = C_SpellBook
    local any = false
    for _, fn in ipairs({ book and book.IsSpellKnown or false, book and book.IsSpellInSpellBook or false, _G.IsPlayerSpell or false }) do
        if fn then
            any = true
            local ok, v = pcall(fn, id)
            if ok and (ns.IsSecret(v) or v) then return true end
        end
    end
    return not any
end
local gameProbe = { known = Known }
CB.gameProbe = gameProbe

local function SpellName(id)
    local fn = C_Spell and C_Spell.GetSpellName
    if fn then
        local ok, n = pcall(fn, id)
        n = ok and Plain(n) or nil
        if type(n) == "string" and n ~= "" then return n end
    end
    return "#" .. tostring(id)
end

local function SpellIcon(id)
    local fn = C_Spell and C_Spell.GetSpellTexture
    if fn then
        local ok, t = pcall(fn, id)
        t = ok and Plain(t) or nil
        if t then return t end
    end
    return 134400
end

-- 這招現在是不是充能法術（上限 > 1；明文讀到才算，讀不到用上次記的，從沒讀到過當不是）
local chargeCache = {}
local function IsChargeSpell(id)
    local fn = C_Spell and C_Spell.GetSpellCharges
    if not fn then return false end
    local ok, info = pcall(fn, id)
    if not ok then return chargeCache[id] == true end
    if type(info) ~= "table" then
        chargeCache[id] = false
        return false
    end
    local okM, m = pcall(function() return info.maxCharges end)
    m = okM and Plain(m) or nil
    if type(m) == "number" then
        chargeCache[id] = m > 1
        return m > 1
    end
    return chargeCache[id] == true
end

local function TryDur(fn, ...)
    if not fn then return nil end
    local ok, d = pcall(fn, ...)
    if ok and d then return d end
    return nil
end

-- 零長度的 duration 物件（清空條身用；跟 Modules/Custom.lua 的長條同一招，哪一條真的清得掉待實機驗證）
local zeroDuo
local function ZeroDuration()
    if zeroDuo == nil then
        zeroDuo = false
        local U = C_DurationUtil
        if U and U.CreateDuration then
            local ok, d = pcall(U.CreateDuration)
            if ok and d then
                if d.SetTimeFromStart then pcall(d.SetTimeFromStart, d, 0, 0) end
                zeroDuo = d
            end
        end
    end
    return zeroDuo or nil
end

local function RemainingDir()
    local E = Enum and Enum.StatusBarTimerDirection
    return E and E.RemainingTime or nil
end

local function ImmediateInterp()
    local E = Enum and Enum.StatusBarInterpolation
    return E and E.Immediate or nil
end

------------------------------------------------------------
-- 框
------------------------------------------------------------
local container, root
local rows = {}                 -- 池化的列（frame 刪不掉）
local shown = 0
local plansNow = {}             -- 目前畫面上的規劃（音效登記、除錯用）
local pendingRelayout = false
local has = { aura = false, debuff = false, cooldown = false }
local SyncEvents                -- 事件那一段（前置宣告）
local Mark                      -- 同上

local function OnReady(cd)
    local row = cd.cbRow
    local plan = row and row.plan
    -- 身分閘：列被換成別的內容後，舊的倒數到期不能替新的那一列響
    if not (plan and plan.kind == "cooldown" and cd.cbID == plan.spellID and row.cdArmed) then return end
    row.cdArmed = false
    local name = plan.st.readySound
    if name and ns.Sound and ns.Sound.Play then
        ns.Sound.Play(name, "cbar:" .. tostring(plan.spellID), "custombar ready")
    end
    Mark(false)
end

local function MakeRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.bar = CreateFrame("Frame", nil, row)           -- 條身的範圍（圖示以外）
    row.iconFrame = row:CreateTexture(nil, "BACKGROUND")
    row.iconFrame:SetColorTexture(0, 0, 0, 1)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.textFrame = CreateFrame("Frame", nil, row)
    row.textFrame:SetAllPoints(row.bar)
    row.name = row.textFrame:CreateFontString(nil, "OVERLAY")
    ns.Media.SetPixelFont(row.name, 10, "OUTLINE")     -- 先給字型才能 SetText（樣式在排版時重套）
    row.name:SetWordWrap(false)
    row.ab, row.abDecor, row.cdBar, row.cd = false, false, false, false
    row:Hide()
    return row
end

-- 冷卻列的條身與秒數（懶建）
local function EnsureCooldownParts(row)
    if row.cdBar then return end
    local bar = CreateFrame("StatusBar", nil, row.bar)
    bar:SetAllPoints(row.bar)
    bar:SetMinMaxValues(0, 1)                          -- 起始值：之後由 SetTimerDuration 的引擎接手
    bar:SetValue(0)
    row.cdBar = bar
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, row.bar, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints(row.bar)
        if cd.SetDrawSwipe then cd:SetDrawSwipe(false) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
        if fs then ns.Media.SetPixelFont(fs, 10, "OUTLINE") end
        cd.cbRow = row
        -- 自己的框：轉好那一刻（冷卻好了音效）。零長度物件被 clearIfZero 清掉不會觸發
        cd:SetScript("OnCooldownDone", OnReady)
        row.cd = cd
    end
end

local function HideCooldownParts(row)
    if row.cdBar then row.cdBar:Hide() end
    if row.cd then
        row.cd:Clear()
        row.cd:Hide()
    end
    row.cdArmed = false
end

-- 這一列的外觀解成純數字與字串（AuraSpec 與列上的東西都吃這張）
local function Look(style, plan, g)
    local st = plan.st
    local R = ns.Resources
    local cr, cg, cb = ns.Style.Accent()
    local r, gg, b = CB.FillColor(st, cr, cg, cb)
    local scale = UIParent:GetEffectiveScale()
    if not scale or scale <= 0 then scale = 1 end
    local token = ns.Media.ElementFont(style.textFont, ns.Setting(nil, "font"))
    -- 暗底：自訂底色 ＞ 填色 × 0.25（同資源條的連續條），alpha 乘背景不透明度
    local m = R.BgAlpha(style)
    local bc = R.BgCustom(style)
    local dim = bc and { bc.r, bc.g, bc.b, 0.8 * m } or { r * 0.25, gg * 0.25, b * 0.25, 0.8 * m }
    local _, oy = R.TextOffset(style)
    return {
        r = r, g = gg, b = b, alpha = tonumber(style.barAlpha) or 1,
        texture = ns.Media.Texture(style.texture), bgTex = R.BgTexture(style),
        dim = dim, px = R.DecorPx(style), edge = R.EdgeArray(style),
        token = token, font = ns.Media.Font(token), outline = R.TextOutline(style),
        size = st.textSize, sizePx = st.textSize * scale,
        pad = CB.TEXT_PAD, padPx = CB.TEXT_PAD * scale, offY = oy, scale = scale,
        name = SpellName(plan.spellID), iconFile = SpellIcon(plan.spellID),
        nameW = CB.NameWidth(st, g.barW, CB.TEXT_PAD), nameWpx = CB.NameWidth(st, g.barW, CB.TEXT_PAD) * scale,
    }
end

CB.Look = Look                        -- 設定頁的預覽框用同一套外觀（Options/ResourcePreview.lua）

local function PlaceText(fs, parent, point, look)
    fs:ClearAllPoints()
    fs:SetJustifyH(point)
    local pad = (point == "LEFT" and look.padPx) or (point == "RIGHT" and -look.padPx) or 0
    fs:SetPoint(point, parent, point, pad, look.offY)
end

-- 列上的東西（一直顯示的列；「只在生效時顯示」的光環列整組藏起來，改建在按鈕子樹裡）
local function LayoutRowParts(row, plan, look, g, inside)
    local st = plan.st
    -- 圖示：框色＝邊框色、圖示內縮邊框粗細（邊框 0 ＝ 貼滿）
    local showIcon = st.icon ~= "none" and not inside
    if showIcon then
        row.iconFrame:ClearAllPoints()
        row.iconFrame:SetPoint("TOPLEFT", row, "TOPLEFT", g.iconX, 0)
        row.iconFrame:SetSize(g.iconW, g.H)
        local e = look.edge
        row.iconFrame:SetColorTexture(e[1], e[2], e[3], e[4])
        row.icon:ClearAllPoints()
        row.icon:SetPoint("TOPLEFT", row.iconFrame, "TOPLEFT", look.px, -look.px)
        row.icon:SetPoint("BOTTOMRIGHT", row.iconFrame, "BOTTOMRIGHT", -look.px, look.px)
        row.icon:SetTexture(look.iconFile)
        row.iconFrame:Show()
        row.icon:Show()
    else
        row.iconFrame:Hide()
        row.icon:Hide()
    end
    -- 光環列的名字設成只在生效時出現 ⇒ 建在按鈕子樹裡（CB.AuraSpec 的 label），列上不畫
    if st.nameShow and not inside and not (plan.aura and st.nameWhen == "active") then
        ns.Media.SetPixelFont(row.name, look.size, look.outline, look.token)
        row.name:SetTextColor(1, 1, 1, 1)
        row.name:SetWidth(look.nameWpx)
        PlaceText(row.name, row.bar, st.namePoint, look)
        row.name:SetText(look.name)
        row.name:Show()
    else
        row.name:SetText("")
        row.name:Hide()
    end
    if inside then
        ns.AuraBar.HideRowDecor(row.bar)
    else
        ns.AuraBar.RowDecor(row.bar, { W = g.barW, H = g.H, n = 1, gap = 0, segW = g.barW, segments = false,
            reversed = st.reverse, dim = look.dim, px = look.px, edge = look.edge, bgTex = look.bgTex },
            (row:GetFrameLevel() or 1) + 8)
    end
end

-- 冷卻列：條身、秒數的樣式（值在 UpdateCooldown）
local function LayoutCooldown(row, plan, look)
    local st = plan.st
    EnsureCooldownParts(row)
    local lv = row:GetFrameLevel() or 1
    local bar = row.cdBar
    bar:SetFrameLevel(lv + 2)
    bar:SetStatusBarTexture(look.texture)
    bar:SetReverseFill(st.reverse)
    local t = bar:GetStatusBarTexture()
    if t then t:SetVertexColor(look.r, look.g, look.b, look.alpha) end
    bar:Show()
    local cd = row.cd
    if cd then
        cd:SetFrameLevel(lv + 10)
        cd.cbID = plan.spellID
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(not st.timeShow) end
        local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
        if fs then
            ns.Media.SetPixelFont(fs, look.size, look.outline, look.token)
            fs:SetTextColor(1, 1, 1, 1)
            PlaceText(fs, row.bar, st.timePoint, look)
        end
        -- 小數門檻＋低秒變色（格式字串包色碼）：Core/Text.lua 同一支
        local fmt = ns.Text and ns.Text.CountdownFormatter and ns.Text.CountdownFormatter({
            decimalsBelow = st.decimals, lowColorOn = st.lowOn, lowBelow = st.lowBelow, lowColor = st.lowColor })
        if fmt and cd.SetCountdownFormatter then pcall(cd.SetCountdownFormatter, cd, fmt) end
        if cd.SetCountdownMillisecondsThreshold then pcall(cd.SetCountdownMillisecondsThreshold, cd, 0) end
        cd:Show()
    end
end

local function LayoutRow(row, plan, style, W)
    local st = plan.st
    local H = ns.P.Scale(st.height)
    row:SetSize(W, H)
    row:SetAlpha(1)
    local g = CB.Geometry(W, H, st.icon, ns.P.Pixel(1))
    row.bar:ClearAllPoints()
    row.bar:SetPoint("TOPLEFT", row, "TOPLEFT", g.barX, 0)
    row.bar:SetSize(g.barW, H)
    row.textFrame:SetFrameLevel((row:GetFrameLevel() or 1) + 12)
    local look = Look(style, plan, g)
    local inside = plan.aura and st.showWhen == "active"
    LayoutRowParts(row, plan, look, g, inside)
    if plan.aura then
        HideCooldownParts(row)
        row.ab = row.ab or ns.AuraBar.New(row.bar, function() Mark(true) end)
        local status = ns.AuraBar.Apply(row.ab, CB.AuraSpec(plan, look, g))
        row.engineStatus = status
        if status ~= "ready" then ns.AuraBar.HideContainer(row.ab) end
        ns.AuraBar.KickPending(row.ab)
    else
        if row.ab then ns.AuraBar.HideContainer(row.ab) end
        row.engineStatus = nil
        LayoutCooldown(row, plan, look)
    end
end

------------------------------------------------------------
-- 冷卻列的值（SPELL_UPDATE_COOLDOWN／CHARGES、重排之後）
------------------------------------------------------------
local function ClearCooldown(row)
    local bar = row.cdBar
    if row.cd then row.cd:Clear() end
    row.cdArmed = false
    if not bar then return end
    local z = ZeroDuration()
    if z and bar.SetTimerDuration and pcall(bar.SetTimerDuration, bar, z, ImmediateInterp(), RemainingDir()) then
        CB.clearPath = "zero"
        return
    end
    pcall(bar.SetMinMaxValues, bar, 0, 1)
    pcall(bar.SetValue, bar, 0)
    CB.clearPath = "value"
end

local function UpdateCooldown(row)
    local plan = row.plan
    local id = plan.spellID
    local charges = IsChargeSpell(id)
    local state, dur
    if charges then
        local fn = C_Spell and C_Spell.GetSpellCharges
        local ok, info = false, nil
        if fn then ok, info = pcall(fn, id) end
        state = CB.ChargeState(ok and info or nil, ns.IsSecret)
        dur = TryDur(C_Spell and C_Spell.GetSpellChargeDuration, id)
    else
        local fn = C_Spell and C_Spell.GetSpellCooldown
        local ok, info = false, nil
        if fn then ok, info = pcall(fn, id) end
        state = CB.CooldownState(ok and info or nil, ns.IsSecret)
        -- 不含 GCD 的冷卻（ignoreGCD）：只是 GCD 時引擎給零長度，條不會閃
        dur = TryDur(C_Spell and C_Spell.GetSpellCooldownDuration, id, true)
    end
    row.cdState, row.cdCharges = state, charges
    if state == "idle" or not dur then
        ClearCooldown(row)
    else
        local bar = row.cdBar
        if not (bar and bar.SetTimerDuration and pcall(bar.SetTimerDuration, bar, dur, ImmediateInterp(), RemainingDir())) then
            row.feedFailed = true
        end
        local cd = row.cd
        if cd and cd.SetCooldownFromDurationObject and pcall(cd.SetCooldownFromDurationObject, cd, dur, true) then
            -- 明文確認在冷卻（或讀不到旗標）才武裝「冷卻好了」：只是 GCD 已經在上面清掉了
            row.cdArmed = true
        end
    end
    -- 整列（只在生效時顯示）與名字（只在冷卻中出現，名字在 textFrame 上）各自一個透明度，判準相同
    local st = plan.st
    local zero, zeroRead
    local function Apply(frame, showWhen)
        local a = CB.CooldownAlpha(showWhen, state)
        if a then frame:SetAlpha(a) return end
        -- 讀不到旗標：duration:IsZero() 是秘密布林，取得可以、測試不行 ⇒ 直接餵 SetAlphaFromBoolean
        if not zeroRead then
            zeroRead = true
            if dur and dur.IsZero then
                local ok, z = pcall(dur.IsZero, dur)
                if ok then zero = z end
            end
        end
        if (ns.IsSecret(zero) or zero ~= nil) and frame.SetAlphaFromBoolean and pcall(frame.SetAlphaFromBoolean, frame, zero, 0, 1) then return end
        frame:SetAlpha(1)          -- 什麼都讀不到：寧可顯示
    end
    Apply(row, st.showWhen)
    if row.textFrame then Apply(row.textFrame, st.nameWhen == "active" and "active" or "always") end
end

local function UpdateRows()
    for i = 1, shown do
        local row = rows[i]
        if row.plan and row.plan.kind == "cooldown" then
            local ok, err = xpcall(UpdateCooldown, ns.ReportError, row)
            if not ok then CB.lastError = err end
        end
    end
end

------------------------------------------------------------
-- 重排
------------------------------------------------------------
local function HideRows(from)
    for i = from, #rows do
        local row = rows[i]
        row:Hide()
        row.plan, row.engineStatus = nil, nil
        HideCooldownParts(row)
        if row.ab then ns.AuraBar.HideContainer(row.ab) end
        ns.AuraBar.HideRowDecor(row.bar)
    end
end

-- 光環列的 AuraContainer 讓面板變成保護框：戰鬥中不能 SetSize／SetPoint／Show／Hide 列 ⇒ 記旗標、脫戰補
local function MustDefer()
    return InCombatLockdown() and root ~= nil and ns.IsProtectedFrame and ns.IsProtectedFrame(root)
end

local function OnRegenRelayout()
    ns.Events.Unregister("PLAYER_REGEN_ENABLED", "custombars_relayout")
    if pendingRelayout then
        pendingRelayout = false
        Mark(true)
    end
end

local function DeferRelayout()
    pendingRelayout = true
    ns.Events.Register("PLAYER_REGEN_ENABLED", "custombars_relayout", OnRegenRelayout)
end

local function SoundSync()
    if ns.Sound and ns.Sound.RequestAuraSync then ns.Sound.RequestAuraSync() end
end

local function Relayout(style, W)
    local cfg = Cfg()
    W = ns.P.Scale(W)
    local gap = ns.P.Scale(tonumber(style.rowSpacing) or 1)
    local plans = CB.Plan(style, ns.specID, gameProbe)
    local heights = {}
    for i, plan in ipairs(plans) do heights[i] = ns.P.Scale(plan.st.height) end
    local offsets = CB.RowOffsets(heights, gap)
    local down = CB.Grow(cfg and cfg.anchor) == "down"
    has.aura, has.debuff, has.cooldown = false, false, false
    for i, plan in ipairs(plans) do
        local row = rows[i]
        if not row then
            row = MakeRow(root)
            rows[i] = row
        end
        row.plan = plan
        if plan.aura then has.aura = true end
        if plan.kind == "debuff" then has.debuff = true end
        if plan.kind == "cooldown" then has.cooldown = true end
        row:ClearAllPoints()
        if down then
            row:SetPoint("TOPLEFT", root, "TOPLEFT", 0, -offsets[i])
        else
            row:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, offsets[i])
        end
        row:Show()
        LayoutRow(row, plan, style, W)
    end
    HideRows(#plans + 1)
    shown = #plans
    plansNow = plans
    SyncEvents()
    SoundSync()
    -- 「只在生效時顯示」的列照樣佔位（12.1 讀不到按鈕顯不顯示）
    ns.Bars.SetPanelSize(KEY, W, CB.PanelHeight(heights, gap))
end

local laidOut = false

-- force：重排（清單、尺寸、樣式、寬度都可能變了）。不給 ＝ 只重畫冷卻列的值
function CB.Update(force)
    if not root then return end
    local cfg, style = Cfg(), StyleCfg()
    if not cfg or cfg.enabled == false or not style then
        if MustDefer() then DeferRelayout() return end
        HideRows(1)
        local had = shown > 0
        shown = 0
        plansNow = {}
        has.aura, has.debuff, has.cooldown = false, false, false
        SyncEvents()
        if had then SoundSync() end
        laidOut = false
        -- 關著也收合：施法條改貼資源條
        ns.Bars.SetPanelSize(KEY, ns.P.Scale(ns.Resources.Width(style, KEY)), 0)
        return
    end
    if force or not laidOut then
        if MustDefer() then
            DeferRelayout()
        else
            Relayout(style, ns.Resources.Width(style, KEY))
            laidOut = true
        end
    end
    UpdateRows()
end

-- 目前畫面上的光環列要登記的音效（Core/Sound.lua 叫）
function CB.SoundWants()
    return CB.SoundWantsOf(plansNow)
end

------------------------------------------------------------
-- 事件：只標髒，下一幀做
------------------------------------------------------------
local dirtyRelayout, dirtyValues, dirtyTarget, armed = false, false, false, false

local function Flush()
    armed = false
    local re, va, tg = dirtyRelayout, dirtyValues, dirtyTarget
    dirtyRelayout, dirtyValues, dirtyTarget = false, false, false
    if tg then
        -- 目標減益：換目標時容器不會自己重掃（只聽 UNIT_AURA）
        for i = 1, shown do
            local row = rows[i]
            if row.plan and row.plan.kind == "debuff" and row.ab then ns.AuraBar.Refresh(row.ab) end
        end
    end
    if re then
        CB.Update(true)
    elseif va then
        CB.Update(false)
    end
end

-- what：true ＝ 重排；"target" ＝ 目標換了；其他 ＝ 只重畫值
Mark = function(what)
    if what == true then dirtyRelayout = true
    elseif what == "target" then dirtyTarget = true
    else dirtyValues = true end
    if not armed then
        armed = true
        ns.Defer(Flush)
    end
end
CB.Mark = Mark

local RELAYOUT_EVENTS = {
    SPELLS_CHANGED = true, PLAYER_TALENT_UPDATE = true, TRAIT_CONFIG_UPDATED = true,
    PLAYER_SPECIALIZATION_CHANGED = true, PLAYER_ENTERING_WORLD = true,
}
local COOLDOWN_EVENTS = { SPELL_UPDATE_COOLDOWN = true, SPELL_UPDATE_CHARGES = true }

local evFrame
local evCooldown, evTarget = false, false

local function OnEvent(_, event)
    if RELAYOUT_EVENTS[event] then Mark(true)
    elseif event == "PLAYER_TARGET_CHANGED" then Mark("target")
    else Mark(false) end
end

SyncEvents = function()
    if not evFrame then return end
    local wantCd = has.cooldown and true or false
    if wantCd ~= evCooldown then
        evCooldown = wantCd
        for e in pairs(COOLDOWN_EVENTS) do
            if wantCd then evFrame:RegisterEvent(e) else evFrame:UnregisterEvent(e) end
        end
    end
    local wantTarget = has.debuff and true or false
    if wantTarget ~= evTarget then
        evTarget = wantTarget
        if wantTarget then evFrame:RegisterEvent("PLAYER_TARGET_CHANGED") else evFrame:UnregisterEvent("PLAYER_TARGET_CHANGED") end
    end
end

local function RegisterEvents()
    if evFrame then return end
    evFrame = CreateFrame("Frame")
    evFrame:RegisterUnitEvent("PLAYER_SPECIALIZATION_CHANGED", "player")
    for _, e in ipairs({ "SPELLS_CHANGED", "PLAYER_TALENT_UPDATE", "TRAIT_CONFIG_UPDATED", "PLAYER_ENTERING_WORLD" }) do
        evFrame:RegisterEvent(e)
    end
    evFrame:SetScript("OnEvent", OnEvent)
end

------------------------------------------------------------
-- 初始化（ns.StartEngine：Pips 之後）
------------------------------------------------------------
local function MinSize()
    local style = StyleCfg() or {}
    return ns.Resources.Width(style, KEY), CB.HEIGHT_DEFAULT
end

function CB.Init()
    if container then return end
    container = ns.Bars.RegisterPanel(KEY, {
        anchorPoint = "BOTTOM",               -- 貼在資源條上方、往上長，列數增減時下緣不動
        collapsible = true,                   -- 沒有列 ＝ 收合（不佔位，施法條接到資源條上）
        minSize     = MinSize,
        relayout    = function() CB.Update(true) end,
    })
    root = CreateFrame("Frame", nil, container)
    root:SetAllPoints(container)
    RegisterEvents()
    ns.RegisterCallback("FirstRowWidthChanged", KEY, function()
        local style = StyleCfg()
        if style and (tonumber(style.width) or 0) <= 0 then Mark(true) end
    end)
    ns.RegisterCallback("ProfileChanged", KEY, function() Mark(true) end)
    ns.RegisterCallback("SpecChanged", KEY, function() Mark(true) end)
    -- 錨定改了（設定頁、編輯模式拖了脫離錨定）：往上長還是往下長可能跟著變
    ns.RegisterCallback("AnchorChanged", KEY, function(key) if key == KEY then Mark(true) end end)
    ns.RegisterCallback("BarMoved", KEY, function(key) if key == KEY then Mark(true) end end)
    CB.Update(true)
end

-- 設定頁改了值（清單、每列設定、資源條的樣式、這裡的位置／錨定／淡出）：重排＋結構＋ alpha
function CB.Apply()
    if not container then return end
    CB.Update(true)
    if InCombatLockdown() then ns.Bars.Request(KEY, "structure") else ns.Bars.ApplyStructure(KEY) end
    if ns.Visibility then ns.Visibility.Apply(KEY) end
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
function CB.RowFrame(i)
    if type(i) ~= "number" or i < 1 or i > shown then return nil end
    return rows[i]
end

local KIND_TEXT = { buff = "增益", debuff = "目標減益", cooldown = "冷卻" }

function CB.DebugLines()
    local out = {}
    if not container then
        out[1] = "  自訂列：沒有初始化"
        return out
    end
    local cfg, style = Cfg(), StyleCfg()
    local list = CB.List(style, ns.specID)
    local h = container.GetHeight and container:GetHeight()
    local a = type(cfg) == "table" and cfg.anchor
    local where = type(a) == "table" and ("錨 %s %s→%s"):format(tostring(a.to), tostring(a.point), tostring(a.relPoint)) or "自己的位置"
    out[#out + 1] = ("  自訂列：%s  專精 %s  清單 %d 筆  顯示 %d 列  高 %s  %s（%s）  收合 %s  alpha %s  事件 冷卻 %s／換目標 %s%s")
        :format((cfg and cfg.enabled ~= false) and "開" or "關", tostring(ns.specID), list and #list or 0, shown,
            tostring(Plain(h)), where, CB.Grow(a) == "down" and "往下長" or "往上長",
            tostring(ns.Bars.IsCollapsed and ns.Bars.IsCollapsed(KEY)), tostring(ns.Visibility and ns.Visibility.Current(KEY)),
            evCooldown and "開" or "關", evTarget and "開" or "關", pendingRelayout and "  （戰鬥中，重排延到脫戰）" or "")
    for i, e in ipairs(list or {}) do
        local row
        for j = 1, shown do
            if rows[j].plan and rows[j].plan.index == i then row = rows[j] end
        end
        local kind = type(e) == "table" and (KIND_TEXT[e.kind] or tostring(e.kind)) or "?"
        local id = type(e) == "table" and tostring(e.spellID) or "?"
        if row then
            local extra
            if row.plan.aura then
                local bound = row.ab and ns.AuraBar.Bound(row.ab)
                extra = ("容器 %s／交條 %s"):format(tostring(row.engineStatus),
                    bound == true and "是" or bound == false and "失敗" or "未知")
            else
                extra = ("狀態 %s  充能 %s  武裝 %s  清空走 %s"):format(tostring(row.cdState), tostring(row.cdCharges),
                    tostring(row.cdArmed), tostring(CB.clearPath))
            end
            out[#out + 1] = ("    自訂列 %d. %s spellID %s  高 %d  顯示 %s  %s"):format(i, kind, id, row.plan.st.height,
                row.plan.st.showWhen == "active" and "生效時" or "一直", extra)
            if row.plan.aura and row.ab and ns.AuraBar.DebugLines then
                for _, line in ipairs(ns.AuraBar.DebugLines(row.ab, row.plan.kind == "buff" and { e.spellID } or nil)) do
                    out[#out + 1] = line
                end
            end
        else
            local why
            if type(e) ~= "table" or not KINDS[e.kind] or type(e.spellID) ~= "number" then why = "壞資料"
            elseif cfg and cfg.enabled == false then why = "自訂列關著"
            elseif e.enabled == false then why = "關閉"
            elseif e.kind == "cooldown" and not Known(e.spellID) then why = "法術未學會"
            else why = "沒有建列" end
            out[#out + 1] = ("    （自訂列 %d. %s spellID %s）%s"):format(i, kind, id, why)
        end
    end
    if CB.lastError then out[#out + 1] = "    最近錯誤：" .. tostring(CB.lastError) end
    return out
end
