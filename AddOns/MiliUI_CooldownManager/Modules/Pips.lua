------------------------------------------------------------
-- 自訂格子：玩家自己加的「法術充能／光環層數」列，一組一列（獨立面板，容器 MiliUICDM_Bar_pips）
--
-- 資料與樣式都借資源條的：
--   * 清單：profile.resources.customRows[specID]（每個專精一份，設定頁在資源條頁）
--   * 樣式：列距、格距、材質、填充方向、填充透明度、寬度（0 ＝ 核心技能第一列）一律讀
--     profile.resources，不另開一組；**列高與顏色是每一列自己的**（entry.height／entry.color）
--   * 自己的只有 profile.pips：enabled、pos、anchor、fadeWithEssential、loadConditions、strata
-- 預設跟著核心技能下方（anchor TOP → essential BOTTOM），輔助技能也是：同一邊的自動排開
-- （Core/Layout.lua 的 StackTarget），格子在內、輔助在外 ⇒ 核心 → 自訂格子 → 輔助。
-- 沒有任何一列時面板收合（Bars 的 collapsible 面板：不佔位，輔助改貼核心），輔助就跟原本
-- 一樣貼在核心下方 1px；有列時輔助自動往下讓。
--
--   charges  法術充能。每格由下往上：
--              底色貼圖（BACKGROUND）
--              閘門 StatusBar（透明）：SetMinMaxValues(i-2, i-1)＋SetValue(目前充能數) ——
--                充能數 ≥ i-1 時是滿的，否則是空的
--              裁切框（SetClipsChildren）錨在閘門的**填充貼圖**上：閘門滿 ＝ 跟格子一樣大、空 ＝ 寬 0
--                ├ 回充條 StatusBar（錨在**格子**上、被裁切不是被壓扁）：SetTimerDuration(回充的 duration
--                │  物件)，引擎平滑填滿；顏色 ＝ 這一列的暗版
--                └ 秒數：一顆不畫扇形的 Cooldown（SetCooldownFromDurationObject 同一個物件），只留倒數字
--              填色 StatusBar：SetMinMaxValues(i-1, i)＋SetValue(目前充能數)，滿的格子蓋住下面全部
--            ⇒ 第 i 格已滿：填色蓋住；第 i 格是「下一格」（充能數 = i-1）：閘門滿、回充條看得到、平滑長；
--              更後面的空格：閘門空、什麼都沒有。全程不讀充能數（秘密值照樣對）。
--            ⚠ 閘門的填充貼圖幾何是秘密的（SetValue(秘密值)），錨在它上面的框會被傳染 ⇒ 只有裁切框錨在它上面，
--              裁切框底下的東西一律錨回格子；裁切框與它的子孫不讀任何幾何（GetWidth／GetSize／IsShown）。
--   stacks   光環層數。**引擎寫**：一顆單格 AuraContainer（Modules/AuraBar.lua），initializeFrame 裡把一條
--            整列寬的 StatusBar 交給按鈕的 SetApplicationBar ⇒ 引擎在安全端寫層數，首領戰／M+ 裡
--            GetPlayerAuraBySpellID 回 nil 也照樣對。格子外觀（暗底、黑邊、分隔）是另外畫的裝飾。
--            容器還沒建好（戰鬥中登入、建失敗）時退回明文路徑：GetPlayerAuraBySpellID().applications 直接餵
--            每格的 SetValue（讀不到整列半透明）。
--
-- 每列的顯示時機（entry.showWhen）：
--   always           一直顯示（預設）
--   active           charges：回充中（充能不滿）才顯示 —— GetSpellCharges().isActive 是明文布林（NeverSecret），
--                             讀不到時退回 GetSpellChargeDuration():IsZero()（秘密布林）餵 SetAlphaFromBoolean
--                    stacks：有這個光環才顯示 —— 裝飾與填色都建在按鈕子樹裡，按鈕只在有光環時顯示
--   activeOrCombat   charges 限定：回充中或戰鬥中
--   不是 always 的列照樣**佔位**（秘密值下不知道它現在顯不顯示）：面板高度只看有幾列。
--
-- 12.1 秘密值：值一律只轉手、不比較不算術（`x and v or 0` 這種會把秘密值當布林的式子一律改寫成 if）。
-- 格子一律錨在列上（不串在前一格）：SetValue(秘密值) 會讓填色條的幾何變秘密，錨在它身上的框會被傳染。
--
-- 保護：層數列的 AuraContainer 是受保護的 intrinsic，保護沿父層往上傳到列、面板 ⇒ 戰鬥中面板是保護框時
-- 不重排（記旗標、脫戰補做），只重畫值；面板容器的寫入本來就走 ns.Write。
--
-- 事件（SPELL_UPDATE_CHARGES／COOLDOWN、UNIT_AURA、進出戰鬥）只在真的有那一種列時才註冊，處理器只標髒、
-- 下一幀做（ns.Defer）。清單／格數／尺寸變了（專精、天賦、法術書、設定）才重排。
------------------------------------------------------------
local _, ns = ...

ns.Pips = {}
local Pips = ns.Pips

local R = ns.Resources
local RC = ns.ResCond
local MAX_SEGMENTS = RC.MAX_SEGMENTS
local SOLID = "Interface\\BUTTONS\\WHITE8X8"
local DIM = R.DIM
local Plain = R.Plain

local KEY = "pips"
-- 回充條由空長到滿（經過的時間）
local ELAPSED = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0

