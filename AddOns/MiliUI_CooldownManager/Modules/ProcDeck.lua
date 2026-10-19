------------------------------------------------------------
-- 觸發牌堆：增強薩（263）四個「洗好的一疊牌」型觸發——暴風雨、末日之風、風暴釋放、深根元素
--
-- 這幾個觸發不是每次獨立擲骰：每花掉一層氣漩武器就從一疊牌翻一張，一疊裡固定幾張是觸發，翻完重洗。
-- 所以「這疊翻到哪、還剩幾個觸發、下一發花 N 層會中的機率」算得出來。沒有任何 API 回牌堆位置，
-- 全部是我們自己數的：花了幾層（氣漩武器的光環）、中了沒（觸發訊號）。
--
-- 牌堆（數字、訊號、視窗是參考來源實測的結論，這裡只抄常數）：
--   暴風雨      100 張／2 個觸發；訊號 SPELL_UPDATE_COOLDOWN 帶 454015（暴風雨增益），跟花層**同一幀**、視窗 5ms。
--               覺醒風暴也會給同一個增益，但不在花層那一幀 ⇒ 視窗本身就是分辨器，不要放寬
--   末日之風    600 張／3 個觸發；訊號 224127（劈啪湧動：末日之風召喚的自然狼身上的增益），**晚 85～138ms 才到**、
--               視窗 250ms；昇華期間凍結不翻牌；硬讀末日之風（384352）後 0.5 秒內的那一隻不算（那是手按的）。
--               ⚠ 要有點「滾雷」或「野性狼魂」才有狼可以當訊號；沒點的話這疊永遠不會中，翻完就漂移（不另外閘）
--   風暴釋放    250 張／5 個觸發；訊號 1252413（觸發法術本身；增益 1262830 每次層數變動都報、分不出方向，不能用），
--               同一幀、視窗 50ms
--   深根元素    333 張／2 個觸發；訊號 378270 或 114051（昇華），同一幀、視窗 5ms
--
-- 天賦（學了才追蹤；判斷照 Catalog.TalentKnown，讀不到 ⇒ 照追蹤）：wago.tools 的 TraitNodeEntry → TraitDefinition
-- 對過——暴風雨 454009（entry 117489 → definition 122501）、末日之風 384352、風暴釋放 1262713、深根元素 378270
-- （entry 101816 → definition 106894）。
--
-- 「花掉幾層」（PD.MSW）：
--   * UNIT_AURA（player）時重讀 GetPlayerAuraBySpellID(344179)。payload **一個都不讀**（12.1 受限內容裡向量是秘密的、
--     ipairs 會拋）；也**不存 auraInstanceID**（可能是秘密值）。有沒有表是明文；applications 過 IsSecret，讀不到當 0
--     （＝不知道；消失時當 10）
--   * 有→沒有，而且 0.3 秒內有花費者的施放成功（閃電箭、閃電鏈、原始風暴、暴風雨；末日之風期間風暴打擊／狂風打擊／
--     雷擊也算）⇒ 花掉＝消失前快取的層數；沒有花費者 ⇒ 到期，不翻牌
--   * 都有、層數兩次都是明文而且往下掉、0.3 秒內有花費者 ⇒ 同一批事件裡「花光又疊回來」：花掉＝舊的層數
--     （花費者一次吃光全部層數，掉下去只可能是疊回來）。層數讀不到時這種情況看不出來、會漏算（探針記次數）
--   * 昇華（114051 施放／114049）15 秒內末日之風那疊凍結；末日之風施放後 10 秒內近戰三招算花費者
--
-- 觸發訊號跟花層的先後：同一幀裡誰先到不一定 ⇒ 花層開一個視窗等觸發；觸發先到就記下時間，同一幀稍後的花層直接認領。
-- 一次花層最多算一個觸發。翻過這疊尾端的那一次花層，觸發算**剛翻完的那一疊**（它還有觸發沒中的話），否則算新的一疊。
--
-- 漂移：一疊翻完、觸發數不對 ⇒ 下一疊整疊標成漂移（文字變灰「?」，提醒這疊的位置不準），再下一次重洗照數字重新判斷；
-- 一疊裡中的比觸發數多 ⇒ 這疊立刻漂移。漂移沒辦法自動校正（沒有任何 API 回牌堆位置）。
--
-- 存檔：MiliUI_CooldownManager_DB.procdeck[角色][牌堆 key] ＝ { drawn, hit, deckNo, ticks, drift }（角色層、不在 profile：
-- 是追蹤進度不是設定，換設定檔不該跟著換）。/reload 後接著算；首領戰開始、鑰石開始歸零。
--
-- 兩種畫法（每個牌堆自己選，共用同一份狀態，切換不重算）：
--   overlay  疊在那個技能的冷卻格上：格子上緣或下緣一條細條＋一個角落的小字（這支檔尾）。找不到格子就不畫（不代畫格子）
--   row      資源條下方一個獨立面板（面板 key procdeck）裡一個牌堆一列（Modules/ProcDeckRows.lua）
--
-- 前半是純函式（時間、層數、事件全部從參數進來，沒有任何 WoW API）：Tests/ProcDeck_test.lua 離線測。
-- 後半（「遊戲裡才跑的」那條線之後）掛事件、讀寫存檔、畫 overlay。
--
--   PD.DEFS / PD.DefsFor(class, spec) / PD.Def(key)
--   PD.New() / PD.Reset(st) / PD.OnSpend(st, def, n, now, frozen) / PD.OnTrigger(st, def, now) / PD.OnHardcast(st, now)
--   PD.Remaining(st, def) / PD.Chance(size, procs, drawn, hit, spend) / PD.FormatChance(pct)
--   PD.State(st, def) / PD.Text(st, def, mode, spend) / PD.RowText(st, def, mode, spend)
--   PD.Snapshot(st) / PD.Restore(st, def, saved)
--   PD.List(cfg, specID, create) / PD.Entry(cfg, specID, key, create) / PD.Setting(entry) / PD.Color(s, state) / PD.Plan(...)
--   PD.MSW.New() / PD.MSW.OnCast(m, spellID, now) / PD.MSW.OnAura(m, present, apps, now) / PD.MSW.Frozen(m, now)
------------------------------------------------------------
local _, ns = ...

-- 關掉貼圖的像素貼齊（Core/Media.lua 的 ns.NoSnap；離線測試沒載 Media 時是空操作）
local function NoSnap(t) if ns.NoSnap then ns.NoSnap(t) end return t end

ns.ProcDeck = {}
local PD = ns.ProcDeck

PD.KEY = "procdeck"                    -- row 樣式的面板（Modules/ProcDeckRows.lua）

-- 順序＝設定頁卡片順序＝row 面板的列順序
-- cells：畫在哪個法術的冷卻格（overlay；照順序找第一個在冷卻管理器裡的）。name／icon：列與卡片的名字、圖示用哪個法術查
PD.DEFS = {
    { key = "tempest", class = "SHAMAN", spec = 263, size = 100, procs = 2,
      cells = { 452201 }, name = 452201, icon = 452201, talent = 454009,
      trigger = { 454015 }, window = 0.005 },
    { key = "doomwinds", class = "SHAMAN", spec = 263, size = 600, procs = 3,
      cells = { 384352 }, name = 384352, icon = 384352, talent = 384352,
      trigger = { 224127 }, window = 0.25, freezeInAscendance = true,
      hardcast = 384352, hardcastWindow = 0.5 },
    { key = "stormunleashed", class = "SHAMAN", spec = 263, size = 250, procs = 5,
      cells = { 1252413, 187874 }, name = 1252413, icon = 1252413, talent = 1262713,
      trigger = { 1252413 }, window = 0.05 },
    { key = "dre", class = "SHAMAN", spec = 263, size = 333, procs = 2,
      cells = { 114051 }, name = 378270, icon = 378270, talent = 378270,
      trigger = { 378270, 114051 }, window = 0.005 },
}