-- 自己的設定（位置、錨定、開關、淡出）與借來的樣式／清單（資源條那張表）
local function Cfg() return ns.DB and ns.DB.ConfigTable(KEY) end
local function StyleCfg() return ns.DB and ns.DB.ConfigTable("resources") end
Pips.Cfg, Pips.StyleCfg = Cfg, StyleCfg

------------------------------------------------------------
-- 清單與「要建哪些列」
--
--   resources.customRows[specID] = { { kind = "charges"|"stacks", spellID, max, color, height, text, showTime, enabled }, … }
--   height 沒存 ＝ CUSTOM_DEFAULT_HEIGHT（不跟資源條的列高走）
--   text = { show, size, font, outline }：這一列自己的數字（充能＝回充秒數、層數＝引擎寫的層數）；
--   沒存 ＝ 充能列看舊欄位 showTime、層數列不顯示；size 0 ＝ 照列高、font／outline "INHERIT" ＝ 跟資源條／主題
--   （Pips.TextStyle）
--
-- 清單的讀寫與規劃都是純函式（吃 cfg、specID 與一個查詢 probe），離線測試得到。
-- cfg 是**資源條的設定表**（清單存在那裡）。
------------------------------------------------------------
local CUSTOM_KINDS = { charges = true, stacks = true }
Pips.CUSTOM_KINDS = CUSTOM_KINDS
Pips.CUSTOM_DEFAULT_STACKS = 5
Pips.CUSTOM_DEFAULT_HEIGHT = 8
Pips.HEIGHT_MIN, Pips.HEIGHT_MAX = 2, 30

-- 純函式：這一列的高（沒存、壞資料 → 預設；超出範圍夾回來）
function Pips.CustomHeight(entry)
    local h = math.floor(tonumber(type(entry) == "table" and entry.height) or Pips.CUSTOM_DEFAULT_HEIGHT)
    return math.max(Pips.HEIGHT_MIN, math.min(Pips.HEIGHT_MAX, h))
end

-- 數字：每一列自己的（entry.text），不跟資源條的「長條上顯示數值」走
Pips.TEXT_SIZE_MIN, Pips.TEXT_SIZE_MAX = 6, 30

-- 純函式：這一列的數字 → show, size, font token, outline token
--   show     text.show 布林；沒存 ⇒ 充能列看舊欄位 showTime（預設開）、層數列預設關
--   size     text.size；0／沒存／壞值 ⇒ 照列高（max(8, 列高−4)）；其餘夾在 TEXT_SIZE_MIN～MAX
--   font     text.font；沒存／空字串 ⇒ "INHERIT"（跟資源條的 textFont → 通用字型）
--   outline  text.outline；沒存 ⇒ "INHERIT"（跟主題的描邊）；其餘原樣回（呼叫端用 Media.Outline 驗）
function Pips.TextStyle(entry, height)
    local e = type(entry) == "table" and entry or {}
    local t = type(e.text) == "table" and e.text or {}
    local show
    if type(t.show) == "boolean" then
        show = t.show
    elseif e.kind == "charges" then
        show = e.showTime ~= false
    else
        show = false
    end
    local size = math.floor(tonumber(t.size) or 0)
    if size <= 0 then
        size = math.max(8, (tonumber(height) or Pips.CUSTOM_DEFAULT_HEIGHT) - 4)
    else
        size = math.max(Pips.TEXT_SIZE_MIN, math.min(Pips.TEXT_SIZE_MAX, size))
    end
    local font = (type(t.font) == "string" and t.font ~= "" and t.font ~= "INHERIT") and t.font or "INHERIT"
    local outline = (type(t.outline) == "string" and t.outline ~= "INHERIT") and t.outline or "INHERIT"
    return show, size, font, outline
end

-- 這個專精的清單；create ＝ 沒有就建（寫入用），否則沒有回 nil
function Pips.CustomRowList(cfg, specID, create)
    if type(cfg) ~= "table" or specID == nil then return nil end
    local all = cfg.customRows
    if type(all) ~= "table" then
        if not create then return nil end
        all = {}
        cfg.customRows = all
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
function Pips.FindCustomRow(cfg, specID, kind, spellID)
    for i, e in ipairs(Pips.CustomRowList(cfg, specID) or {}) do
        if type(e) == "table" and e.kind == kind and e.spellID == spellID then return i end
    end
    return nil
end

function Pips.AddCustomRow(cfg, specID, entry)
    if type(entry) ~= "table" or not CUSTOM_KINDS[entry.kind] then return nil end
    local list = Pips.CustomRowList(cfg, specID, true)
    if not list then return nil end
    list[#list + 1] = entry
    return #list
end

-- 刪掉第 i 筆；清單空了就把這個專精的鍵拿掉（存檔不留空表）
function Pips.RemoveCustomRow(cfg, specID, i)
    local list = Pips.CustomRowList(cfg, specID)
    if not (list and type(i) == "number" and list[i] ~= nil) then return false end
    table.remove(list, i)
    if list[1] == nil then cfg.customRows[specID] = nil end
    return true
end

------------------------------------------------------------
-- 推薦清單：新增格子的輸入彈窗裡那顆下拉，選了就帶入法術 ID（層數列連上限一起）
--   class 必填；spec 有寫 ＝ 只給那個專精（術士這種天賦專屬的），沒寫 ＝ 整個職業
------------------------------------------------------------
local CUSTOM_RECOMMENDED = {
    PALADIN = {
        { kind = "charges", spellID = 190784 },                     -- 神性戰馬
    },
    EVOKER = {
        { kind = "charges", spellID = 358267 },                     -- 盤旋
    },
    MONK = {
        { kind = "stacks", spellID = 202090, max = 4, spec = 270 },  -- 僧院教義（織霧）
    },
    WARLOCK = {
        { kind = "stacks", spellID = 264173, max = 4, spec = 266 },  -- 魔能之核（惡魔學）
        { kind = "stacks", spellID = 296553, max = 10, spec = 266 }, -- 狂野小鬼（惡魔學）
    },
}
Pips.CUSTOM_RECOMMENDED = CUSTOM_RECOMMENDED

-- 純函式：這個職業／專精、這種列能推薦哪些。用不了的一律靜默跳過（不顯示、不佔位）：
--   別的專精的、這個專精已經加過的、法術不存在的（probe.exists）、
--   充能列：沒學會（probe.known）或現在沒有充能（probe.hasCharges，換天賦會變）
function Pips.CustomRecommendations(cfg, classFile, specID, kind, probe)
    local out = {}
    local list = CUSTOM_RECOMMENDED[classFile]
    if type(list) ~= "table" or specID == nil then return out end
    probe = probe or {}
    for _, r in ipairs(list) do
        local ok = r.kind == kind
            and (r.spec == nil or r.spec == specID)
            and not Pips.FindCustomRow(cfg, specID, r.kind, r.spellID)
            and (not probe.exists or probe.exists(r.spellID))
        if ok and kind == "charges" then
            ok = (not probe.known or probe.known(r.spellID))
                and (not probe.hasCharges or probe.hasCharges(r.spellID))
        end
        if ok then out[#out + 1] = r end
    end
    return out
end

local function ClampSegments(n)
    n = math.floor(tonumber(n) or 0)
    if n < 1 then return nil end
    return math.min(MAX_SEGMENTS, n)
end
Pips.ClampSegments = ClampSegments

-- 純函式：這個專精實際要建哪些自訂列。
--   probe.known(spellID)      → 充能法術學了沒（stacks 不問：沒有光環 ＝ 全空，列照顯示）
--   probe.maxCharges(spellID) → 明文的充能上限或 nil（讀不到／秘密值）
-- 回傳 { { index, entry, kind, spellID, numSeg }, … }，順序照清單；壞資料、enabled = false、
-- 未學會的充能法術都不建
function Pips.PlanCustomRows(cfg, specID, probe)
    local out = {}
    local list = Pips.CustomRowList(cfg, specID)
    if not list then return out end
    probe = probe or {}
    for i, e in ipairs(list) do
        if type(e) == "table" and CUSTOM_KINDS[e.kind] and type(e.spellID) == "number" and e.enabled ~= false then
            local n
            if e.kind == "charges" then
                if not probe.known or probe.known(e.spellID) then
                    -- 充能上限：API 讀得到就用它（天賦會改），讀不到才退回存檔的 max
                    local m = probe.maxCharges and probe.maxCharges(e.spellID)
                    n = ClampSegments(m) or ClampSegments(e.max) or 2
                end
            else
                n = ClampSegments(e.max) or Pips.CUSTOM_DEFAULT_STACKS
            end
            if n then
                out[#out + 1] = { index = i, entry = e, kind = e.kind, spellID = e.spellID, numSeg = n,
                                  showWhen = Pips.ShowWhen(e), height = Pips.CustomHeight(e) }
            end
        end
    end
    return out
end

-- 顯示時機：每種列開放哪幾種（設定頁的下拉照這張表；順序＝選單順序）
local SHOW_WHEN = {
    charges = { "always", "active", "activeOrCombat" },
    stacks  = { "always", "active" },
}
Pips.SHOW_WHEN = SHOW_WHEN

-- 純函式：這一筆實際生效的顯示時機（沒存、壞資料、這種列不開放的值 → always）
function Pips.ShowWhen(entry)
    local v = type(entry) == "table" and entry.showWhen
    local kinds = type(entry) == "table" and SHOW_WHEN[entry.kind]
    if type(v) ~= "string" or not kinds then return "always" end
    for _, k in ipairs(kinds) do if k == v then return v end end
    return "always"
end

-- 純函式：充能列這一次的透明度。
--   mode      always | active | activeOrCombat
--   isActive  GetSpellCharges().isActive（明文布林；讀不到 nil）
--   inCombat  明文
--   base      平常的透明度（讀不到值時 0.5）
-- 回傳數字 ＝ 直接 SetAlpha；回傳 nil ＝ Lua 決定不了，呼叫端改用引擎（duration:IsZero() 餵 SetAlphaFromBoolean）
function Pips.ChargeAlpha(mode, isActive, inCombat, base)
    if mode ~= "active" and mode ~= "activeOrCombat" then return base end
    if mode == "activeOrCombat" and inCombat then return base end
    if isActive == true then return base end
    if isActive == false then return 0 end
    return nil
end

-- 純函式：第 i 格的填色條與閘門的 min／max（SetValue 目前充能數）。
--   填色 (i-1, i)：充能數 ≥ i 滿、≤ i-1 空
--   閘門 (i-2, i-1)：充能數 ≥ i-1 滿（這一格是「下一格」或已經滿了）、≤ i-2 空（還輪不到）
function Pips.FillRange(i) return i - 1, i end
function Pips.GateRange(i) return i - 2, i - 1 end

-- 純函式：容器高度 ＝ 各列高加總＋列距（heights 是每列的高；沒有列 ＝ 0：輔助技能貼回核心下方）
function Pips.PanelHeight(heights, gap)
    if type(heights) ~= "table" or heights[1] == nil then return 0 end
    local sum = 0
    for _, h in ipairs(heights) do sum = sum + h end
    return sum + (#heights - 1) * gap
end

-- 遊戲裡的 probe：學了沒（兩支 API 過 pcall；秘密值當學了，API 都不在也當學了）與
-- 充能上限（明文才收，順手記下來，秘密值下沿用上次的明文值）
local lastChargeMax = {}

local function CustomKnown(id)
    local book = C_SpellBook
    local any = false
    for _, fn in ipairs({ book and book.IsSpellKnown, book and book.IsSpellInSpellBook }) do
        if fn then
            any = true
            local ok, v = pcall(fn, id)
            if ok then
                if ns.IsSecret(v) then return true end
                if v then return true end
            end
        end
    end
    return not any
end

local function CustomMaxCharges(id)
    local fn = C_Spell and C_Spell.GetSpellCharges
    if fn then
        local ok, info = pcall(fn, id)
        if ok and type(info) == "table" then
            local ok2, m = pcall(function() return info.maxCharges end)
            if ok2 then m = Plain(m) else m = nil end
            if m and m > 0 then
                lastChargeMax[id] = m
                return m
            end
        end
    end
    return lastChargeMax[id]
end

local gameProbe = { known = CustomKnown, maxCharges = CustomMaxCharges }
Pips.gameProbe = gameProbe

-- 推薦清單用的 probe：充能看「現在」有沒有（不吃 lastChargeMax 的舊值 —— 換掉天賦後那是過期的）
Pips.recommendProbe = {
    known = CustomKnown,
    exists = function(id)
        local fn = C_Spell and C_Spell.GetSpellInfo
        if not fn then return true end
        local ok, info = pcall(fn, id)
        return ok and type(info) == "table"
    end,
    hasCharges = function(id)
        local fn = C_Spell and C_Spell.GetSpellCharges
        if not fn then return true end
        local ok, info = pcall(fn, id)
        return ok and type(info) == "table"
    end,
}

-- 自訂列的顏色：存檔的色 → 職業色
local function CustomColor(entry)
    local c = RC.ValidColor(entry and entry.color)
    if c then return c.r, c.g, c.b end
    local r, g, b = ns.Style.Accent()
    return r, g, b
end
Pips.CustomColor = CustomColor

-- 自訂列的目前值（原始值，可能是秘密值）、回充的 duration 物件、回充中（明文布林或 nil）。讀不到回 nil
local function CustomValue(plan)
    if plan.kind == "stacks" then return R.AuraStacks(plan.spellID), nil, nil end
    local fn = C_Spell and C_Spell.GetSpellCharges
    local cur, active
    if fn then
        local ok, info = pcall(fn, plan.spellID)
        if ok and type(info) == "table" then
            local ok2, v, a = pcall(function() return info.currentCharges, info.isActive end)
            if ok2 then
                cur = v
                -- isActive 是 NeverSecret；保險起見照樣驗過明文才收
                if type(a) == "boolean" and not ns.IsSecret(a) then active = a end
            end
        end
    end
    local dfn = C_Spell and C_Spell.GetSpellChargeDuration
    local dur
    if dfn then
        local ok, d = pcall(dfn, plan.spellID)
        if ok then dur = d end
    end
    return cur, dur, active
end
Pips.CustomValue = CustomValue

------------------------------------------------------------
-- 框
------------------------------------------------------------
local container, root
local customRows = {}           -- 池化的列（frame 刪不掉；格子懶建）
local pendingRelayout = false   -- 戰鬥中面板是保護框、該重排的時候記在這裡

-- 充能格（見檔頭的層次）。層數格只用底色與填色（明文退路）
local function MakeCustomCell(row)
    local cell = CreateFrame("Frame", nil, row)
    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetTexture(SOLID)
    cell.bg:SetAllPoints(cell)
    -- 閘門：透明，只拿它的填充貼圖當裁切框的錨點
    cell.gate = CreateFrame("StatusBar", nil, cell)
    cell.gate:SetAllPoints(cell)
    cell.gate:SetStatusBarTexture(SOLID)
    local gt = cell.gate:GetStatusBarTexture()
    if gt then gt:SetVertexColor(0, 0, 0, 0) end
    cell.clip = CreateFrame("Frame", nil, cell)
    cell.clip:SetClipsChildren(true)
    if gt then
        cell.clip:SetPoint("TOPLEFT", gt, "TOPLEFT", 0, 0)
        cell.clip:SetPoint("BOTTOMRIGHT", gt, "BOTTOMRIGHT", 0, 0)
    end
    -- 回充條：錨在格子上（被裁切，不是被壓扁）
    cell.rc = CreateFrame("StatusBar", nil, cell.clip)
    cell.rc:SetAllPoints(cell)
    cell.rc:SetStatusBarTexture(SOLID)
    -- 秒數：不畫扇形的 Cooldown，只留倒數字
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, cell.clip, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints(cell)
        if cd.SetDrawSwipe then cd:SetDrawSwipe(false) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
        -- ⚠ 先給字型（像素字型、跟數值文字同一套）；樣式在 LayoutCustomRow 依列高重套
        if fs then ns.Media.SetPixelFont(fs, 8, "OUTLINE") end
        cell.cd = cd
    end
    cell.bar = CreateFrame("StatusBar", nil, cell)
    cell.bar:SetAllPoints(cell)
    cell.bar:SetStatusBarTexture(SOLID)
    R.Edges(cell.bar)
    cell:Hide()
    return cell
end

local function OnAuraRegen() Pips.Mark(true) end

local function MakeCustomRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row.cells = {}                    -- 懶建：要幾格建幾格（frame 刪不掉，建了就留著重用）
    row.ab, row.abDecor, row.engine = false, false, false   -- 引擎寫層數的持有框／裝飾（懶建）
    row:Hide()
    return row
end

local function HideCells(row, from)
    for i = from, #row.cells do
        local cell = row.cells[i]
        if cell.cd then cell.cd:Clear() end
        cell:Hide()
    end
end

-- 層數列：引擎寫的那條（AuraBar）。回傳 true ＝ 用引擎；false ＝ 退回明文格子
-- 這一列的數字（Pips.TextStyle 解成遊戲端的值）：show, 字級（UIParent 座標）, 字型 token, 描邊旗標
local function RowText(plan, style)
    local show, size, font, outline = Pips.TextStyle(plan.entry, plan.height)
    local token = ns.Media.ElementFont(font, ns.Media.ElementFont(style.textFont, ns.Setting(nil, "font")))
    local flags = (outline == "INHERIT") and ns.Media.ThemeOutline() or ns.Media.Outline(outline)
    return show, size, token, flags
end

local function LayoutStackEngine(row, plan, style, W, H, gap, r, g, b, alpha, reversed, tex, count)
    if not ns.AuraBar then return false end
    row.ab = row.ab or ns.AuraBar.New(row, OnAuraRegen)
    local n = plan.numSeg
    local geom = {
        W = W, H = H, n = n, gap = gap, segW = (W - gap * (n - 1)) / n, reversed = reversed, segments = true,
        dim = { DIM.r, DIM.g, DIM.b, DIM.a }, px = ns.P.Scale(1), bgTex = ns.Resources.BgTexture(style),
    }
    local inside = plan.showWhen == "active"
    local status = ns.AuraBar.Apply(row.ab, {
        spellIDs = { plan.spellID }, max = n, texture = tex, color = { r = r, g = g, b = b }, alpha = alpha,
        reversed = reversed, inside = inside and geom or nil,
        count = count,          -- 層數文字（引擎寫；樣式進簽章，改了換容器、戰鬥中等脫戰）
    })
    row.engineStatus = status
    if status ~= "ready" then
        ns.AuraBar.HideContainer(row.ab)
        ns.AuraBar.HideRowDecor(row)
        return false
    end
    if inside then
        ns.AuraBar.HideRowDecor(row)
    else
        ns.AuraBar.RowDecor(row, geom, (row:GetFrameLevel() or 1) + 8)
    end
    return true
end

-- style：資源條的設定表（樣式照它）
local function LayoutCustomRow(row, plan, style, W, H)
    local numSeg = plan.numSeg
    row:SetSize(W, H)
    row:SetAlpha(1)
    local reversed = ns.FillReversed(style)
    local tex = ns.Media.Texture(style.texture)
    local gap = ns.P.Scale(tonumber(style.segmentSpacing) or 1)     -- 引擎列（裝飾自己處理 0 間距）
    local r, g, b = CustomColor(plan.entry)
    local alpha = tonumber(style.barAlpha) or 1
    local charges = plan.kind == "charges"
    local showText, fontSize, font, outline = RowText(plan, style)

    row.engine = false
    if not charges then
        -- 層數文字交給引擎（SetApplicationCount）：字級換成實體像素（按鈕子樹裡的 FontString 忽略父層縮放）
        local count
        if showText then
            local scale = UIParent:GetEffectiveScale()
            if not scale or scale <= 0 then scale = 1 end
            count = { font = ns.Media.Font(font), size = fontSize * scale, outline = outline }
        end
        row.engine = LayoutStackEngine(row, plan, style, W, H, gap, r, g, b, alpha, reversed, tex, count)
        if row.engine then
            HideCells(row, 1)
            return
        end
    else
        if row.ab then ns.AuraBar.HideContainer(row.ab) end
        if ns.AuraBar then ns.AuraBar.HideRowDecor(row) end
    end

    local fmt = ns.Text and ns.Text.PlainFormatter and ns.Text.PlainFormatter(0)
    for i = 1, numSeg do
        local cell = row.cells[i]
        if not cell then
            cell = MakeCustomCell(row)
            row.cells[i] = cell
        end
        local x, segW = R.SegCell(W, numSeg, style.segmentSpacing, i)
        cell:SetSize(segW, H)
        cell:ClearAllPoints()
        if reversed then
            cell:SetPoint("TOPRIGHT", row, "TOPRIGHT", -x, 0)
        else
            cell:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
        end
        -- 層級每次重排都重設：父層的 strata／level 可能被結構套用改過
        local lv = cell:GetFrameLevel()
        cell.bg:SetTexture(ns.Resources.BgTexture(style))
        cell.bg:SetVertexColor(DIM.r, DIM.g, DIM.b, DIM.a)
        cell.gate:SetFrameLevel(lv + 1)
        cell.clip:SetFrameLevel(lv + 1)
        cell.rc:SetFrameLevel(lv + 2)
        cell.bar:SetFrameLevel(lv + 4)
        cell.bar:SetStatusBarTexture(tex)
        cell.bar:SetMinMaxValues(Pips.FillRange(i))
        local t = cell.bar:GetStatusBarTexture()
        if t then t:SetVertexColor(r, g, b, alpha) end
        if charges then
            cell.gate:SetMinMaxValues(Pips.GateRange(i))
            cell.clip:Show()
            -- 回充條：這一列顏色的暗版，往下一格的方向長
            cell.rc:SetStatusBarTexture(tex)
            cell.rc:SetReverseFill(reversed)
            local rt = cell.rc:GetStatusBarTexture()
            if rt then rt:SetVertexColor(r * 0.5, g * 0.5, b * 0.5, alpha) end
            local cd = cell.cd
            if cd then
                cd:SetFrameLevel(lv + 3)
                if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(not showText) end
                local fs = cd.GetCountdownFontString and cd:GetCountdownFontString()
                if fs then
                    ns.Media.SetPixelFont(fs, fontSize, outline, font)
                    fs:SetTextColor(1, 1, 1, 1)
                    fs:ClearAllPoints()
                    fs:SetPoint("CENTER", cell, "CENTER", 0, 0)
                end
                if fmt and cd.SetCountdownFormatter then pcall(cd.SetCountdownFormatter, cd, fmt) end
                if cd.SetCountdownMillisecondsThreshold then pcall(cd.SetCountdownMillisecondsThreshold, cd, 0) end
                cd:Show()
            end
        else
            -- 層數的明文退路：沒有回充
            cell.clip:Hide()
            if cell.cd then cell.cd:Clear() end
        end
        cell:Show()
    end
    HideCells(row, numSeg + 1)
end

-- 充能列的顯示時機：Lua 決定得了就 SetAlpha，決定不了（isActive 讀不到）交給引擎
local function ApplyChargeAlpha(row, plan, base, dur, isActive)
    local a = Pips.ChargeAlpha(plan.showWhen, isActive, InCombatLockdown() and true or false, base)
    if a then
        row:SetAlpha(a)
        return
    end
    -- duration:IsZero() 是秘密布林：取得可以、測試不行 ⇒ 直接餵 SetAlphaFromBoolean
    local zero
    if dur and dur.IsZero then
        local ok, z = pcall(dur.IsZero, dur)
        if ok then zero = z end
    end
    -- 秘密值連跟 nil 比都會拋錯：先問是不是秘密值
    if (ns.IsSecret(zero) or zero ~= nil) and row.SetAlphaFromBoolean and pcall(row.SetAlphaFromBoolean, row, zero, 0, base) then return end
    row:SetAlpha(base)             -- 什麼都讀不到：寧可顯示
end

local function UpdateCustomRow(row)
    local plan = row.plan
    if not plan then return end
    local charges = plan.kind == "charges"
    if row.engine then
        -- 層數由引擎寫；顯不顯示也是按鈕自己的事（active 時裝飾在按鈕子樹裡）
        row.valueState = "engine"
        row:SetAlpha(1)
        return
    end
    local cur, dur, isActive = CustomValue(plan)
    -- 只看型別（type() 回真實型別，不讀值）：秘密數字照樣是 "number"
    local readable = type(cur) == "number"
    local vs = "unreadable"
    if readable then
        if ns.IsSecret(cur) then vs = "secret" else vs = "plain" end
    end
    row.valueState = vs
    local base = readable and 1 or 0.5
    if charges then
        ApplyChargeAlpha(row, plan, base, dur, isActive)
    elseif plan.showWhen == "active" then
        -- 層數的明文退路：有沒有這個光環（表的真假，不讀內容）
        local get = C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID
        local has = false
        if get then
            local ok, aura = pcall(get, plan.spellID)
            has = ok and aura ~= nil
        end
        row:SetAlpha(has and base or 0)
    else
        row:SetAlpha(base)
    end
    for i = 1, plan.numSeg do
        local cell = row.cells[i]
        -- ⚠ 不能寫 `readable and cur or 0`：`or` 要判斷 cur 的真假，秘密值當布林用會拋錯
        if readable then cell.bar:SetValue(cur) else cell.bar:SetValue(0) end   -- 引擎決定這格亮多少，秘密值照樣對
        if charges then
            if readable then cell.gate:SetValue(cur) else cell.gate:SetValue(-1) end
            local cd = cell.cd
            if dur then
                cell.rc:Show()
                pcall(cell.rc.SetTimerDuration, cell.rc, dur, nil, ELAPSED)
                if cd then pcall(cd.SetCooldownFromDurationObject, cd, dur, true) end
            else
                cell.rc:Hide()
                if cd then cd:Clear() end
            end
        end
    end
end

------------------------------------------------------------
-- 重排與重畫
------------------------------------------------------------
local customShown = 0
local laidOut = false            -- 排過版了沒（false ＝ 下一次 Update 一定重排）
local customHas = { charges = false, stacks = false, combat = false }
local SyncEvents                 -- 定義在事件那一段（前置宣告）

local function HideRows(from)
    for i = from, #customRows do
        local row = customRows[i]
        row:Hide()
        row.plan, row.valueState, row.engine = nil, nil, false
        HideCells(row, 1)
        if row.ab and ns.AuraBar then ns.AuraBar.HideContainer(row.ab) end
        if ns.AuraBar then ns.AuraBar.HideRowDecor(row) end
    end
end

-- 層數列的 AuraContainer 讓面板變成保護框：戰鬥中不能 SetSize／SetPoint／Show／Hide 列 ⇒ 記旗標、脫戰補
local function MustDefer()
    return InCombatLockdown() and root ~= nil and ns.IsProtectedFrame and ns.IsProtectedFrame(root)
end

local function OnRegenRelayout()
    ns.Events.Unregister("PLAYER_REGEN_ENABLED", "pips_relayout")
    if pendingRelayout then
        pendingRelayout = false
        Pips.Mark(true)
    end
end

local function DeferRelayout()
    pendingRelayout = true
    ns.Events.Register("PLAYER_REGEN_ENABLED", "pips_relayout", OnRegenRelayout)
end

local function Relayout(style, W)
    local heights = {}
    local gap = ns.P.Scale(tonumber(style.rowSpacing) or 1)
    W = ns.P.Scale(W)
    local plans = Pips.PlanCustomRows(style, ns.specID, gameProbe)
    customHas.charges, customHas.stacks, customHas.combat = false, false, false
    local prev
    for i, plan in ipairs(plans) do
        local row = customRows[i]
        if not row then
            row = MakeCustomRow(root)
            customRows[i] = row
        end
        row.plan = plan
        local H = ns.P.Scale(plan.height)
        heights[i] = H
        customHas[plan.kind] = true
        if plan.showWhen == "activeOrCombat" then customHas.combat = true end
        row:ClearAllPoints()
        if prev then
            row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -gap)
        else
            row:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
        end
        prev = row
        row:Show()
        LayoutCustomRow(row, plan, style, W, H)
        if row.ab and ns.AuraBar then ns.AuraBar.KickPending(row.ab) end
    end
    HideRows(#plans + 1)
    customShown = #plans
    SyncEvents()
    -- 顯示時機不是 always 的列照樣佔位（秘密值下不知道它現在顯不顯示）
    ns.Bars.SetPanelSize(KEY, W, Pips.PanelHeight(heights, gap))
end

local function UpdateRows()
    for i = 1, customShown do
        local ok, err = xpcall(UpdateCustomRow, ns.ReportError, customRows[i])
        if not ok then Pips.lastError = err end
    end
end

-- force：重排（清單、格數、尺寸設定、寬度都可能變了）。不給 ＝ 只重畫值（充能／光環事件走這條）
function Pips.Update(force)
    if not root then return end
    local cfg, style = Cfg(), StyleCfg()
    if not cfg or cfg.enabled == false or not style then
        if MustDefer() then DeferRelayout() return end
        HideRows(1)
        customShown = 0
        customHas.charges, customHas.stacks, customHas.combat = false, false, false
        SyncEvents()
        laidOut = false
        -- 關著也收合：跟著這裡的輔助技能改貼核心下方
        ns.Bars.SetPanelSize(KEY, ns.P.Scale(R.Width(style)), 0)
        return
    end
    if force or not laidOut then
        if MustDefer() then
            DeferRelayout()
        else
            Relayout(style, R.Width(style))
            laidOut = true
        end
    end
    UpdateRows()
end

------------------------------------------------------------
-- 事件：只標髒，下一幀做
------------------------------------------------------------
local dirtyRelayout, dirtyValues, armed = false, false, false

local function Flush()
    armed = false
    local re, va = dirtyRelayout, dirtyValues
    dirtyRelayout, dirtyValues = false, false
    if re then
        Pips.Update(true)
    elseif va then
        Pips.Update(false)
    end
end

-- relayout：true ＝ 重算清單與重排；其他 ＝ 只重畫值
local function Mark(relayout)
    if relayout then dirtyRelayout = true else dirtyValues = true end
    if not armed then
        armed = true
        ns.Defer(Flush)
    end
end
Pips.Mark = Mark

-- 清單可能變的事件（法術學會／忘掉、天賦改了充能上限、換專精、進世界）
local RELAYOUT_EVENTS = {
    SPELLS_CHANGED = true, PLAYER_TALENT_UPDATE = true, TRAIT_CONFIG_UPDATED = true,
    PLAYER_SPECIALIZATION_CHANGED = true, PLAYER_ENTERING_WORLD = true,
}
-- 值的事件（很密）：只在有那一種列時才註冊
local CHARGE_EVENTS = { SPELL_UPDATE_CHARGES = true, SPELL_UPDATE_COOLDOWN = true }
local COMBAT_EVENTS = { PLAYER_REGEN_DISABLED = true, PLAYER_REGEN_ENABLED = true }

local evFrame
local evCharges, evAura, evCombat = false, false, false

local function OnEvent(_, event)
    Mark(RELAYOUT_EVENTS[event] == true)
end

-- 重排時對一次帳：充能列 → SPELL_UPDATE_CHARGES／COOLDOWN；層數列 → UNIT_AURA（player，明文退路用；
-- 引擎寫的列不需要，但容器可能還沒建好）；「不滿或戰鬥中」→ 進出戰鬥
SyncEvents = function()
    if not evFrame then return end
    local wantCharges = customHas.charges and true or false
    if wantCharges ~= evCharges then
        evCharges = wantCharges
        for e in pairs(CHARGE_EVENTS) do
            if wantCharges then evFrame:RegisterEvent(e) else evFrame:UnregisterEvent(e) end
        end
    end
    local wantAura = customHas.stacks and true or false
    if wantAura ~= evAura then
        evAura = wantAura
        if wantAura then evFrame:RegisterUnitEvent("UNIT_AURA", "player") else evFrame:UnregisterEvent("UNIT_AURA") end
    end
    local wantCombat = customHas.combat and true or false
    if wantCombat ~= evCombat then
        evCombat = wantCombat
        for e in pairs(COMBAT_EVENTS) do
            if wantCombat then evFrame:RegisterEvent(e) else evFrame:UnregisterEvent(e) end
        end
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
-- 初始化（ns.StartEngine：Resources 之後）
------------------------------------------------------------
local function MinSize()
    local style = StyleCfg() or {}
    return R.Width(style), Pips.CUSTOM_DEFAULT_HEIGHT
end

function Pips.Init()
    if container then return end
    container = ns.Bars.RegisterPanel(KEY, {
        anchorPoint = "TOP",                  -- 貼在核心技能下方、往下長，列數增減時上緣不動
        collapsible = true,                   -- 沒有列 ＝ 收合（不佔位，後面的接到上一層）
        minSize     = MinSize,
        relayout    = function() Pips.Update(true) end,
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
    Pips.Update(true)
end

-- 設定頁改了值（資源條頁：清單、樣式、這裡的位置／錨定／淡出）：重排＋結構＋ alpha
function Pips.Apply()
    if not container then return end
    Pips.Update(true)
    if InCombatLockdown() then ns.Bars.Request(KEY, "structure") else ns.Bars.ApplyStructure(KEY) end
    if ns.Visibility then ns.Visibility.Apply(KEY) end
end

------------------------------------------------------------
-- 除錯
------------------------------------------------------------
-- 第 i 列的框（除錯與冒煙用；不是公開 API）
function Pips.RowFrame(i)
    if type(i) ~= "number" or i < 1 or i > customShown then return nil end
    return customRows[i]
end

local function AnchorText(cfg)
    local a = type(cfg) == "table" and cfg.anchor
    if type(a) == "table" and type(a.to) == "string" then
        return ("錨 %s %s→%s (%s, %s)"):format(a.to, tostring(a.point), tostring(a.relPoint), tostring(a.x), tostring(a.y))
    end
    local pos = type(cfg) == "table" and type(cfg.pos) == "table" and cfg.pos or {}
    return ("位置 %s (%s, %s)"):format(tostring(pos.point), tostring(pos.x), tostring(pos.y))
end

local SHOW_TEXT = { always = "一直", active = "作用中", activeOrCombat = "作用中或戰鬥" }

function Pips.DebugLines()
    local out = {}
    if not container then
        out[1] = "  自訂格子：沒有初始化"
        return out
    end
    local cfg, style = Cfg(), StyleCfg()
    local specID = ns.specID
    local list = Pips.CustomRowList(style, specID)
    local h = container.GetHeight and container:GetHeight()
    local lc = type(cfg) == "table" and type(cfg.loadConditions) == "table" and cfg.loadConditions or {}
    out[#out + 1] = ("  自訂格子：%s  專精 %s  清單 %d 筆  顯示 %d 列  高 %s  %s  alpha %s  載入條件 騎乘藏 %s／只在戰鬥 %s  事件 充能 %s／光環 %s／戰鬥 %s%s")
        :format((cfg and cfg.enabled ~= false) and "開" or "關", tostring(specID), list and #list or 0, customShown,
                tostring(Plain(h)), AnchorText(cfg), tostring(ns.Visibility and ns.Visibility.Current(KEY)),
                lc.hideMounted and "是" or "否", lc.onlyCombat and "是" or "否",
                evCharges and "開" or "關", evAura and "開" or "關", evCombat and "開" or "關",
                pendingRelayout and "  （戰鬥中，重排延到脫戰）" or "")
    -- 清單裡每一筆都印（沒建列的寫原因）
    for i, e in ipairs(list or {}) do
        local row
        for j = 1, customShown do
            if customRows[j].plan and customRows[j].plan.index == i then row = customRows[j] end
        end
        local kind = type(e) == "table" and tostring(e.kind) or "?"
        local id = type(e) == "table" and tostring(e.spellID) or "?"
        if row then
            -- 值是不是秘密：用上一次更新時記的狀態（只看型別與 issecretvalue，不讀值）
            local vs = row.valueState
            local state = vs == "secret" and "秘密" or vs == "plain" and "明文" or vs == "unreadable" and "讀不到"
                or vs == "engine" and "引擎寫" or "—"
            local extra = ""
            if row.plan.kind == "stacks" and row.ab and ns.AuraBar then
                local bound = ns.AuraBar.Bound(row.ab)
                extra = ("  容器 %s／交條 %s"):format(tostring(row.engineStatus),
                    bound == true and "是" or bound == false and "失敗" or "未知")
            end
            out[#out + 1] = ("    自訂 %d. %-7s spellID %s  ×%d  高 %d  值 %s  顯示 %s%s")
                :format(i, kind, id, row.plan.numSeg, row.plan.height, state, SHOW_TEXT[row.plan.showWhen] or "?", extra)
        else
            local why
            if type(e) ~= "table" or not CUSTOM_KINDS[e.kind] or type(e.spellID) ~= "number" then why = "壞資料"
            elseif cfg and cfg.enabled == false then why = "自訂格子關著"
            elseif e.enabled == false then why = "關閉"
            elseif e.kind == "charges" and not CustomKnown(e.spellID) then why = "法術未學會"
            else why = "沒有建列" end
            out[#out + 1] = ("    （自訂 %d. %s spellID %s）%s"):format(i, kind, id, why)
        end
    end
    return out
end