function PD.DefsFor(class, spec)
    local out = {}
    for _, def in ipairs(PD.DEFS) do
        if def.class == class and def.spec == spec then out[#out + 1] = def end
    end
    return out
end

function PD.Def(key)
    for _, def in ipairs(PD.DEFS) do
        if def.key == key then return def end
    end
    return nil
end

function PD.IsTrigger(def, spellID, baseSpellID)
    for _, id in ipairs(def.trigger) do
        if spellID == id or baseSpellID == id then return true end
    end
    return false
end

------------------------------------------------------------
-- 狀態機
--
--   st = { drawn（這疊翻了幾張）, hit（這疊中了幾個）, deckNo, ticks（這疊中的時候翻到第幾張，畫刻度）, drift,
--          lastProcAt, procThisSpend, pendingSpend = { at, n, snap, crossed, oldHit } | nil, hardcastAt, orphanAt }
------------------------------------------------------------
-- 觸發比花層早到時，只認同一幀（時間戳記一樣）的花層；不同幀的不算（末日之風的狼一律晚到，不能往回認）
local SAME_FRAME = 0.0005

function PD.New()
    return { drawn = 0, hit = 0, deckNo = 1, ticks = {}, drift = false,
             lastProcAt = nil, procThisSpend = false, pendingSpend = nil, hardcastAt = nil, orphanAt = nil }
end

function PD.Reset(st)
    st.drawn, st.hit, st.deckNo, st.ticks, st.drift = 0, 0, 1, {}, false
    st.lastProcAt, st.procThisSpend, st.pendingSpend, st.hardcastAt, st.orphanAt = nil, false, nil, nil, nil
end

-- 算進一個觸發（視窗、重複、硬讀都已經檢查過）
local function Credit(st, def, now)
    local p = st.pendingSpend
    st.procThisSpend = true
    st.lastProcAt = now
    if p.crossed and p.oldHit < def.procs then
        -- 翻過尾端的那次花層、剛翻完的那疊還有觸發沒中：它一定在這次翻掉的牌裡 ⇒ 算舊的那疊，
        -- 補完之後重新判斷新的這疊要不要標漂移
        p.oldHit = p.oldHit + 1
        st.drift = p.oldHit ~= def.procs
        return
    end
    st.hit = st.hit + 1
    st.ticks[#st.ticks + 1] = p.crossed and 0 or p.snap
    if st.hit > def.procs then st.drift = true end
end

-- 翻 n 張。frozen ＝ 這疊現在不翻（昇華期間的末日之風）。回 true ＝ 狀態變了
function PD.OnSpend(st, def, n, now, frozen)
    n = tonumber(n) or 0
    if frozen or n <= 0 then return false end
    local snap = st.drawn
    local total = snap + n
    local p = { at = now, n = n, snap = snap, crossed = false, oldHit = nil }
    if total >= def.size then
        -- 翻過尾端：一次最多花 10 層、一疊最少 100 張 ⇒ 最多跨一次
        p.crossed, p.oldHit = true, st.hit
        st.drift = st.hit ~= def.procs
        st.drawn = total - def.size
        st.hit = 0
        st.ticks = {}
        st.deckNo = st.deckNo + 1
    else
        st.drawn = total
    end
    st.pendingSpend = p
    st.procThisSpend = false
    -- 觸發比花層早到（同一幀）：直接認領
    if st.orphanAt and math.abs(now - st.orphanAt) <= SAME_FRAME then
        st.orphanAt = nil
        Credit(st, def, now)
    end
    st.orphanAt = nil
    return true
end

-- 觸發訊號。回 changed, 原因（"ok"｜"hardcast"｜"dup"｜"outside"｜"early"）
function PD.OnTrigger(st, def, now)
    if def.hardcast and st.hardcastAt and now - st.hardcastAt <= (def.hardcastWindow or 0) then
        return false, "hardcast"
    end
    if st.lastProcAt == now then return false, "dup" end
    local p = st.pendingSpend
    if p and now - p.at >= 0 and now - p.at <= def.window then
        if st.procThisSpend then return false, "dup" end
        Credit(st, def, now)
        return true, "ok"
    end
    -- 還沒有開著的視窗：可能是同一幀稍後才到的花層，記下來等它
    st.orphanAt = now
    return false, (p and "outside") or "early"
end

function PD.OnHardcast(st, now)
    st.hardcastAt = now
end

-- 這疊還剩幾張、還剩幾個觸發
function PD.Remaining(st, def)
    local N = def.size - st.drawn
    local P = def.procs - st.hit
    if N < 0 then N = 0 end
    if P < 0 then P = 0 end
    return N, P
end

-- 下一發花 spend 層至少中一個的機率（0～100）：超幾何。翻完這疊還有剩的，從一疊新的接著翻
function PD.Chance(size, procs, drawn, hit, spend)
    spend = math.floor(tonumber(spend) or 0)
    if spend <= 0 or size <= 0 then return 0 end
    local N = size - (drawn or 0)
    local P = procs - (hit or 0)
    if N < 0 then N = 0 end
    if P < 0 then P = 0 end
    if spend >= N then
        if P > 0 then return 100 end
        return PD.Chance(size, procs, 0, 0, spend - N)
    end
    if P == 0 then return 0 end
    if N - spend < P then return 100 end
    local miss = 1
    for j = 0, P - 1 do
        miss = miss * (N - spend - j) / (N - j)
    end
    return (1 - miss) * 100
end

-- 10% 以下一位小數（滿牌的末日之風是 4.9%，四捨五入到整數會把它會動的範圍全丟掉）
function PD.FormatChance(pct)
    pct = tonumber(pct) or 0
    if pct >= 99.95 then return "100%" end
    if pct <= 0 then return "0%" end
    if pct < 9.95 then return ("%.1f%%"):format(pct) end
    return ("%d%%"):format(math.floor(pct + 0.5))
end

-- 顏色用的狀態：滿牌（還沒中過）／用掉一部分／這疊的觸發用完了／漂移
function PD.State(st, def)
    if st.drift then return "drift" end
    if st.hit <= 0 then return "full" end
    if st.hit >= def.procs then return "spent" end
    return "partial"
end

PD.TEXT_MODES = { "chance", "position", "left" }

-- 格子角落的字（短）：機率「4.9%」｜位置「37/100」｜剩餘觸發數「2」；漂移一律「?」
function PD.Text(st, def, mode, spend)
    if st.drift then return "?" end
    if mode == "position" then return ("%d/%d"):format(st.drawn, def.size) end
    local _, P = PD.Remaining(st, def)
    if mode == "left" then return tostring(P) end
    return PD.FormatChance(PD.Chance(def.size, def.procs, st.drawn, st.hit, spend))
end

-- 列右側的字（有空間）：位置模式多帶剩餘觸發數「366/600 · 2」，其他同 PD.Text
function PD.RowText(st, def, mode, spend)
    if st.drift then return "?" end
    if mode == "position" then
        local _, P = PD.Remaining(st, def)
        return ("%d/%d · %d"):format(st.drawn, def.size, P)
    end
    return PD.Text(st, def, mode, spend)
end

-- 存檔用的一份（只存進度，視窗之類的瞬間狀態不存）
function PD.Snapshot(st)
    local ticks = {}
    for i, t in ipairs(st.ticks) do ticks[i] = t end
    return { drawn = st.drawn, hit = st.hit, deckNo = st.deckNo, ticks = ticks, drift = st.drift and true or nil }
end

-- 從存檔讀回（壞資料、超出範圍的退回新的一疊）
function PD.Restore(st, def, saved)
    PD.Reset(st)
    if type(saved) ~= "table" then return false end
    local drawn, hit, deckNo = tonumber(saved.drawn), tonumber(saved.hit), tonumber(saved.deckNo)
    if not (drawn and hit) or drawn < 0 or drawn >= def.size or hit < 0 then return false end
    st.drawn, st.hit = math.floor(drawn), math.floor(hit)
    st.deckNo = (deckNo and deckNo >= 1) and math.floor(deckNo) or 1
    if type(saved.ticks) == "table" then
        for _, t in ipairs(saved.ticks) do
            t = tonumber(t)
            if t and t >= 0 and t < def.size then st.ticks[#st.ticks + 1] = math.floor(t) end
        end
    end
    st.drift = saved.drift == true or st.hit > def.procs
    return true
end

------------------------------------------------------------
-- 設定（profile.resources.procDecks[specID][key]；開放式表，沒存的鍵一律當預設、不遷移）
--
--   entry = { on, style = "overlay"|"row", text = "chance"|"position"|"left", spend（1～10）,
--             colors = { full, partial, spent }（{ r, g, b, a }），ticks,
--             corner, edge, textSize（overlay）, height, icon, name（row）, collapsed（設定頁卡片） }
------------------------------------------------------------
PD.STYLES = { "overlay", "row" }
PD.CORNERS = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
PD.EDGES = { "bottom", "top" }
PD.SPEND_MIN, PD.SPEND_MAX, PD.SPEND_DEFAULT = 1, 10, 10
PD.TEXT_SIZE_MIN, PD.TEXT_SIZE_MAX, PD.TEXT_SIZE_DEFAULT = 8, 16, 11
PD.HEIGHT_MIN, PD.HEIGHT_MAX, PD.HEIGHT_DEFAULT = 8, 30, 16
PD.BAR_H = 4                           -- overlay 細條的高（實體像素）
PD.COLOR_KEYS = { "full", "partial", "spent" }
PD.DEFAULT_COLORS = {
    full    = { r = 0.36, g = 0.84, b = 0.36, a = 1 },
    partial = { r = 0.94, g = 0.77, b = 0.10, a = 1 },
    spent   = { r = 0.88, g = 0.28, b = 0.28, a = 1 },
}
PD.DRIFT_COLOR = { r = 0.54, g = 0.54, b = 0.54, a = 1 }

local STYLE_OK = { overlay = true, row = true }
local TEXT_OK = { chance = true, position = true, left = true }
local CORNER_OK = { TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true }

local function Clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

local function ValidRGBA(c)
    if type(c) ~= "table" then return nil end
    local r, g, b, a = tonumber(c.r), tonumber(c.g), tonumber(c.b), tonumber(c.a)
    if not (r and g and b) then return nil end
    return { r = Clamp(r, 0, 1), g = Clamp(g, 0, 1), b = Clamp(b, 0, 1), a = Clamp(a or 1, 0, 1) }
end

function PD.List(cfg, specID, create)
    if type(cfg) ~= "table" or specID == nil then return nil end
    local all = cfg.procDecks
    if type(all) ~= "table" then
        if not create then return nil end
        all = {}
        cfg.procDecks = all
    end
    local list = all[specID]
    if type(list) ~= "table" then
        if not create then return nil end
        list = {}
        all[specID] = list
    end
    return list
end

function PD.Entry(cfg, specID, key, create)
    local list = PD.List(cfg, specID, create)
    if not list then return nil end
    local e = list[key]
    if type(e) ~= "table" then
        if not create then return nil end
        e = {}
        list[key] = e
    end
    return e
end

-- 一個牌堆的設定解成生效值
function PD.Setting(entry)
    local e = type(entry) == "table" and entry or {}
    local s = {}
    s.on = e.on == true
    s.style = STYLE_OK[e.style] and e.style or "overlay"
    s.text = TEXT_OK[e.text] and e.text or "chance"
    s.spend = Clamp(math.floor(tonumber(e.spend) or PD.SPEND_DEFAULT), PD.SPEND_MIN, PD.SPEND_MAX)
    local c = type(e.colors) == "table" and e.colors or {}
    s.colors = {}
    for _, k in ipairs(PD.COLOR_KEYS) do
        local d = PD.DEFAULT_COLORS[k]
        s.colors[k] = ValidRGBA(c[k]) or { r = d.r, g = d.g, b = d.b, a = d.a }
    end
    s.ticks = e.ticks ~= false
    s.corner = CORNER_OK[e.corner] and e.corner or "TOPRIGHT"
    s.edge = (e.edge == "top") and "top" or "bottom"
    s.textSize = Clamp(math.floor(tonumber(e.textSize) or PD.TEXT_SIZE_DEFAULT), PD.TEXT_SIZE_MIN, PD.TEXT_SIZE_MAX)
    s.height = Clamp(math.floor(tonumber(e.height) or PD.HEIGHT_DEFAULT), PD.HEIGHT_MIN, PD.HEIGHT_MAX)
    s.icon = e.icon ~= false
    s.name = e.name ~= false
    s.collapsed = e.collapsed == true
    return s
end

-- 這個狀態的顏色 → r, g, b, a
function PD.Color(s, state)
    local c = (state == "drift") and PD.DRIFT_COLOR or (s.colors[state] or PD.DEFAULT_COLORS.full)
    return c.r, c.g, c.b, c.a or 1
end

-- 這個職業專精、這種樣式要畫哪些牌堆 → { { def, s }, … }（順序照 PD.DEFS；沒勾的不畫）
function PD.Plan(cfg, class, specID, style)
    local out = {}
    for _, def in ipairs(PD.DefsFor(class, specID)) do
        local s = PD.Setting(PD.Entry(cfg, specID, def.key))
        if s.on and s.style == style then out[#out + 1] = { def = def, s = s } end
    end
    return out
end

-- 刻度位置：這疊實際中的位置（0～1），最多 procs 個
function PD.TickFractions(st, def)
    local out = {}
    for i, t in ipairs(st.ticks) do
        if i > def.procs then break end
        out[i] = t / def.size
    end
    return out
end

------------------------------------------------------------
-- 「花掉幾層」偵測（氣漩武器 344179）
------------------------------------------------------------
PD.MSW = {}
local MSW = PD.MSW
MSW.AURA = 344179
MSW.SPENDERS = { [188196] = true, [188443] = true, [1218090] = true, [452201] = true }   -- 閃電箭、閃電鏈、原始風暴、暴風雨
MSW.DW_SPENDERS = { [17364] = true, [115356] = true, [187874] = true }                  -- 風暴打擊、狂風打擊、雷擊
MSW.ASCENDANCE = { [114051] = true, [114049] = true }
MSW.DOOM_WINDS = 384352
MSW.SPEND_WINDOW = 0.3
MSW.ASCEND_SECS = 15
MSW.DW_SECS = 10
MSW.UNKNOWN_SPEND = 10                 -- 層數讀不到時，消失算花掉幾層

function MSW.New()
    return { present = false, apps = 0, spender = nil, spenderAt = nil, ascUntil = 0, dwUntil = 0,
             regainSeen = 0, unknownDrops = 0 }
end

-- 施放成功 → 標籤（"spender"｜"ascendance"｜"doomwinds"｜nil）
function MSW.OnCast(m, spellID, now)
    if MSW.ASCENDANCE[spellID] then
        m.ascUntil = now + MSW.ASCEND_SECS
        return "ascendance"
    end
    if spellID == MSW.DOOM_WINDS then
        m.dwUntil = now + MSW.DW_SECS
        return "doomwinds"
    end
    if MSW.SPENDERS[spellID] or (MSW.DW_SPENDERS[spellID] and now < m.dwUntil) then
        m.spender, m.spenderAt = spellID, now
        return "spender"
    end
    return nil
end

local function RecentSpender(m, now)
    return m.spenderAt ~= nil and now - m.spenderAt >= 0 and now - m.spenderAt < MSW.SPEND_WINDOW
end

-- 光環重讀的結果。present：有沒有光環（明文）。apps：層數，0 ＝ 讀不到
-- 回 nil（沒事）｜{ spent = n }｜{ expired = n }｜{ gained = n }
function MSW.OnAura(m, present, apps, now)
    apps = tonumber(apps) or 0
    local was, old = m.present, m.apps
    m.present = present and true or false
    if present then m.apps = apps else m.apps = 0 end
    if was and not present then
        local n = (old and old > 0) and old or MSW.UNKNOWN_SPEND
        if RecentSpender(m, now) then
            m.spenderAt = nil
            return { spent = n }
        end
        return { expired = n }
    end
    if not was and present then return { gained = apps } end
    if was and present then
        if old > 0 and apps > 0 and apps < old and RecentSpender(m, now) then
            -- 同一批事件花光又疊回來（花費者一次吃光全部層數，往下掉只可能是這樣）
            m.spenderAt = nil
            m.regainSeen = m.regainSeen + 1
            return { spent = old }
        end
        if (old == 0 or apps == 0) and RecentSpender(m, now) then
            -- 層數讀不到：看不出來有沒有花光又疊回來（漏算的那一種，只記次數）
            m.unknownDrops = m.unknownDrops + 1
        end
    end
    return nil
end

function MSW.Frozen(m, now)
    return now < (m.ascUntil or 0)
end

------------------------------------------------------------
-- ======== 以下是遊戲裡才跑的（事件、存檔、overlay 畫面）========
------------------------------------------------------------
local PROBE_MAX = 30
PD.probe = { lines = {}, plain = { combat = 0, idle = 0 }, secret = { combat = 0, idle = 0 },
             castSecret = 0, appsSecret = 0, auraReads = 0, spends = 0, expires = 0 }

local function InCombat()
    local f = _G.InCombatLockdown
    return f and f() and true or false
end

local function ProbeLine(text)
    local p = PD.probe
    local t = _G.GetTime and _G.GetTime() or 0
    p.lines[#p.lines + 1] = ("%.3f %s %s"):format(t, InCombat() and "戰鬥" or "脫戰", text)
    while #p.lines > PROBE_MAX do table.remove(p.lines, 1) end
end
PD.ProbeLine = ProbeLine

local IsSecret = function(v) return ns.IsSecret and ns.IsSecret(v) end

local states = {}                      -- [def.key] ＝ 狀態
local msw = MSW.New()
PD.msw = msw

function PD.StateOf(key)
    return states[key]
end

local function ResCfg() return ns.DB and ns.DB.ConfigTable("resources") end

-- 這個專精的牌堆（UNIT_AURA／SPELL_UPDATE_COOLDOWN 很頻繁：照專精快取）
local specDefs, specDefsFor = {}, false
local function DefsForSpec()
    if specDefsFor ~= ns.specID then
        specDefs, specDefsFor = PD.DefsFor(ns.playerClass, ns.specID), ns.specID
    end
    return specDefs
end
PD.DefsForSpec = DefsForSpec

-- 天賦學了沒（讀不到 ⇒ 當學了：照追蹤）。換天賦時清快取
local talentCache = {}
function PD.Talented(def)
    if not def.talent then return true end
    local v = talentCache[def.talent]
    if v == nil then
        local C = ns.Catalog
        local k = C and C.TalentKnown and C.TalentKnown(def.talent)
        v = (k == false) and "no" or (k == true and "yes" or "unsure")
        talentCache[def.talent] = v
    end
    return v ~= "no", v
end

------------------------------------------------------------
-- 存檔
------------------------------------------------------------
local function SaveTable(create)
    local sv = _G.MiliUI_CooldownManager_DB
    if type(sv) ~= "table" then return nil end
    if type(sv.procdeck) ~= "table" then
        if not create then return nil end
        sv.procdeck = {}
    end
    local key = ns.DB and ns.DB.CharKey and ns.DB.CharKey()
    if not key then return nil end
    local t = sv.procdeck[key]
    if type(t) ~= "table" then
        if not create then return nil end
        t = {}
        sv.procdeck[key] = t
    end
    return t
end

local function Save(def)
    local st = states[def.key]
    local t = SaveTable(true)
    if st and t then t[def.key] = PD.Snapshot(st) end
end

local function Load()
    local t = SaveTable(false)
    for _, def in ipairs(PD.DEFS) do
        if def.class == ns.playerClass then
            local st = states[def.key] or PD.New()
            states[def.key] = st
            PD.Restore(st, def, t and t[def.key])
        end
    end
end

------------------------------------------------------------
-- 狀態變了 → 兩個畫家各自重畫（下一幀合併）
------------------------------------------------------------
local Render                           -- overlay（下面）
local changedArmed = false
local function FlushChanged()
    changedArmed = false
    if Render then Render() end
    if ns.ProcDeckRows and ns.ProcDeckRows.Paint then ns.ProcDeckRows.Paint() end
end

function PD.Changed()
    if changedArmed then return end
    changedArmed = true
    if ns.Defer then ns.Defer(FlushChanged) else FlushChanged() end
end

------------------------------------------------------------
-- 事件
------------------------------------------------------------
local function Active()
    return not ns.released and ns.playerClass == "SHAMAN" and DefsForSpec()[1] ~= nil
end

local function AuraRead()
    local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
    if not get then return false, 0 end
    local ok, a = pcall(get, MSW.AURA)
    if not ok or a == nil then return false, 0 end
    PD.probe.auraReads = PD.probe.auraReads + 1
    local okA, n = pcall(function() return a.applications end)
    if not okA or n == nil then return true, 0 end
    if IsSecret(n) then
        PD.probe.appsSecret = PD.probe.appsSecret + 1
        return true, 0
    end
    return true, tonumber(n) or 0
end

local function OnAura()
    if not Active() then return end
    local now = GetTime()
    local present, apps = AuraRead()
    local r = MSW.OnAura(msw, present, apps, now)
    if not r then return end
    if r.expired then
        PD.probe.expires = PD.probe.expires + 1
        ProbeLine(("氣漩武器到期 %d 層（不翻牌）"):format(r.expired))
        return
    end
    if not r.spent then return end
    PD.probe.spends = PD.probe.spends + 1
    local frozen = MSW.Frozen(msw, now)
    local any = false
    for _, def in ipairs(DefsForSpec()) do
        if PD.Talented(def) then
            local st = states[def.key] or PD.New()
            states[def.key] = st
            local fz = def.freezeInAscendance and frozen
            if PD.OnSpend(st, def, r.spent, now, fz) then
                any = true
                Save(def)
            end
        end
    end
    ProbeLine(("花掉 %d 層（花費者 %s）%s"):format(r.spent, tostring(msw.spender), frozen and "（昇華中：末日之風凍結）" or ""))
    if any then PD.Changed() end
end

local function OnCast(a2, a3)
    if not Active() then return end
    local spellID = a3
    if a3 == nil and type(a2) == "number" then spellID = a2 end
    if spellID == nil then return end
    if IsSecret(spellID) then
        PD.probe.castSecret = PD.probe.castSecret + 1
        return
    end
    local now = GetTime()
    local tag = MSW.OnCast(msw, spellID, now)
    for _, def in ipairs(DefsForSpec()) do
        if def.hardcast and spellID == def.hardcast then
            local st = states[def.key] or PD.New()
            states[def.key] = st
            PD.OnHardcast(st, now)
        end
    end
    if tag and tag ~= "spender" then ProbeLine(("施放 %d（%s）"):format(spellID, tag)) end
end

local REASON = { hardcast = "硬讀後略過", dup = "重複略過", outside = "視窗外略過", early = "先到、等花層" }

local function OnCooldown(spellID, baseSpellID)
    if not Active() then return end
    if IsSecret(spellID) or IsSecret(baseSpellID) then
        local p = PD.probe.secret
        if InCombat() then p.combat = p.combat + 1 else p.idle = p.idle + 1 end
        return
    end
    local now
    for _, def in ipairs(DefsForSpec()) do
        if PD.IsTrigger(def, spellID, baseSpellID) and PD.Talented(def) then
            now = now or GetTime()
            local p = PD.probe.plain
            if InCombat() then p.combat = p.combat + 1 else p.idle = p.idle + 1 end
            local st = states[def.key] or PD.New()
            states[def.key] = st
            local pend = st.pendingSpend
            local since = pend and (now - pend.at) or nil
            local changed, why = PD.OnTrigger(st, def, now)
            ProbeLine(("觸發 %s spellID=%s%s %s"):format(def.key, tostring(spellID),
                since and (" 距花層 %.0fms"):format(since * 1000) or "", changed and "算進" or (REASON[why] or why)))
            if changed then
                Save(def)
                PD.Changed()
            end
        end
    end
end

local function ResetAll(why)
    for _, def in ipairs(PD.DEFS) do
        local st = states[def.key]
        if st then
            PD.Reset(st)
            Save(def)
        end
    end
    ProbeLine("歸零（" .. why .. "）")
    PD.Changed()
end
PD.ResetAll = ResetAll

------------------------------------------------------------
-- overlay：疊在冷卻格上的細條＋角落小字（照 Modules/EchoWindow.lua 的畫法：全是自己的框，戰鬥中照畫）
------------------------------------------------------------
local WHITE = "Interface\\BUTTONS\\WHITE8X8"
local shown = {}                       -- shown[rec] ＝ 正在畫的 fx 框

local function Fx(rec)
    local ov = rec.overlay
    if not ov then return nil end
    local fx = rec.deckFx
    if not fx then
        fx = CreateFrame("Frame", nil, ov)
        fx:SetAllPoints(ov)
        -- 細條（實體像素高）、填色、1px 刻度都不貼齊
        fx.bg = NoSnap(fx:CreateTexture(nil, "BACKGROUND"))
        fx.bg:SetTexture(WHITE)
        fx.bg:SetVertexColor(0, 0, 0, 0.8)
        fx.bar = NoSnap(fx:CreateTexture(nil, "ARTWORK"))
        fx.bar:SetTexture(WHITE)
        fx.ticks = {}
        fx.text = fx:CreateFontString(nil, "OVERLAY")
        ns.Media.SetFont(fx.text, PD.TEXT_SIZE_DEFAULT, "OUTLINE")
        fx:Hide()
        rec.deckFx = fx
    end
    fx:SetFrameLevel(ov:GetFrameLevel() + 4)
    return fx
end

-- 格子的寬（錨定鏈牽到秘密錨點時讀回秘密值 ⇒ 這次不畫填色與刻度，下次再試）
local function PlainWidth(f)
    local ok, w = pcall(f.GetWidth, f)
    if not ok or IsSecret(w) or type(w) ~= "number" then return nil end
    return w
end

local function PaintFx(fx, def, s, st)
    local P = ns.P
    local h = P.Pixel(PD.BAR_H)
    local edge = s.edge == "top" and "TOP" or "BOTTOM"
    fx.bg:ClearAllPoints()
    fx.bg:SetPoint(edge .. "LEFT", fx, edge .. "LEFT", 0, 0)
    fx.bg:SetPoint(edge .. "RIGHT", fx, edge .. "RIGHT", 0, 0)
    fx.bg:SetHeight(h)
    local r, g, b, a = PD.Color(s, PD.State(st, def))
    local w = PlainWidth(fx)
    local frac = st.drawn / def.size
    if w and w > 0 and frac > 0 then
        fx.bar:ClearAllPoints()
        fx.bar:SetPoint(edge .. "LEFT", fx.bg, edge .. "LEFT", 0, 0)
        fx.bar:SetHeight(h)
        fx.bar:SetWidth(math.max(P.Pixel(1), w * frac))
        fx.bar:SetVertexColor(r, g, b, a)
        fx.bar:Show()
    else
        fx.bar:Hide()
    end
    local n = 0
    if s.ticks and w and w > 0 and not st.drift then
        for i, f in ipairs(PD.TickFractions(st, def)) do
            local t = fx.ticks[i]
            if not t then
                t = NoSnap(fx:CreateTexture(nil, "OVERLAY"))
                t:SetTexture(WHITE)
                t:SetVertexColor(1, 1, 1, 1)
                fx.ticks[i] = t
            end
            t:ClearAllPoints()
            t:SetPoint(edge .. "LEFT", fx.bg, edge .. "LEFT", math.floor(w * f + 0.5), 0)
            t:SetSize(P.Pixel(1), h)
            t:Show()
            n = i
        end
    end
    for i = n + 1, #fx.ticks do fx.ticks[i]:Hide() end
    ns.Media.SetFont(fx.text, s.textSize, "OUTLINE")
    fx.text:ClearAllPoints()
    local inset = 2
    local x = s.corner:find("LEFT") and inset or -inset
    local y = s.corner:find("TOP") and -inset or inset
    -- 角落跟細條同一邊：字往內讓出條的高
    if (s.corner:find("TOP") and edge == "TOP") then y = y - h
    elseif (s.corner:find("BOTTOM") and edge == "BOTTOM") then y = y + h end
    fx.text:SetPoint(s.corner, fx, s.corner, x, y)
    fx.text:SetTextColor(r, g, b, 1)
    fx.text:SetText(PD.Text(st, def, s.text, s.spend))
end

-- 這個牌堆畫在哪些格子上（照 cells 順序，第一個在冷卻管理器裡的法術）
function PD.CellEntries(def)
    local SI = ns.SpellIndex
    if not (SI and SI.Lookup) then return {}, nil end
    for _, id in ipairs(def.cells) do
        local list = SI.Lookup(id)
        if list[1] ~= nil then return list, id end
    end
    return {}, nil
end

Render = function()
    local want = {}
    local cfg = ResCfg()
    -- 總開關（profile.procdeck.enabled）兩種畫法一起管
    local panel = ns.DB and ns.DB.ConfigTable(PD.KEY)
    if Active() and cfg and not (panel and panel.enabled == false) then
        for _, item in ipairs(PD.Plan(cfg, ns.playerClass, ns.specID, "overlay")) do
            local def, s = item.def, item.s
            local st = states[def.key]
            if st and PD.Talented(def) then
                for _, e in ipairs((PD.CellEntries(def))) do
                    local fx = e.rec and Fx(e.rec)
                    if fx then
                        want[e.rec] = fx
                        PaintFx(fx, def, s, st)
                        fx:Show()
                    end
                end
            end
        end
    end
    for rec, fx in pairs(shown) do
        if not want[rec] then fx:Hide() end
    end
    shown = want
end
PD.Render = Render

-- 設定頁改了值：兩個畫家都重來
function PD.Apply()
    PD.Changed()
end

------------------------------------------------------------
-- 初始化（ns.StartEngine：CustomBars 之後）
------------------------------------------------------------
local inited = false
function PD.Init()
    if inited then return end
    inited = true
    -- 只有用得到的職業才聽（UNIT_AURA／SPELL_UPDATE_COOLDOWN 很頻繁）；專精不對時處理器第一行就走
    if not (ns.Events and ns.Events.Register and ns.playerClass == "SHAMAN") then return end
    Load()
    -- 登入時已經有的層數不算「獲得」：先讀一次當起點
    local present, apps = AuraRead()
    msw.present, msw.apps = present, present and apps or 0
    local E = ns.Events
    E.Register("UNIT_AURA", PD.KEY, function() OnAura() end, "player")
    E.Register("UNIT_SPELLCAST_SUCCEEDED", PD.KEY, function(_, a2, a3) OnCast(a2, a3) end, "player")
    E.Register("SPELL_UPDATE_COOLDOWN", PD.KEY, function(spellID, baseSpellID) OnCooldown(spellID, baseSpellID) end)
    E.Register("ENCOUNTER_START", PD.KEY, function() ResetAll("首領戰開始") end)
    E.Register("CHALLENGE_MODE_START", PD.KEY, function() ResetAll("鑰石開始") end)
    E.Register("PLAYER_ENTERING_WORLD", PD.KEY, function()
        Load()
        local p, n = AuraRead()
        msw.present, msw.apps = p, p and n or 0
        PD.Changed()
    end)
    local function Talents()
        talentCache = {}
        PD.Changed()
    end
    for _, ev in ipairs({ "TRAIT_CONFIG_UPDATED", "PLAYER_TALENT_UPDATE", "SPELLS_CHANGED" }) do
        E.Register(ev, PD.KEY, Talents)
    end
    -- ⚠ 回呼的 key 不能跟列的面板（Modules/ProcDeckRows.lua 用 "procdeck"）一樣：同一事件同一 key 會互相蓋掉
    if ns.RegisterCallback then
        ns.RegisterCallback("SpecChanged", "procdeck_state", Talents)
        ns.RegisterCallback("ProfileChanged", "procdeck_state", function() PD.Changed() end)
        -- 格子重建（認領變了）：rec 可能換了，重找
        ns.RegisterCallback("SpellIndexRebuilt", "procdeck_state", function() PD.Changed() end)
    end
    PD.Changed()
end

------------------------------------------------------------
-- 除錯：/mcdm deck（探針）、/mcdm debug（PD.DebugLines）
------------------------------------------------------------
function PD.DebugLines()
    local out = {}
    if ns.playerClass ~= "SHAMAN" then return out end
    local cfg = ResCfg()
    local defs = DefsForSpec()
    out[#out + 1] = ("  觸發牌堆：專精 %s  這個專精的牌堆 %d 個  氣漩武器 %s／%d 層  昇華凍結 %s"):format(tostring(ns.specID), #defs,
        msw.present and "在" or "不在", msw.apps, tostring(MSW.Frozen(msw, GetTime())))
    for _, def in ipairs(defs) do
        local st = states[def.key]
        local s = PD.Setting(PD.Entry(cfg, ns.specID, def.key))
        local _, tal = PD.Talented(def)
        local cells, id = PD.CellEntries(def)
        if st then
            out[#out + 1] = ("    %s：%s／%s  第 %d 疊 %d/%d 張 中 %d/%d  刻度 %s  漂移 %s  天賦 %s  格子 %s（%d 格）"):format(
                def.key, s.on and "開" or "關", s.style, st.deckNo, st.drawn, def.size, st.hit, def.procs,
                table.concat(st.ticks, ","), tostring(st.drift), tal, tostring(id), #cells)
        else
            out[#out + 1] = ("    %s：沒有狀態"):format(def.key)
        end
    end
    return out
end

function PD.ProbeReport()
    local p = PD.probe
    local out = {
        ("[米利冷卻 deck] 職業=%s 專精=%s 這個專精的牌堆=%d 個"):format(tostring(ns.playerClass), tostring(ns.specID), #DefsForSpec()),
        ("  觸發參數是明文：戰鬥中 %d 次、脫戰 %d 次"):format(p.plain.combat, p.plain.idle),
        ("  SPELL_UPDATE_COOLDOWN 參數是秘密值（不分法術）：戰鬥中 %d 次、脫戰 %d 次"):format(p.secret.combat, p.secret.idle),
        ("  氣漩武器：重讀 %d 次、層數是秘密值 %d 次、花掉 %d 次、到期 %d 次、花光又疊回 %d 次、層數讀不到看不出來 %d 次"):format(
            p.auraReads, p.appsSecret, p.spends, p.expires, msw.regainSeen, msw.unknownDrops),
        ("  施放事件的 spellID 是秘密值：%d 次"):format(p.castSecret),
    }
    if p.plain.combat == 0 and p.secret.combat > 0 then
        out[#out + 1] = "  ⚠ 戰鬥中沒看到明文的觸發、但有秘密參數 ⇒ 觸發參數戰鬥中可能是秘密值"
    end
    for _, line in ipairs(PD.DebugLines()) do out[#out + 1] = line end
    out[#out + 1] = "  最近的事件："
    if #p.lines == 0 then out[#out + 1] = "    （還沒有）" end
    for _, line in ipairs(p.lines) do out[#out + 1] = "    " .. line end
    if ns.Diag and ns.Diag.SaveDeck then ns.Diag.SaveDeck(out) end
    return out
end
