------------------------------------------------------------
-- 從 Ayije_CDM 匯入設定（首次使用）
--
--   ns.Import.Convert(src, opts)     → profile, report
--       純函式：一份 Ayije_CDM 的設定檔（Ayije_CDMDB.profiles[名字]）→ 一份本插件的設定檔。
--       不碰任何 frame、不讀全域；要用的東西全部從 opts 來：
--         opts.defaults   本插件的預設設定檔（DB.BuildDefaults().profile），輸出從它的深複本開始
--         opts.specID     目前的專精：這個專精的 spellID 當場換成 cooldownID
--         opts.resolve    function(spellID, kind) → cooldownID | nil（kind："cooldown" | "buff"）
--         opts.class      玩家職業（資源條的設定是分職業存的，撞 key 時優先用這個職業的）
--         opts.specName   function(specID) → 專精名（選用；自訂群組撞名時加在後面）
--       資源條「哪幾個專精顯示這一列」要知道每個專精的候選資源：借 Modules/Resources.lua 的純函式
--       （R.SpecCandidates／R.SetRow；匯入在登入後才跑，那時已經載好）。
--   ns.Import.PlanNames(names, existing, previous, fmt) → { [原名] = 新名 }   純函式：取名
--   ns.Import.ApplyPending(profile, specID, resolve)     → 換好幾筆, 還剩幾筆   純函式
--   ns.Import.BuildResolver(records)                     → resolve              純函式
--   ns.Import.FromAyije()          互斥彈窗的「匯入」鈕（讀 Ayije_CDMDB、寫 SV、停用它、重載）
--   ns.Import.ResolvePending(specID)  目錄建好之後叫（Core/Catalog.lua）
--
-- 為什麼只能在互斥彈窗那一刻做：SavedVariables 只在插件載入時才在記憶體裡。兩支都開著時
-- 本插件什麼都不初始化（Core/Init.lua），但兩邊的存檔都讀得到 —— 讀它的、寫我們的
-- （DB.Init 還沒跑，直接寫 SV 表）、停用它、重載，登入時 DB.Init 照常補預設值。
--
-- 匯入產生的一律是**新的設定檔**（名字前面加「Ayije：」，撞名加序號），不覆蓋既有的；
-- 重新匯入時覆蓋的是上次匯入建的那幾份（SV 的 importedFromAyije.profiles 記著對照）。
--
-- ⚠ 對方的存檔只存「跟它的預設值不同」的鍵。**沒出現的鍵一律不動**（保留本插件的預設值），
--   匯入摘要會講這一句。
--
-- ── 跨專精：spellID → cooldownID ──
-- 對方的自訂群組、增益覆寫用 spellID，本插件用 cooldownID（暴雪 CooldownSetSpell 的 ID，**每個專精不同**）。
-- 匯入當下只查得到目前專精；其他專精的先原樣存在設定檔的 pendingImport[specID]：
--   pendingImport[specID] = {
--       groups    = { { bar = "g2", kind = "cooldown"|"buff", spells = { spellID, … } }, … },
--       overrides = { { spellID, kind, fields = { hideCooldownText = true, … } }, … },
--   }
-- 目錄每次建好（登入、換專精、換設定檔）就把目前專精那一筆對一次表（ResolvePending），
-- 換得到的寫進 spells[specID]（groupOf／order／overrides）、清掉；換不到的留著，/mcdm debug 印得出來。
--
-- 12.1：匯入當下呼叫的 C_CooldownViewer／C_Spell API 全部 pcall，回傳值過 Plain（秘密值、
-- 讀不到的一律當沒有）；進 table key 的 cooldownID 只收明文數字。存檔內容本身是明文。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

ns.Import = {}
local Import = ns.Import

-- 資料夾名是功能上的識別字（IsAddOnLoaded／EnableAddOn／DisableAddOn 要用）
Import.SOURCE_ADDON   = "Ayije_CDM"
Import.SOURCE_FOLDERS = { "Ayije_CDM", "Ayije_CDM_Options" }
local SOURCE_SV = "Ayije_CDMDB"

-- 「不限每列幾格」在本插件的表示法：設定頁滑桿的上限
local UNLIMITED_PER_ROW = 20

------------------------------------------------------------
-- 小工具（純函式）
------------------------------------------------------------
local function Num(v)
    if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

local function Str(v)
    if type(v) == "string" and v ~= "" then return v end
    return nil
end

local function Color(c)
    if type(c) ~= "table" then return nil end
    local r, g, b = Num(c.r), Num(c.g), Num(c.b)
    if not (r and g and b) then return nil end
    return { r = r, g = g, b = b, a = Num(c.a) or 1 }
end

local function SameColor(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    return a.r == b.r and a.g == b.g and a.b == b.b and (a.a or 1) == (b.a or 1)
end

local POINTS = {
    CENTER = true, TOP = true, BOTTOM = true, LEFT = true, RIGHT = true,
    TOPLEFT = true, TOPRIGHT = true, BOTTOMLEFT = true, BOTTOMRIGHT = true,
}
local function Point(v)
    if POINTS[v] then return v end
    return nil
end

local function DeepCopy(t)
    if type(t) ~= "table" then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = DeepCopy(v) end
    return o
end
Import.DeepCopy = DeepCopy

local function SortedKeys(t)
    local keys = {}
    for k in pairs(type(t) == "table" and t or {}) do keys[#keys + 1] = k end
    table.sort(keys, function(a, b)
        local ta, tb = type(a), type(b)
        if ta ~= tb then return ta < tb end
        if ta == "number" or ta == "string" then return a < b end
        return tostring(a) < tostring(b)
    end)
    return keys
end

local function SetPath(t, path, v)
    local cur = t
    local segs = {}
    for seg in string.gmatch(path, "[^%.]+") do segs[#segs + 1] = seg end
    for i = 1, #segs - 1 do
        local k = segs[i]
        if type(cur[k]) ~= "table" then cur[k] = {} end
        cur = cur[k]
    end
    cur[segs[#segs]] = v
end

local function GetPath(t, path)
    local cur = t
    for seg in string.gmatch(path, "[^%.]+") do
        if type(cur) ~= "table" then return nil end
        cur = cur[seg]
    end
    return cur
end

-- 點的水平／垂直那一半，與組回去
local function HSide(p)
    if p:find("LEFT$") then return "LEFT" end
    if p:find("RIGHT$") then return "RIGHT" end
    return "CENTER"
end
local function VSide(p)
    if p:find("^TOP") then return "TOP" end
    if p:find("^BOTTOM") then return "BOTTOM" end
    return "CENTER"
end
local function Compose(h, v)
    if v == "CENTER" then return h == "CENTER" and "CENTER" or h end
    if h == "CENTER" then return v end
    return v .. h
end
Import.Compose = Compose

-- 點在一個 w×h 的矩形裡的座標（原點在左下角、y 往上）
local function PointXY(p, w, h)
    local hs, vs = HSide(p), VSide(p)
    local x = (hs == "LEFT" and 0) or (hs == "RIGHT" and w) or w / 2
    local y = (vs == "BOTTOM" and 0) or (vs == "TOP" and h) or h / 2
    return x, y
end

-- 會被「錨定的排開」（Core/Layout.lua 的 AnchorSide）當成上下疊的組合
local function StacksVertically(point, relPoint)
    local p, r = tostring(point), tostring(relPoint)
    return (p:find("^TOP") and r:find("^BOTTOM")) or (p:find("^BOTTOM") and r:find("^TOP")) or false
end

------------------------------------------------------------
-- 匯入報告
--
--   report = {
--     imported = { 來源鍵… },                        有用到的頂層鍵（排序過）
--     skipped  = { { key, why, cat }… },             why：noEquivalent（本插件沒有這個功能）／
--                                                   obsolete（對方的舊版殘留，它自己也不讀了）／unknown
--     approx   = { { key, note }… },                 對得上但不是一模一樣（note 是給 debug 看的英文短句）
--     counts   = { profiles, groups, groupsPending, auras, overrides, overridesPending, conditions },
--     pending  = { [specID] = { groups = n, spells = n, overrides = n } },
--   }
------------------------------------------------------------
local function NewReport()
    return {
        imported = {}, skipped = {}, approx = {}, pending = {},
        counts = { groups = 0, groupsPending = 0, auras = 0, overrides = 0, overridesPending = 0, conditions = 0 },
    }
end

local function Skip(ctx, key, why, cat)
    if ctx.skipSeen[key] then return end
    ctx.skipSeen[key] = true
    local list = ctx.R.skipped
    list[#list + 1] = { key = key, why = why, cat = cat or "other" }
end

local function Approx(ctx, key, note)
    local list = ctx.R.approx
    list[#list + 1] = { key = key, note = note }
end

-- 讀一個頂層鍵並記成「用過了」（沒出現也記：之後分類只看有出現的鍵）
local function Take(ctx, key)
    ctx.used[key] = true
    return ctx.src[key]
end

local function Bar(ctx, key)
    local bars = ctx.out.bars
    local b = type(bars) == "table" and bars[key]
    return type(b) == "table" and b or nil
end

local function Layout(bar)
    if type(bar.layout) ~= "table" then bar.layout = {} end
    return bar.layout
end

local function Size(v)
    if type(v) ~= "table" then return nil end
    local w, h = Num(v.w), Num(v.h)
    if not (w and h) or w <= 0 or h <= 0 then return nil end
    return { w = w, h = h }
end

-- 條自己的文字欄位：值跟主題一樣就不寫（寫了會讓那條不再「跟隨全域主題」）
local function BarText(ctx, barKey, path, v)
    if v == nil then return end
    local bar = Bar(ctx, barKey)
    if not bar then return end
    local themeV = GetPath(ctx.out.theme, path)
    if v == themeV or SameColor(v, themeV) then return end
    if type(bar.follow) ~= "table" then bar.follow = {} end
    bar.follow.text = false
    if type(bar.text) ~= "table" then bar.text = {} end
    SetPath(bar.text, path, v)
end

-- LibSharedMedia 名稱：對方的「Solid」＝本插件的內建純色
local function Texture(v)
    v = Str(v)
    if not v then return nil end
    if v == "Solid" then return "solid" end
    return v
end

------------------------------------------------------------
-- 1. 位置與錨定
--
-- 對方存的是 editModePositions[檢視器]["Default"] = { point, x, y }（point 是 UIParent 上的點）。
-- 存檔座標的語意（四個容器各不相同）：
--
--   核心技能   容器 TOPLEFT → UIParent point，偏移 (x − halfW, y)
--   增益圖示   容器 BOTTOM  → UIParent point，偏移 (x, y)
--   增益長條   往下長 TOPLEFT／往上長 BOTTOMLEFT → UIParent point，偏移 (x − halfW, y)
--   輔助技能   容器 TOPLEFT → 核心 BOTTOMLEFT，偏移 (核心halfW − 輔助halfW + xOff, −spacing + yOff)
--
-- halfW 是容器寬的一半。它把「上緣（或下緣）中點」存成 (x, y)，套用時才扣半寬換成左上角 ——
-- 所以存檔裡的 (x, y) **本來就是中點**：核心技能＝上緣中點、增益長條＝成長那一邊的中點。
-- 本插件的 pos 是「容器錨點那一邊」貼 UIParent 的 pos.point，而置中對齊的成長方向
-- （CENTER_DOWN／CENTER_UP）錨點正好是 TOP／BOTTOM 的中點 ⇒ 匯入時把成長方向設成置中，
-- (x, y) 原樣搬過來，不需要知道容器多寬（halfW 在兩邊抵消）。
-- 輔助技能：兩邊都是「上緣中點貼核心下緣中點」，只差偏移：y = −spacing + yOff；
-- x 只有在對方的 utilityWrap 與 utilityUnlock 都開時才生效（不然它自己也強制 0）。
------------------------------------------------------------
local VIEWER_POS_KEYS = {
    EssentialCooldownViewer = true, BuffIconCooldownViewer = true, BuffBarCooldownViewer = true,
}

local function ViewerPos(src, viewer)
    local all = src.editModePositions
    local t = type(all) == "table" and all[viewer]
    if type(t) ~= "table" then return nil end
    local p = t.Default
    if type(p) ~= "table" then
        -- 其他版面名（理論上只有 Default）：照名字排序取第一個，結果穩定
        local names = SortedKeys(t)
        p = names[1] ~= nil and t[names[1]] or nil
    end
    if type(p) ~= "table" then return nil end
    local x, y = Num(p.x), Num(p.y)
    if not (x and y) then return nil end
    return { point = Point(p.point) or "CENTER", x = x, y = y }
end

local function StepPositions(ctx)
    local src = ctx.src
    local all = Take(ctx, "editModePositions")
    if type(all) == "table" then
        for _, name in ipairs(SortedKeys(all)) do
            if not VIEWER_POS_KEYS[name] then
                Skip(ctx, "editModePositions." .. tostring(name), "noEquivalent", "other")
            end
        end
    end

    local ess = ViewerPos(src, "EssentialCooldownViewer")
    ctx.essPos = ess
    local b = Bar(ctx, "essential")
    if ess and b then
        b.pos = DeepCopy(ess)
        b.anchor = false
        Layout(b).grow = "CENTER_DOWN"
    end

    local buff = ViewerPos(src, "BuffIconCooldownViewer")
    b = Bar(ctx, "buffs")
    if buff and b then
        b.pos = DeepCopy(buff)
        b.anchor = false
        Layout(b).grow = "CENTER_UP"
    end

    local dir = Take(ctx, "buffBarGrowDirection")
    local bbPos = ViewerPos(src, "BuffBarCooldownViewer")
    b = Bar(ctx, "buffbars")
    if b and (bbPos or dir ~= nil) then
        local up = dir == "UP"
        Layout(b).grow = up and "CENTER_UP" or "CENTER_DOWN"
        if bbPos then
            b.pos = DeepCopy(bbPos)
            b.anchor = false
        end
    end

    -- 輔助技能：錨在核心技能下緣
    local yOff = Num(Take(ctx, "utilityYOffset"))
    local spacing = Num(src.spacing)
    local wrap, unlock = Take(ctx, "utilityWrap"), Take(ctx, "utilityUnlock")
    local xRaw = Num(Take(ctx, "utilityXOffset"))
    local xOff = (wrap == true and unlock == true) and xRaw or nil
    b = Bar(ctx, "utility")
    if b and (yOff or spacing or xOff) then
        b.anchor = { to = "essential", point = "TOP", relPoint = "BOTTOM",
                     x = xOff or 0, y = -(spacing or 1) + (yOff or 0) }
    end
    if Take(ctx, "utilityVertical") == true and unlock == true and wrap == true then
        Skip(ctx, "utilityVertical", "noEquivalent", "other")
    end
end

------------------------------------------------------------
-- 2. 圖示尺寸、間距、每列上限、增益長條的外觀
------------------------------------------------------------
local function StepSizes(ctx)
    local ess, util, buffs, bb = Bar(ctx, "essential"), Bar(ctx, "utility"), Bar(ctx, "buffs"), Bar(ctx, "buffbars")
    local s1 = Size(Take(ctx, "sizeEssRow1"))
    if s1 and ess then Layout(ess).size = s1 end
    local s2 = Size(Take(ctx, "sizeEssRow2"))
    if s2 and ess then
        local row1 = Layout(ess).size
        if type(row1) == "table" and row1.w == s2.w and row1.h == s2.h then
            Layout(ess).row2Size = false
        else
            Layout(ess).row2Size = s2
        end
    end
    local su = Size(Take(ctx, "sizeUtility"))
    if su and util then Layout(util).size = su end
    local sb = Size(Take(ctx, "sizeBuff"))
    if sb and buffs then Layout(buffs).size = sb end

    local spacing = Num(Take(ctx, "spacing"))
    if spacing and spacing >= 0 then
        for _, b in ipairs({ ess, util, buffs }) do Layout(b).spacing = spacing end
    end

    local maxEss = Num(Take(ctx, "maxRowEss"))
    if maxEss and maxEss >= 1 and ess then Layout(ess).maxPerRow = math.floor(maxEss) end
    -- 輔助技能：沒開換列時它是一整排不換列；開了才看 maxRowUtil（對方預設 8）
    local maxUtil = Num(Take(ctx, "maxRowUtil"))
    if ctx.src.utilityWrap == true and util then
        Layout(util).maxPerRow = (maxUtil and maxUtil >= 1) and math.floor(maxUtil) or 8
    end

    -- 增益長條：寬 0 ＝ 跟核心技能第一列同寬，兩邊同義
    if bb then
        local bar = type(bb.bar) == "table" and bb.bar or {}
        bb.bar = bar
        local w = Num(Take(ctx, "buffBarWidth"))
        if w and w >= 0 then bar.width = w end
        local h = Num(Take(ctx, "buffBarHeight"))
        if h and h > 0 then
            bar.height = h
            local sz = type(Layout(bb).size) == "table" and Layout(bb).size or {}
            sz.h = h
            Layout(bb).size = sz
        end
        local sp = Num(Take(ctx, "buffBarSpacing"))
        if sp and sp >= 0 then Layout(bb).spacing = sp end
        local side = Take(ctx, "buffBarIconPosition")
        if side == "LEFT" or side == "RIGHT" then bar.iconSide = side
        elseif side == "HIDDEN" then bar.iconSide = "NONE" end
        local gap = Num(Take(ctx, "buffBarIconGap"))
        if gap and gap >= 0 then bar.iconGap = gap end
        local v = Take(ctx, "buffBarShowName")
        if type(v) == "boolean" then bar.showName = v end
        v = Num(Take(ctx, "buffBarNameFontSize"))
        if v and v > 0 then bar.nameSize = v end
        v = Take(ctx, "buffBarShowDuration")
        if type(v) == "boolean" then bar.showTime = v end
        v = Num(Take(ctx, "buffBarDurationFontSize"))
        if v and v > 0 then bar.timeSize = v end
        v = Take(ctx, "buffBarShowApplications")
        if type(v) == "boolean" then bar.showStacks = v end
        v = Num(Take(ctx, "buffBarApplicationsFontSize"))
        if v and v > 0 then bar.stackSize = v end
        v = Texture(Take(ctx, "buffBarTexture"))
        if v then bar.texture = v end
        v = Color(Take(ctx, "buffBarColor"))
        if v then bar.color = v end
        v = Color(Take(ctx, "buffBarBackgroundColor"))
        if v then bar.bgColor = v end
    end
end

------------------------------------------------------------
-- 3. 文字（字型、倒數、充能、層數）
------------------------------------------------------------
local OUTLINES = { [""] = "", NONE = "", OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE" }

local function StepText(ctx)
    local theme = ctx.out.theme
    local font = Str(Take(ctx, "textFont"))
    if font then theme.font = font end
    local outline = Take(ctx, "textFontOutline")
    if type(outline) == "string" then
        local o = OUTLINES[outline]
        if o == nil then
            o = outline:find("THICK") and "THICKOUTLINE" or (outline:find("OUTLINE") and "OUTLINE" or "")
            Approx(ctx, "textFontOutline", "outline flags reduced to " .. (o == "" and "none" or o))
        end
        theme.outline = o
    end

    local cd = theme.cooldownText
    local v = Num(Take(ctx, "cooldownFontSize"))
    if v and v > 0 then cd.size = v end
    v = Color(Take(ctx, "cooldownColor"))
    if v then cd.color = v end
    v = Num(Take(ctx, "cooldownDecimalThreshold"))
    if v and v >= 0 then cd.decimalsBelow = v end
    local lowOn = Take(ctx, "cooldownColorThresholdEnabled")
    local lowAt = Num(Take(ctx, "cooldownColorThreshold"))
    local lowColor = Color(Take(ctx, "cooldownColorThresholdColor"))
    if lowOn == true then
        cd.lowBelow = (lowAt and lowAt > 0) and lowAt or 5
        if lowColor then cd.lowColor = lowColor end
    elseif lowOn == false then
        cd.lowBelow = 0
    end

    local ch = theme.chargeText
    v = Num(Take(ctx, "chargeFontSize"))
    if v and v > 0 then ch.size = v end
    v = Color(Take(ctx, "chargeColor"))
    if v then ch.color = v end
    v = Point(Take(ctx, "chargePosition"))
    if v then ch.point = v end
    v = Num(Take(ctx, "chargeOffsetX"))
    if v then ch.x = v end
    v = Num(Take(ctx, "chargeOffsetY"))
    if v then ch.y = v end

    -- 層數（對方的「Main」＝主要那一排增益圖示；Sec／Tert 是舊版的第二、三排，已經拿掉了）
    local st = theme.stackText
    v = Num(Take(ctx, "countFontSize"))
    if v and v > 0 then st.size = v end
    v = Color(Take(ctx, "countColor"))
    if v then st.color = v end
    v = Point(Take(ctx, "countPositionMain"))
    if v then st.point = v end
    v = Num(Take(ctx, "countOffsetXMain"))
    if v then st.x = v end
    v = Num(Take(ctx, "countOffsetYMain"))
    if v then st.y = v end

    -- 輔助技能、增益圖示各自的字（跟主題一樣就不寫）
    v = Num(Take(ctx, "utilityCooldownFontSize"))
    if v and v > 0 then BarText(ctx, "utility", "cooldownText.size", v) end
    v = Num(Take(ctx, "utilityChargeFontSize"))
    if v and v > 0 then BarText(ctx, "utility", "chargeText.size", v) end
    BarText(ctx, "utility", "chargeText.color", Color(Take(ctx, "utilityChargeColor")))
    BarText(ctx, "utility", "chargeText.point", Point(Take(ctx, "utilityChargePosition")))
    BarText(ctx, "utility", "chargeText.x", Num(Take(ctx, "utilityChargeOffsetX")))
    BarText(ctx, "utility", "chargeText.y", Num(Take(ctx, "utilityChargeOffsetY")))
    v = Num(Take(ctx, "buffCooldownFontSize"))
    if v and v > 0 then BarText(ctx, "buffs", "cooldownText.size", v) end
    BarText(ctx, "buffs", "cooldownText.color", Color(Take(ctx, "buffCooldownColor")))
end

------------------------------------------------------------
-- 4. 圖示、邊框
------------------------------------------------------------
local function StepIcons(ctx)
    local icon, border = ctx.out.theme.icon, ctx.out.theme.border
    local zoomOn = Take(ctx, "zoomIcons")
    local zoom = Num(Take(ctx, "zoomAmount"))
    if zoomOn == false then
        icon.zoom = 0
    elseif zoom and zoom >= 0 and zoom < 0.5 then
        icon.zoom = zoom
    end
    local v = Color(Take(ctx, "swipeColor"))
    if v then icon.swipeColor = v end
    v = Take(ctx, "hideGCDSwipe")
    if type(v) == "boolean" then icon.hideGCDSwipe = v end
    v = Take(ctx, "disableCooldownDesat")
    if type(v) == "boolean" then icon.desaturateOnCooldown = not v end

    v = Num(Take(ctx, "borderSize"))
    if v and v >= 0 then border.size = v end
    v = Color(Take(ctx, "borderColor"))
    if v then border.color = v end
    local file = Str(Take(ctx, "borderFile"))
    if file then
        if file == "1 Pixel" or file == "Solid" or file == "None" then
            border.texture = "solid"
        else
            border.texture = file
            Approx(ctx, "borderFile", "LibSharedMedia border name kept as-is")
        end
    end
end

------------------------------------------------------------
-- 5. 發光、無損刷新
--
-- 無損刷新邊框在對方要三個條件都成立才有：hidePandemicIndicator（預設開）、
-- pandemicCustomizationEnabled、pandemicBorderEnabled（兩個預設關）。三個鍵有任一個出現在存檔裡
-- 就照「沒出現的用對方預設」算出結果寫進來；都沒出現就不動。
------------------------------------------------------------
local GLOW_TYPES = { pixel = true, autocast = true, button = true, proc = true }

local function StepGlow(ctx)
    local proc = ctx.out.theme.glow.proc
    local t = Take(ctx, "glowType")
    if GLOW_TYPES[t] then proc.type = t end
    local effType = GLOW_TYPES[t] and t or proc.type
    local useColor = Take(ctx, "glowUseCustomColor")
    local color = Color(Take(ctx, "glowColor"))
    if useColor == true and color then proc.color = color end

    local lines, thick, freq = Num(Take(ctx, "glowPixelLines")), Num(Take(ctx, "glowPixelThickness")), Num(Take(ctx, "glowPixelFrequency"))
    local particles, acFreq = Num(Take(ctx, "glowAutocastParticles")), Num(Take(ctx, "glowAutocastFrequency"))
    local btnFreq = Num(Take(ctx, "glowButtonFrequency"))
    if effType == "pixel" then
        if lines and lines >= 1 then proc.lines = math.floor(lines) end
        if thick and thick > 0 then proc.thickness = thick end
        if freq then proc.frequency = freq end
    elseif effType == "autocast" then
        if particles and particles >= 1 then proc.lines = math.floor(particles) end
        if acFreq then proc.frequency = acFreq end
    elseif effType == "button" then
        if btnFreq and btnFreq > 0 then proc.frequency = btnFreq end
    end

    local pan = ctx.out.theme.pandemic
    local hideInd = Take(ctx, "hidePandemicIndicator")
    local custom = Take(ctx, "pandemicCustomizationEnabled")
    local borderOn = Take(ctx, "pandemicBorderEnabled")
    if hideInd ~= nil or custom ~= nil or borderOn ~= nil then
        pan.enabled = (hideInd ~= false) and custom == true and borderOn == true
    end
    local pc = Color(Take(ctx, "pandemicBorderColor"))
    if pc then pan.color = pc end
    local pb = Take(ctx, "pandemicBorderColorBuffBars")
    if type(pb) == "boolean" then pan.bars = pb end
end

------------------------------------------------------------
-- 6. 淡出
--
-- 對方：以下任一成立就淡 —— 沒目標（fadingTriggerNoTarget，預設開）、脫戰（fadingTriggerOOC）、
-- 騎乘（fadingTriggerMounted）。本插件：騎乘勾了一律淡；否則「不淡出的時機」任一成立就完整顯示。
--   只有沒目標   ＝ keepWithTarget
--   只有脫戰     ＝ keepInCombat
--   兩個都開     ＝ 對方要「有目標而且在戰鬥中」才不淡，本插件表達不了「而且」 ⇒ 取 keepInCombat（近似）
--   只有騎乘     ＝ 本插件沒有「只在騎乘時淡」 ⇒ 兩個時機都勾（近似：脫戰又沒目標時也會淡）
--   都沒開       ＝ 不淡
-- 各條要不要跟著淡（fadingEssential…）：關掉的那條改成自己的淡出設定、關閉。
------------------------------------------------------------
local FADE_BARS = {
    { key = "fadingEssential", bar = "essential" },
    { key = "fadingUtility",   bar = "utility" },
    { key = "fadingBuffs",     bar = "buffs" },
    { key = "fadingBuffBars",  bar = "buffbars" },
}

local function StepFade(ctx)
    local fade = ctx.out.theme.fade
    local enabled = Take(ctx, "fadingEnabled")
    local noTarget, ooc, mounted = Take(ctx, "fadingTriggerNoTarget"), Take(ctx, "fadingTriggerOOC"), Take(ctx, "fadingTriggerMounted")
    local opacity = Num(Take(ctx, "fadingOpacity"))
    if opacity then
        local a = opacity / 100
        if a < 0 then a = 0 elseif a > 1 then a = 1 end
        fade.alpha = a
    end
    if enabled ~= nil or noTarget ~= nil or ooc ~= nil or mounted ~= nil then
        local nt = noTarget ~= false          -- 對方預設開
        local oc = ooc == true
        local mt = mounted == true
        fade.enabled = (enabled == true) and (nt or oc or mt)
        fade.whenMounted = mt
        if nt and oc then
            fade.keepInCombat, fade.keepWithTarget = true, false
            Approx(ctx, "fadingTriggerOOC", "no-target OR out-of-combat trigger reduced to out-of-combat")
        elseif nt then
            fade.keepInCombat, fade.keepWithTarget = false, true
        elseif oc then
            fade.keepInCombat, fade.keepWithTarget = true, false
        elseif mt then
            fade.keepInCombat, fade.keepWithTarget = true, true
            Approx(ctx, "fadingTriggerMounted", "mounted-only trigger also fades out of combat without a target")
        end
    end
    for _, f in ipairs(FADE_BARS) do
        local b = Bar(ctx, f.bar)
        if Take(ctx, f.key) == false and b then
            if type(b.follow) ~= "table" then b.follow = {} end
            b.follow.fade = false
            if type(b.fade) ~= "table" then b.fade = {} end
            b.fade.enabled = false
        end
    end
    local res = Take(ctx, "fadingResources")
    if res == false and type(ctx.out.resources) == "table" then ctx.out.resources.fadeWithEssential = false end
end

------------------------------------------------------------
-- 7. 資源條
--
-- 對方：resourceBarSettings[職業或 "General"][資源 key] = { color, conditions, height, … }，每一種資源一份；
-- 本插件：顏色與條件是逐資源的（resources.colors[key]、conditions[key]），列高、列距、寬、材質、
-- 數值文字是整條共用一份。共用的那幾格取「第一個有存值的」：先看玩家自己的職業，再看 General，
-- 其餘職業照名字排；不同資源存的值不一樣時記一筆近似。
--
-- 位置：對方的第一列預設貼在螢幕上（底邊中點在 CENTER + (offsetX, offsetY)，預設 (0, −200)，
-- 剛好是它的核心技能預設位置上緣再往上 1）。本插件預設錨在核心技能上緣 ⇒ 底邊跟核心技能上緣
-- 同一條中線、而且只差 0～20 像素時，當成「貼在核心技能上方」並把差距當 y；
-- 否則照螢幕座標存 pos（CENTER，資源條容器的錨點是 BOTTOM 中點，跟對方同一個點）。
------------------------------------------------------------
local RES_RENAME = { DevourerSoulFragments = "DevourerFragments" }

-- 規則的形狀兩邊一樣（Modules/ResourceConditions.lua 檔頭）；照白名單複製，壞的整條丟掉
local COND_VARS = { always = true, powerValue = true, powerPercent = true, powerFull = true, spec = true, pipRecharging = true }
local COND_BOOL = { powerFull = true, pipRecharging = true }
local COND_CMPS = { [">="] = true, [">"] = true, ["<="] = true, ["<"] = true, ["=="] = true, ["~="] = true }

local function CopyCheck(c, depth)
    if type(c) ~= "table" or depth > 4 then return nil end
    if c.op ~= nil then
        local out = {}
        for _, child in ipairs(type(c.children) == "table" and c.children or {}) do
            local x = CopyCheck(child, depth + 1)
            if x then out[#out + 1] = x end
        end
        if #out == 0 then return nil end
        if #out == 1 then return out[1] end
        return { op = "and", children = out }
    end
    if not COND_VARS[c.var] then return nil end
    if c.var == "always" then return { var = "always" } end
    if COND_BOOL[c.var] then
        if type(c.value) ~= "boolean" then return nil end
        return { var = c.var, value = c.value }
    end
    if not COND_CMPS[c.cmp] or not Num(c.value) then return nil end
    return { var = c.var, cmp = c.cmp, value = c.value }
end

local function CopyRules(list)
    if type(list) ~= "table" then return nil end
    local out = {}
    for _, rule in ipairs(list) do
        if type(rule) == "table" then
            local check = CopyCheck(rule.check, 1)
            local ov = type(rule.overrides) == "table" and rule.overrides or {}
            local o = {
                color = Color(ov.color), bgColor = Color(ov.bgColor), tagColor = Color(ov.tagColor),
                alpha = Num(ov.alpha),
            }
            if check and next(o) ~= nil then
                local t = Num(rule.target)
                out[#out + 1] = { target = (t and t >= 1) and math.floor(t) or nil, check = check, overrides = o }
            end
        end
    end
    if #out == 0 then return nil end
    return out
end
Import.CopyRules = CopyRules

-- 逐資源欄位 → 本插件 colors[key] 的哪一格
local RES_COLOR_FIELDS = {
    color = "color", chargedColor = "chargedColor", chargedEmptyColor = "chargedEmptyColor",
    moderateColor = "moderateColor", heavyColor = "heavyColor",
    tier3Color = "tier3Color", tier4Color = "tier4Color",        -- 醉仙緩勁第 3／4 段
}
-- 醉仙緩勁第 3／4 段：對方的欄位 → 本插件的設定
local STAGGER_TIER_FIELDS = {
    tier3Threshold = "staggerTier3At", tier4Threshold = "staggerTier4At",
    tier3Enabled = "staggerTier3Enabled", tier4Enabled = "staggerTier4Enabled",
}

-- 對方的「載入條件」→ 本插件分專精的開關 rows[specID][key]。
-- 職業分組（cls）底下的列只看那個職業的專精，General（法力）看全部；每個「這個 key 是候選」的專精，
-- wanted(specID) 跟那個專精的預設不同才寫（R.SetRow）。回傳 false ＝ 資源模組不在、沒辦法換算
local function ImportRows(res, cls, key, wanted)
    local R = ns.Resources
    if not (R and R.SetRow and R.SpecCandidates and R.CLASS_SPECS) then return false end
    local specs = (cls == "General") and R.AllSpecIDs() or R.CLASS_SPECS[cls] or {}
    for _, specID in ipairs(specs) do
        if R.SpecCandidates(specID)[key] then R.SetRow(res, specID, key, wanted(specID)) end
    end
    return true
end
Import.ImportRows = ImportRows

local function WantNever() return false end
local function WantAlways() return true end

-- loadMode：never ＝ 每個專精都關、always ＝ 每個專精都開、conditional ＝ 看 load.spec（專精集合）。
-- 沒存 loadMode 的照對方的預設（法力是 conditional，其他是 always）。專精以外的條件
-- （戰鬥中、騎乘、獵豹形態…）沒有逐列的對應，記略過
local function ImportLoad(ctx, res, cls, key, e, where)
    local mode = e.loadMode
    if mode == nil then mode = (key == "Mana") and "conditional" or "always" end
    local ok = true
    if mode == "never" then
        ok = ImportRows(res, cls, key, WantNever)
    elseif mode == "always" then
        ok = ImportRows(res, cls, key, WantAlways)
    elseif mode == "conditional" then
        local ld = type(e.load) == "table" and e.load or nil
        local set = ld and type(ld.spec) == "table" and ld.spec or nil
        if set then
            ok = ImportRows(res, cls, key, function(specID) return set[specID] == true end)
        end
        for k in pairs(ld or {}) do
            if k ~= "spec" then Skip(ctx, "resourceBarSettings.*.load." .. tostring(k), "noEquivalent", "resources") end
        end
    end
    if not ok then Skip(ctx, "resourceBarSettings." .. where .. ".loadMode", "noEquivalent", "resources") end
end
-- 共用欄位 → resources 的哪一格（值怎麼驗）
local RES_SHARED = {
    height     = { to = "rowHeight",  ok = function(v) return Num(v) and v > 0 and v end },
    width      = { to = "width",      ok = function(v) return Num(v) and v >= 0 and v end },
    barSpacing = { to = "rowSpacing", ok = function(v) return Num(v) and v >= 0 and v end },
    barTexture = { to = "texture",    ok = function(v) return Texture(v) end },
    tagEnabled = { to = "showText",   ok = function(v) if type(v) == "boolean" then return v end end },
    tagFontSize = { to = "textSize",  ok = function(v) return Num(v) and v > 0 and v end },
    smoothBars = { to = "smooth",     ok = function(v) if type(v) == "boolean" then return v end end },
}
-- 讀了但沒有對應的逐資源欄位（每種欄位只記一筆）
local RES_POS_FIELDS = { anchorTo = true, anchorPoint = true, anchorTargetPoint = true, offsetX = true, offsetY = true }

local LEGACY_RES_COLORS = {
    resourcesManaColor = { "Mana", "color" }, resourcesRageColor = { "Rage", "color" },
    resourcesEnergyColor = { "Energy", "color" }, resourcesFocusColor = { "Focus", "color" },
    resourcesComboPointsColor = { "ComboPoints", "color" },
    resourcesComboPointsChargedColor = { "ComboPoints", "chargedColor" },
    resourcesComboPointsChargedEmptyColor = { "ComboPoints", "chargedEmptyColor" },
    resourcesRunesReadyColor = { "Runes", "color" }, resourcesRunicPowerColor = { "RunicPower", "color" },
    resourcesSoulShardsColor = { "SoulShards", "color" }, resourcesLunarPowerColor = { "LunarPower", "color" },
    resourcesHolyPowerColor = { "HolyPower", "color" }, resourcesMaelstromColor = { "Maelstrom", "color" },
    resourcesChiColor = { "Chi", "color" }, resourcesInsanityColor = { "Insanity", "color" },
    resourcesArcaneChargesColor = { "ArcaneCharges", "color" }, resourcesFuryColor = { "Fury", "color" },
    resourcesEssenceColor = { "Essence", "color" }, resourcesSoulFragmentsColor = { "SoulFragments", "color" },
    resourcesDevourerSoulFragmentsColor = { "DevourerFragments", "color" },
    resourcesIronfurColor = { "Ironfur", "color" }, resourcesIgnorePainColor = { "IgnorePain", "color" },
    resourcesTipOfTheSpearColor = { "TipOfTheSpear", "color" },
    resourcesStaggerLightColor = { "Stagger", "color" }, resourcesStaggerModerateColor = { "Stagger", "moderateColor" },
    resourcesStaggerHeavyColor = { "Stagger", "heavyColor" },
}
local LEGACY_RES_SHARED = {
    resourcesBarHeight = "height", resourcesBarWidth = "width", resourcesBarSpacing = "barSpacing",
    resourcesBarTexture = "barTexture", resourcesBar1TagFontSize = "tagFontSize",
}

local function ClassOrder(rbs, prefer)
    local list = {}
    for cls, t in pairs(rbs) do
        if type(t) == "table" then list[#list + 1] = cls end
    end
    local function rank(c)
        if c == prefer then return 1 end
        if c == "General" then return 2 end
        return 3
    end
    table.sort(list, function(a, b)
        local ra, rb = rank(a), rank(b)
        if ra ~= rb then return ra < rb end
        return tostring(a) < tostring(b)
    end)
    return list
end

local function PlaceResources(ctx, res, rootEntry)
    local e = rootEntry
    local to = e.anchorTo
    local aP, tP = Point(e.anchorPoint) or "BOTTOM", Point(e.anchorTargetPoint) or "TOP"
    local ox, oy = Num(e.offsetX) or 0, Num(e.offsetY) or -200
    if to == "essential" then
        res.anchor = { to = "essential", point = aP, relPoint = tP, x = ox, y = oy }
        return
    end
    if to ~= nil and to ~= "screen" then
        Approx(ctx, "resourceBarSettings.anchorTo", "anchored to " .. tostring(to) .. "; kept default placement")
        return
    end
    -- 螢幕座標：底邊中點在 CENTER + (ox, oy)。跟核心技能的上緣比（沒存 ＝ 對方預設 (0, −201)）
    local ess = ctx.essPos or { point = "CENTER", x = 0, y = -201 }
    local gap = oy - ess.y
    if ess.point == "CENTER" and ess.x == ox and gap >= 0 and gap <= 20 then
        res.anchor = { to = "essential", point = "BOTTOM", relPoint = "TOP", x = 0, y = gap }
    else
        res.anchor = false
        res.pos = { point = "CENTER", x = ox, y = oy }
    end
end

local function StepResources(ctx)
    local res = ctx.out.resources
    if type(res) ~= "table" then return end
    local v = Take(ctx, "resourcesEnabled")
    if type(v) == "boolean" then res.enabled = v end
    local fmt = Take(ctx, "manaNumberFormat")
    if fmt == "wan" then res.manaAbbrev = "wan"
    elseif fmt == "km" then res.manaAbbrev = "k"
    elseif fmt == "raw" then res.manaAbbrev = "none" end

    local colors = type(res.colors) == "table" and res.colors or {}
    res.colors = colors
    local rbs = Take(ctx, "resourceBarSettings")
    local shared, sharedFrom = {}, {}

    local function SetShared(field, value, where)
        local spec = RES_SHARED[field]
        local ok = spec and spec.ok(value)
        if ok == nil or ok == false and type(value) ~= "boolean" then return end
        if sharedFrom[spec.to] == nil then
            shared[spec.to], sharedFrom[spec.to] = ok, where
        elseif shared[spec.to] ~= ok then
            Approx(ctx, "resourceBarSettings.*." .. field, ("bars differ; used %s from %s"):format(tostring(shared[spec.to]), sharedFrom[spec.to]))
        end
    end

    local colorSeen = {}
    local function SetColor(key, field, c, where)
        c = Color(c)
        if not (c and type(colors[key]) == "table") then return false end
        local id = key .. "." .. field
        if colorSeen[id] then return true end
        colorSeen[id] = where
        colors[key][field] = c
        return true
    end

    if type(rbs) ~= "table" then
        -- 更舊的存檔（還沒改成逐資源存）：從平鋪的舊鍵讀
        local any = false
        for legacyKey, target in pairs(LEGACY_RES_COLORS) do
            local c = Take(ctx, legacyKey)
            if c ~= nil then any = true; SetColor(target[1], target[2], c, legacyKey) end
        end
        for legacyKey, field in pairs(LEGACY_RES_SHARED) do
            local lv = Take(ctx, legacyKey)
            if lv ~= nil then any = true; SetShared(field, lv, legacyKey) end
        end
        local pct = Take(ctx, "resourcesManaPercentage")
        if type(pct) == "boolean" then any = true; res.manaPercent = pct end
        for k, val in pairs(shared) do res[k] = val end
        if any then Approx(ctx, "resources*", "read from the old flat keys") end
        return
    end

    local rootEntry
    for _, cls in ipairs(ClassOrder(rbs, ctx.opts.class)) do
        for _, rawKey in ipairs(SortedKeys(rbs[cls])) do
            local e = rbs[cls][rawKey]
            local key = RES_RENAME[rawKey] or rawKey
            local where = tostring(cls) .. "." .. tostring(rawKey)
            if type(e) == "table" then
                if type(colors[key]) ~= "table" then
                    Skip(ctx, "resourceBarSettings." .. where, "noEquivalent", "resources")
                else
                    for _, field in ipairs(SortedKeys(e)) do
                        local val = e[field]
                        if RES_COLOR_FIELDS[field] then
                            SetColor(key, RES_COLOR_FIELDS[field], val, where)
                        elseif field == "lightColor" then
                            SetColor(key, "color", val, where)          -- 醉仙緩勁的輕度＝主色
                        elseif RES_SHARED[field] then
                            SetShared(field, val, where)
                        elseif field == "conditions" then
                            -- 同一個資源在對方好幾個職業底下都有時第一筆贏。不能看 res.conditions[key]
                            -- 是不是 nil：輸出從預設設定檔開始，預設本身就帶了幾個資源的規則，匯入的要蓋過它
                            local rules = CopyRules(val)
                            ctx.condSet = ctx.condSet or {}
                            if rules and not ctx.condSet[key] then
                                ctx.condSet[key] = true
                                if type(res.conditions) ~= "table" then res.conditions = {} end
                                res.conditions[key] = rules
                                ctx.R.counts.conditions = ctx.R.counts.conditions + #rules
                            end
                        elseif field == "displayAsPercent" and key == "Mana" then
                            if type(val) == "boolean" then res.manaPercent = val end
                        elseif field == "loadMode" then
                            ImportLoad(ctx, res, cls, key, e, where)
                        elseif field == "load" then
                            -- 有 loadMode 時跟它一起看（上面）；沒存 loadMode 的照對方的預設模式
                            if e.loadMode == nil then ImportLoad(ctx, res, cls, key, e, where) end
                        elseif field == "tier1Threshold" and key == "Stagger" then
                            if e.tier1Enabled ~= false and Num(val) then res.staggerModerateAt = val end
                        elseif field == "tier2Threshold" and key == "Stagger" then
                            if e.tier2Enabled ~= false and Num(val) then res.staggerHeavyAt = val end
                        elseif (field == "tier1Enabled" or field == "tier2Enabled") and key == "Stagger" then
                            if val == false then Approx(ctx, "resourceBarSettings." .. where .. "." .. field, "stagger tier can't be turned off") end
                        elseif STAGGER_TIER_FIELDS[field] and key == "Stagger" then
                            local to = STAGGER_TIER_FIELDS[field]
                            if field:find("Enabled") then
                                if type(val) == "boolean" then res[to] = val end
                            elseif Num(val) and val > 0 then
                                res[to] = val
                            end
                        elseif field == "ceilingPercent" and key == "Stagger" then
                            if Num(val) and val > 0 then res.staggerCeiling = math.min(val, 300) end
                        elseif RES_POS_FIELDS[field] then
                            -- 位置：下面挑一列算
                        elseif field == "tagAnchor" or field == "tagOffsetX" or field == "tagOffsetY" then
                            local centered = (field == "tagAnchor" and val == "CENTER") or (field ~= "tagAnchor" and val == 0)
                            if not centered then Skip(ctx, "resourceBarSettings.*." .. field, "noEquivalent", "resources") end
                        elseif field == "tagColor" then
                            -- 數值文字一律白字；存的也是白色就不算沒匯入
                            local c = Color(val)
                            if not (c and c.r == 1 and c.g == 1 and c.b == 1) then
                                Skip(ctx, "resourceBarSettings.*.tagColor", "noEquivalent", "resources")
                            end
                        else
                            Skip(ctx, "resourceBarSettings.*." .. tostring(field), "noEquivalent", "resources")
                        end
                    end
                    -- 第一列的位置：第一個貼在螢幕（或核心技能）上、而且有存位置的
                    if not rootEntry and (e.offsetX ~= nil or e.offsetY ~= nil or e.anchorTo ~= nil)
                       and (e.anchorTo == nil or e.anchorTo == "screen" or e.anchorTo == "essential") then
                        rootEntry = e
                    end
                end
            end
        end
    end
    for k, val in pairs(shared) do res[k] = val end
    if rootEntry then PlaceResources(ctx, res, rootEntry) end
end

------------------------------------------------------------
-- 8. 施法條
------------------------------------------------------------
local CAST_COLORS = {
    castBarCastColor = "cast", castBarChannelColor = "channel", castBarUninterruptibleColor = "uninterruptible",
    castBarEmpowerStage1Color = "empowerStage1", castBarEmpowerStage2Color = "empowerStage2",
    castBarEmpowerStage3Color = "empowerStage3", castBarEmpowerStage4Color = "empowerStage4",
}

local function StepCastbar(ctx)
    local cb = ctx.out.castbar
    if type(cb) ~= "table" then return end
    local function B(key, field)
        local v = Take(ctx, key)
        if type(v) == "boolean" then cb[field] = v end
    end
    B("castBarEnabled", "enabled")
    B("hideBlizzardCastBar", "hideBlizzard")
    B("castBarShowSpellName", "showName")
    B("castBarShowTimer", "showTime")
    B("castBarShowSpark", "showSpark")
    B("castBarShowIcon", "showIcon")
    B("castBarUseClassColor", "useClassColor")
    local v = Num(Take(ctx, "castBarWidth"))
    if v and v >= 0 then cb.width = v end
    local src = Take(ctx, "castBarAutoWidthSource")
    if (cb.width or 0) == 0 and src ~= nil and src ~= "essential" then
        Approx(ctx, "castBarAutoWidthSource", "auto width follows Essential here")
    end
    v = Num(Take(ctx, "castBarHeight"))
    if v and v > 0 then cb.height = v end
    v = Num(Take(ctx, "castBarFontSize"))
    if v and v > 0 then cb.textSize = v end
    v = Num(Take(ctx, "castBarNameMaxChars"))
    if v and v >= 0 then cb.nameMaxChars = math.floor(v) end
    v = Take(ctx, "castBarShowTotalDuration")
    if v == true then cb.timeFormat = "remainTotal" elseif v == false then cb.timeFormat = "remain" end
    v = Take(ctx, "castBarIconPosition")
    if v == "LEFT" or v == "RIGHT" then cb.iconSide = v end
    v = Num(Take(ctx, "castBarIconGap"))
    if v and v >= 0 then cb.iconGap = v end
    v = Texture(Take(ctx, "castBarTexture"))
    if v then cb.texture = v end
    -- 對方「用暴雪的施法條圖」勾著 ⇒ 對到我們的「暴雪施法條」（顏色仍照下面的施法色，不是暴雪原色）
    if Take(ctx, "castBarUseAtlasTextures") == true then cb.texture = "blizzard" end
    v = Color(Take(ctx, "castBarBackgroundColor"))
    if v then cb.bgColor = v end
    if type(cb.colors) ~= "table" then cb.colors = {} end
    for key, field in pairs(CAST_COLORS) do
        local c = Color(Take(ctx, key))
        if c then cb.colors[field] = c end
    end

    -- 位置：五個鍵任一個有存才動（沒存的用對方預設：跟著資源條、BOTTOM → TOP、(0, 1)）
    local mode = Take(ctx, "castBarAnchor")
    local aP0, tP0 = Take(ctx, "castBarAnchorPoint"), Take(ctx, "castBarTargetPoint")
    local ox0, oy0 = Take(ctx, "castBarOffsetX"), Take(ctx, "castBarOffsetY")
    if mode == nil and aP0 == nil and tP0 == nil and ox0 == nil and oy0 == nil then return end
    mode = mode or "resources"
    local aP, tP = Point(aP0) or "BOTTOM", Point(tP0) or "TOP"
    local ox, oy = Num(ox0) or 0, Num(oy0) or 1
    local h = Num(cb.height) or 20
    local w = Num(cb.width) or 0
    -- 施法條容器的錨點是中心：對方貼的那一點換算成中心
    local px, py = PointXY(aP, w, h)
    local dx, dy = w / 2 - px, h / 2 - py
    if w == 0 and HSide(aP) ~= "CENTER" then
        Approx(ctx, "castBarAnchorPoint", "auto width; horizontal edge anchor treated as centered")
        dx = 0
    end
    if mode == "resources" then
        -- 本插件的排開會把它放在資源條外面（兩個都跟著核心技能上方）＝對方的「貼在資源條上」
        cb.anchor = { to = "essential", point = aP, relPoint = tP, x = ox, y = oy }
    elseif mode == "essential" or mode == "utility" then
        local to = mode
        if StacksVertically(aP, tP) then
            -- 照字面貼：換成中心點、偏移補半高，才不會被排到資源條外面
            cb.anchor = { to = to, point = "CENTER", relPoint = tP, x = ox + dx, y = oy + dy }
        else
            cb.anchor = { to = to, point = aP, relPoint = tP, x = ox, y = oy }
        end
    elseif mode == "screen" then
        cb.anchor = false
        cb.pos = { point = tP, x = ox + dx, y = oy + dy }
    else
        Approx(ctx, "castBarAnchor", "anchor target " .. tostring(mode) .. " not supported; kept default placement")
    end
end

------------------------------------------------------------
-- 9. 自訂群組（cooldownGroups／buffGroups／barGroups，逐專精）
--
-- 對方的群組容器只有一格大，錨點 anchorPoint 貼目標的 anchorRelativeTo（或螢幕 CENTER）＋偏移；
-- 第一格圖示貼在容器的 anchorPoint 上，用哪一個點看成長方向：往右長＝圖示的左側、往左長＝右側、
-- 往下長＝上緣、往上長＝下緣（另一半沿用 anchorPoint）；CENTER_H／CENTER_V 置中＝就用 anchorPoint。
--
-- 本插件的容器是整塊圖示的外框，錨點由成長方向決定（Core/Layout.lua）。換算：
--   成長方向  RIGHT → LEFT_<V>、LEFT → RIGHT_<V>（列內順序固定由左到右 ⇒ **清單反過來**，第一格才會在最右）、
--             DOWN／UP → 一列一格（maxPerRow = 1）、CENTER_H → CENTER_<V>、CENTER_V → 一列一格
--   位置     以「第一格圖示」為基準算出外框錨點那一點的偏移（單列時兩者重合；多列是近似）
--   錨定     錨在檢視器上時用 anchor = { to, point, relPoint, x, y }；點若是上下疊的組合（BOTTOM → TOP…）
--            會被「錨定的排開」排到資源條／施法條外面，所以換成同一側的中線點、偏移補半格高，照字面貼
------------------------------------------------------------
local GROUP_SOURCES = {
    { key = "cooldownGroups", kind = "icons", resolve = "cooldown" },
    { key = "buffGroups",     kind = "icons", resolve = "buff" },
    { key = "barGroups",      kind = "bars",  resolve = "buff" },
}
local GROUP_TARGET = { essential = "essential", utility = "utility", buff = "buffs", resources = "resources" }
local GROW_OK = { RIGHT = true, LEFT = true, UP = true, DOWN = true, CENTER_H = true, CENTER_V = true }

-- 回傳 layout 片段與位置：{ grow, maxPerRow, reverse, anchor | pos }
function Import.GroupPlacement(g, kind)
    local w = Num(g.iconWidth) or 30
    local h = Num(g.iconHeight) or 30
    if kind == "bars" then
        w = Num(g.barWidth) or 0
        if w <= 0 then w = 200 end
        h = Num(g.barHeight) or 20
    end
    local grow = GROW_OK[g.grow] and g.grow or "RIGHT"
    if kind == "bars" then grow = (g.grow == "UP" or g.grow == "CENTER_UP") and "UP" or "DOWN" end
    local anchorPoint = Point(g.anchorPoint) or "CENTER"
    local rel = Point(g.anchorRelativeTo) or "CENTER"
    local ox, oy = Num(g.offsetX) or 0, Num(g.offsetY) or 0
    local perRow = Num(g.maxPerRow)
    perRow = (perRow and perRow >= 1) and math.floor(perRow) or UNLIMITED_PER_ROW

    -- 第一格用哪一個點貼在容器的 anchorPoint 上
    local ah, av = HSide(anchorPoint), VSide(anchorPoint)
    local first = anchorPoint
    if grow == "RIGHT" then first = Compose("LEFT", av)
    elseif grow == "LEFT" then first = Compose("RIGHT", av)
    elseif grow == "DOWN" then first = Compose(ah, "TOP")
    elseif grow == "UP" then first = Compose(ah, "BOTTOM") end

    local out = { reverse = false, approx = nil }
    local vdir = (av == "BOTTOM") and "UP" or "DOWN"
    if kind == "bars" then
        out.grow, out.maxPerRow = (grow == "UP") and "CENTER_UP" or "CENTER_DOWN", 1
        out.approx = "bar group placement is approximate"
    elseif grow == "RIGHT" then
        out.grow, out.maxPerRow = "LEFT_" .. vdir, perRow
    elseif grow == "LEFT" then
        out.grow, out.maxPerRow, out.reverse = "RIGHT_" .. vdir, perRow, true
    elseif grow == "DOWN" or grow == "UP" or grow == "CENTER_V" then
        out.grow, out.maxPerRow = ah .. "_" .. (grow == "UP" and "UP" or "DOWN"), 1
        if (grow == "DOWN" or grow == "UP") and Num(g.maxPerRow) and g.maxPerRow >= 1 then
            out.approx = "wrapping columns aren't supported; one column"
        end
    else -- CENTER_H
        out.grow, out.maxPerRow = "CENTER_" .. vdir, perRow
    end
    -- 本插件外框的錨點（Core/Layout.lua 的 AnchorPoint 同一套規則）
    local gh, gv = out.grow:match("^(%u+)_(%u+)$")
    local A = Compose(kind == "bars" and "CENTER" or gh, gv == "UP" and "BOTTOM" or "TOP")

    local target = g.anchorTarget or "screen"
    local sx, sy = PointXY(first, w, h)
    if GROUP_TARGET[target] then
        local B = A
        if grow == "CENTER_V" then B = anchorPoint end
        if StacksVertically(B, rel) then B = Compose(HSide(B), "CENTER") end
        local bx, by = PointXY(B, w, h)
        out.anchor = { to = GROUP_TARGET[target], point = B, relPoint = rel, x = ox + bx - sx, y = oy + by - sy }
    elseif target == "screen" then
        -- 容器（一格大）中心在 CENTER + 偏移 ⇒ 容器的 anchorPoint 在哪
        local cx, cy = PointXY(anchorPoint, w, h)
        local qx, qy = ox + cx - w / 2, oy + cy - h / 2
        local bx, by = PointXY(A, w, h)
        out.pos = { point = "CENTER", x = qx + bx - sx, y = qy + by - sy }
        if grow == "CENTER_V" then out.approx = "vertically centered column placed by its top edge" end
    else
        out.pos = { point = "CENTER", x = 0, y = 0 }
        out.approx = "anchor target " .. tostring(target) .. " not supported; placed at screen center"
    end
    return out
end

local function NextBarKey(bars)
    local n = 1
    while bars["g" .. n] ~= nil do n = n + 1 end
    return "g" .. n
end

-- 群組自己的文字：對方每個群組都存一整組，跟主題一樣的不寫
local GROUP_TEXT = {
    { key = "cooldownFontSize", path = "cooldownText.size",  num = true },
    { key = "cooldownColor",    path = "cooldownText.color", color = true },
    { key = "chargeFontSize",   path = "chargeText.size",    num = true },
    { key = "chargeColor",      path = "chargeText.color",   color = true },
    { key = "chargePosition",   path = "chargeText.point",   point = true },
    { key = "chargeOffsetX",    path = "chargeText.x",       num = true, any = true },
    { key = "chargeOffsetY",    path = "chargeText.y",       num = true, any = true },
    { key = "countFontSize",    path = "stackText.size",     num = true },
    { key = "countColor",       path = "stackText.color",    color = true },
    { key = "countPosition",    path = "stackText.point",    point = true },
    { key = "countOffsetX",     path = "stackText.x",        num = true, any = true },
    { key = "countOffsetY",     path = "stackText.y",        num = true, any = true },
}
local GROUP_HANDLED = {
    name = true, spells = true, iconWidth = true, iconHeight = true, barWidth = true, barHeight = true,
    spacing = true, grow = true, maxPerRow = true, anchorPoint = true, anchorRelativeTo = true,
    anchorTarget = true, offsetX = true, offsetY = true, spellOverrides = true,
}
for _, t in ipairs(GROUP_TEXT) do GROUP_HANDLED[t.key] = true end

-- 群組名撞名（同名群組出現在好幾個專精）時加上專精名
local function GroupNames(ctx)
    local count = {}
    for _, gs in ipairs(GROUP_SOURCES) do
        local all = ctx.src[gs.key]
        for _, spec in ipairs(SortedKeys(all)) do
            local list = all[spec]
            if type(list) == "table" then
                for i, g in ipairs(list) do
                    if type(g) == "table" then
                        local n = Str(g.name) or ("Group " .. i)
                        count[n] = (count[n] or 0) + 1
                    end
                end
            end
        end
    end
    return count
end

local function PendingFor(ctx, specID)
    local all = ctx.out.pendingImport
    if type(all) ~= "table" then all = {}; ctx.out.pendingImport = all end
    local p = all[specID]
    if type(p) ~= "table" then p = {}; all[specID] = p end
    return p
end

local MapOverride   -- 前置宣告（第 11 節）

local function StepGroups(ctx)
    local out = ctx.out
    out.bars = type(out.bars) == "table" and out.bars or {}
    out.barOrder = type(out.barOrder) == "table" and out.barOrder or {}
    ctx.groupOf = {}       -- [specID][spellID] = barKey（光環格要知道自己在哪個群組）
    local nameCount = GroupNames(ctx)
    for _, gs in ipairs(GROUP_SOURCES) do
        local all = Take(ctx, gs.key)
        for _, spec in ipairs(SortedKeys(all)) do
            local list = all[spec]
            local specID = tonumber(spec)
            if specID and type(list) == "table" then
                for i, g in ipairs(list) do
                    if type(g) == "table" then
                        local key = NextBarKey(out.bars)
                        local name = Str(g.name) or ("Group " .. i)
                        if (nameCount[name] or 0) > 1 then
                            local sn = ctx.opts.specName and ctx.opts.specName(specID)
                            name = ("%s (%s)"):format(name, Str(sn) or tostring(specID))
                        end
                        local bar = ctx.opts.newBar and ctx.opts.newBar(gs.kind, name) or nil
                        if type(bar) ~= "table" then
                            bar = { kind = gs.kind, source = "custom", name = name,
                                    follow = { text = true, icon = true, glow = true, fade = true },
                                    text = {}, icon = {}, glow = {}, fade = {}, layout = {}, anchor = false,
                                    pos = { point = "CENTER", x = 0, y = 0 } }
                        end
                        out.bars[key] = bar
                        out.barOrder[#out.barOrder + 1] = key
                        ctx.R.counts.groups = ctx.R.counts.groups + 1

                        local lay = Layout(bar)
                        local place = Import.GroupPlacement(g, gs.kind)
                        lay.grow, lay.maxPerRow = place.grow, place.maxPerRow
                        if gs.kind == "bars" then
                            if type(bar.bar) ~= "table" then bar.bar = {} end
                            local bw = Num(g.barWidth)
                            if bw and bw >= 0 then bar.bar.width = bw end
                            local bh = Num(g.barHeight)
                            if bh and bh > 0 then
                                bar.bar.height = bh
                                lay.size = { w = (bw and bw > 0) and bw or 200, h = bh }
                            end
                        else
                            local w, h = Num(g.iconWidth), Num(g.iconHeight)
                            if w and h and w > 0 and h > 0 then lay.size = { w = w, h = h } end
                        end
                        local sp = Num(g.spacing)
                        if sp and sp >= 0 then lay.spacing = sp end
                        if place.anchor then
                            bar.anchor, bar.pos = place.anchor, bar.pos or { point = "CENTER", x = 0, y = 0 }
                        else
                            bar.anchor, bar.pos = false, place.pos
                        end
                        if place.approx then Approx(ctx, gs.key .. "." .. spec .. "." .. i, place.approx) end

                        -- 文字
                        for _, t in ipairs(GROUP_TEXT) do
                            local raw = g[t.key]
                            local val
                            if t.color then val = Color(raw)
                            elseif t.point then val = Point(raw)
                            else val = Num(raw); if val and not t.any and val <= 0 then val = nil end end
                            if val ~= nil then
                                local themeV = GetPath(out.theme, t.path)
                                if not (val == themeV or SameColor(val, themeV)) then
                                    bar.follow.text = false
                                    SetPath(bar.text, t.path, val)
                                end
                            end
                        end
                        for _, field in ipairs(SortedKeys(g)) do
                            if not GROUP_HANDLED[field] then
                                Skip(ctx, gs.key .. ".*." .. tostring(field), "noEquivalent", "groups")
                            end
                        end

                        -- 法術：先全部進 pending，目前專精最後一起換
                        local spells = {}
                        ctx.groupOf[specID] = ctx.groupOf[specID] or {}
                        for _, sid in ipairs(type(g.spells) == "table" and g.spells or {}) do
                            sid = Num(sid)
                            if sid then
                                ctx.groupOf[specID][sid] = key
                                -- 自訂光環格（customBuffRegistry）不是 cooldownID，第 10 節處理
                                local reg = type(ctx.src.customBuffRegistry) == "table" and ctx.src.customBuffRegistry[sid]
                                if not (type(reg) == "table" and reg.kind == "aura") then spells[#spells + 1] = sid end
                            end
                        end
                        if place.reverse then
                            local rev = {}
                            for j = #spells, 1, -1 do rev[#rev + 1] = spells[j] end
                            spells = rev
                        end
                        if #spells > 0 then
                            local p = PendingFor(ctx, specID)
                            p.groups = p.groups or {}
                            p.groups[#p.groups + 1] = { bar = key, kind = gs.resolve, spells = spells }
                        end
                        -- 群組裡的逐法術覆寫（spellID 為鍵）
                        if type(g.spellOverrides) == "table" then
                            for _, sk in ipairs(SortedKeys(g.spellOverrides)) do
                                local fields = MapOverride(ctx, gs.key .. ".spellOverrides", g.spellOverrides[sk])
                                local sid = tonumber(sk)
                                if fields and sid then
                                    local p = PendingFor(ctx, specID)
                                    p.overrides = p.overrides or {}
                                    p.overrides[#p.overrides + 1] = { spellID = sid, kind = gs.resolve, fields = fields }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

------------------------------------------------------------
-- 10. 自訂光環格
--
-- 對方：customBuffRegistry[spellID] = { kind = "aura", auraFilter, placeholder, hideCooldownText, … }
-- 是帳號層的登記，哪個專精顯示看 ungroupedCustomBuffOrder[specID] = { { spellID, afterNative }, … }
-- （或放在那個專精的增益群組裡）。本插件的光環格是逐專精的 spells[specID].custom，
-- 光環格永遠排在該條最前面（afterNative 的相對順序不帶）。
-- 不是光環格的登記（施放後固定秒數的計時）本插件沒有 ⇒ 略過。
------------------------------------------------------------
local function EnsureSpec(profile, specID)
    if type(profile.spells) ~= "table" then profile.spells = {} end
    local sp = profile.spells[specID]
    if type(sp) ~= "table" then sp = {}; profile.spells[specID] = sp end
    for _, k in ipairs({ "order", "groupOf", "hidden", "overrides" }) do
        if type(sp[k]) ~= "table" then sp[k] = {} end
    end
    return sp
end
Import.EnsureSpec = EnsureSpec

local function StepAuras(ctx)
    local reg = Take(ctx, "customBuffRegistry")
    local orders = Take(ctx, "ungroupedCustomBuffOrder")
    reg = type(reg) == "table" and reg or {}
    ctx.auraIndex = {}          -- [specID][spellID] = "c:<i>"
    local placed = {}
    local function Add(specID, sid, bar)
        local e = reg[sid]
        if type(e) ~= "table" or e.kind ~= "aura" then return end
        local sp = EnsureSpec(ctx.out, specID)
        sp.custom = type(sp.custom) == "table" and sp.custom or {}
        local filter = e.auraFilter == "HARMFUL" and "HARMFUL" or "HELPFUL"
        for _, x in ipairs(sp.custom) do
            if x.kind == "aura" and x.spellID == sid and (x.filter or "HELPFUL") == filter then return end
        end
        sp.custom[#sp.custom + 1] = { kind = "aura", spellID = sid, filter = filter,
                                      placeholder = e.placeholder ~= false, bar = bar }
        local id = "c:" .. #sp.custom
        ctx.auraIndex[specID] = ctx.auraIndex[specID] or {}
        ctx.auraIndex[specID][sid] = id
        if e.hideCooldownText == true then
            sp.overrides[id] = sp.overrides[id] or {}
            sp.overrides[id].hideCooldownText = true
        end
        placed[sid] = true
        ctx.R.counts.auras = ctx.R.counts.auras + 1
    end
    if type(orders) == "table" then
        for _, spec in ipairs(SortedKeys(orders)) do
            local specID = tonumber(spec)
            if specID and type(orders[spec]) == "table" then
                for _, o in ipairs(orders[spec]) do
                    local sid = type(o) == "table" and Num(o.spellID) or Num(o)
                    if sid then Add(specID, sid, "buffs") end
                end
            end
        end
    end
    -- 放在增益群組裡的光環格：進那個群組（只收圖示群組）
    for specID, map in pairs(ctx.groupOf or {}) do
        for sid, barKey in pairs(map) do
            local e = reg[sid]
            local bar = Bar(ctx, barKey)
            if type(e) == "table" and e.kind == "aura" and bar then
                Add(specID, sid, bar.kind == "bars" and "buffs" or barKey)
            end
        end
    end
    for _, sid in ipairs(SortedKeys(reg)) do
        local e = reg[sid]
        if type(e) == "table" and e.kind ~= "aura" then
            Skip(ctx, "customBuffRegistry." .. tostring(sid), "noEquivalent", "customBuffs")
        elseif type(e) == "table" and not placed[sid] then
            Approx(ctx, "customBuffRegistry." .. tostring(sid), "registered but not shown in any specialization")
        end
    end
end

------------------------------------------------------------
-- 11. 逐法術覆寫
--
-- 對得上的只有這幾格（其他欄位本插件沒有逐法術的版本，記進報告）：
--   hideCooldown              → hideCooldownText
--   soundEnabled＋soundOnShow  → gainSound（soundOnShowEnabled ~= false）
--   soundEnabled＋soundOnHide  → loseSound（soundOnHideEnabled ~= false）
-- ungroupedCooldownOverrides 本來就用 cooldownID 當鍵，直接寫；增益／長條那兩張用 spellID，進 pending。
-- spellRegistry[specID].glowEnabled／glowColors（增益群組裡逐法術的「啟用發光」）→ activeGlow／activeGlowColor，
-- 一樣用 spellID 進 pending（kind "buff"）。對到自訂光環格的不收：生效發光只畫在暴雪的增益格上。
-- 同一張的 colors（逐法術邊框色）沒有對應。
------------------------------------------------------------
local OVERRIDE_HANDLED = { hideCooldown = true, soundEnabled = true, soundOnShow = true, soundOnHide = true,
                           soundOnShowEnabled = true, soundOnHideEnabled = true }

MapOverride = function(ctx, where, t)
    if type(t) ~= "table" then return nil end
    local o = {}
    if t.hideCooldown == true then o.hideCooldownText = true end
    if t.soundEnabled == true then
        if t.soundOnShowEnabled ~= false and Str(t.soundOnShow) then o.gainSound = t.soundOnShow end
        if t.soundOnHideEnabled ~= false and Str(t.soundOnHide) then o.loseSound = t.soundOnHide end
    end
    for _, field in ipairs(SortedKeys(t)) do
        if not OVERRIDE_HANDLED[field] then
            Skip(ctx, where .. ".*." .. tostring(field), "noEquivalent", "overrides")
        end
    end
    if next(o) == nil then return nil end
    return o
end

local function StepOverrides(ctx)
    local cdo = Take(ctx, "ungroupedCooldownOverrides")
    for _, spec in ipairs(SortedKeys(cdo)) do
        local specID, map = tonumber(spec), cdo[spec]
        if specID and type(map) == "table" then
            for _, id in ipairs(SortedKeys(map)) do
                local cd = tonumber(id)
                local fields = MapOverride(ctx, "ungroupedCooldownOverrides", map[id])
                if cd and fields then
                    local sp = EnsureSpec(ctx.out, specID)
                    sp.overrides[cd] = sp.overrides[cd] or {}
                    for k, v in pairs(fields) do sp.overrides[cd][k] = v end
                    ctx.R.counts.overrides = ctx.R.counts.overrides + 1
                end
            end
        end
    end
    for _, tk in ipairs({ "ungroupedBuffOverrides", "ungroupedBarOverrides" }) do
        local all = Take(ctx, tk)
        for _, spec in ipairs(SortedKeys(all)) do
            local specID, map = tonumber(spec), all[spec]
            if specID and type(map) == "table" then
                for _, sk in ipairs(SortedKeys(map)) do
                    local sid = tonumber(sk)
                    local fields = MapOverride(ctx, tk, map[sk])
                    if sid and fields then
                        local aura = ctx.auraIndex and ctx.auraIndex[specID] and ctx.auraIndex[specID][sid]
                        if aura then
                            -- 自訂光環格：id 是 "c:<i>"，不必對表
                            local sp = EnsureSpec(ctx.out, specID)
                            sp.overrides[aura] = sp.overrides[aura] or {}
                            for k, v in pairs(fields) do sp.overrides[aura][k] = v end
                            ctx.R.counts.overrides = ctx.R.counts.overrides + 1
                        else
                            local p = PendingFor(ctx, specID)
                            p.overrides = p.overrides or {}
                            p.overrides[#p.overrides + 1] = { spellID = sid, kind = "buff", fields = fields }
                        end
                    end
                end
            end
        end
    end
    local reg = Take(ctx, "spellRegistry")
    for _, spec in ipairs(SortedKeys(reg)) do
        local specID, node = tonumber(spec), reg[spec]
        if specID and type(node) == "table" then
            local colors = type(node.glowColors) == "table" and node.glowColors or {}
            for _, sk in ipairs(SortedKeys(node.glowEnabled)) do
                local sid = tonumber(sk)
                if sid and node.glowEnabled[sk] == true then
                    if ctx.auraIndex and ctx.auraIndex[specID] and ctx.auraIndex[specID][sid] then
                        Skip(ctx, "spellRegistry.*.glowEnabled (aura slots)", "noEquivalent", "overrides")
                    else
                        local fields = { activeGlow = true }
                        local c = colors[sk]
                        if type(c) == "table" and Num(c.r) and Num(c.g) and Num(c.b) then
                            fields.activeGlowColor = { r = c.r, g = c.g, b = c.b, a = Num(c.a) or 1 }
                        end
                        local p = PendingFor(ctx, specID)
                        p.overrides = p.overrides or {}
                        p.overrides[#p.overrides + 1] = { spellID = sid, kind = "buff", fields = fields }
                    end
                end
            end
            for _, field in ipairs(SortedKeys(node)) do
                if field ~= "glowEnabled" and field ~= "glowColors" and type(node[field]) == "table" and next(node[field]) ~= nil then
                    Skip(ctx, "spellRegistry.*." .. tostring(field), "noEquivalent", "overrides")
                end
            end
        end
    end
end

------------------------------------------------------------
-- 沒有對應的頂層鍵：分類（摘要照類別講「哪些沒匯入」）
------------------------------------------------------------
local SKIP_PATTERNS = {
    { "^rotationAssist", "noEquivalent", "assist" },
    { "^assist",         "noEquivalent", "assist" },
    { "^pressOverlay",   "noEquivalent", "pressOverlay" },
    { "^racials",        "noEquivalent", "racials" },
    { "^fadingRacials$", "noEquivalent", "racials" },
    { "^defensives",     "noEquivalent", "defensives" },
    { "^fadingDefensives$", "noEquivalent", "defensives" },
    { "^trinkets",       "noEquivalent", "trinkets" },
    { "^fadingTrinkets$", "noEquivalent", "trinkets" },
    { "^externals",      "noEquivalent", "externals" },
    { "^castBarOverrides", "noEquivalent", "castbarOverrides" },
    -- 對方舊版的殘留：現行版本已改用別的鍵，這幾個不再有作用
    { "^castBarAnchorToResources$", "obsolete", "legacy" },
    { "^castBarResourcesSpacing$",  "obsolete", "legacy" },
    { "^castBarContainerLocked$",   "obsolete", "legacy" },
    { "^resources",       "obsolete", "legacy" },
    { "Secondary",        "obsolete", "legacy" },
    { "Tertiary",         "obsolete", "legacy" },
    { "Sec$",             "obsolete", "legacy" },
    { "Tert$",            "obsolete", "legacy" },
}
-- 讀得懂、但本插件沒有這一格（外觀細節）
local NO_EQUIVALENT = {
    essRow2CooldownFontSize = true, essRow2ChargeFontSize = true, essRow2ChargeColor = true,
    essRow2ChargePosition = true, essRow2ChargeOffsetX = true, essRow2ChargeOffsetY = true,
    buffBarNameMaxChars = true, buffBarFillDirection = true, buffBarNameColor = true,
    buffBarNameOffsetX = true, buffBarNameOffsetY = true, buffBarDurationColor = true,
    buffBarDurationPosition = true, buffBarDurationOffsetX = true, buffBarDurationOffsetY = true,
    buffBarApplicationsColor = true, buffBarApplicationsPosition = true,
    buffBarApplicationsOffsetX = true, buffBarApplicationsOffsetY = true,
    unifiedBorder = true, moveBuffsDown = true, moveBuffsDownOffset = true, moveBuffsDownFallback = true,
    resourceGroupSettings = true, borderOffsetX = true, borderOffsetY = true,
    hideIconOverlay = true, hideIconOverlayTexture = true, hideBuffSwipe = true, hideDebuffBorder = true,
    hideCooldownBling = true, chargeShowEdge = true, chargeHideSwipe = true, chargeHideRechargeTimer = true,
    glowPixelLength = true, glowPixelXOffset = true, glowPixelYOffset = true, glowPixelBorder = true,
    glowAutocastScale = true, glowAutocastXOffset = true, glowAutocastYOffset = true,
    glowProcDuration = true, glowProcXOffset = true, glowProcYOffset = true,
    castBarNameOffsetX = true, castBarNameOffsetY = true, castBarTimerOffsetX = true, castBarTimerOffsetY = true,
    castBarBackgroundTexture = true, castBarEmpowerWindUpColor = true,
    castBarPreviewEnabled = true, castBarFillDirection = true,
}

local function Classify(key)
    if NO_EQUIVALENT[key] then return "noEquivalent", "other" end
    for _, p in ipairs(SKIP_PATTERNS) do
        if tostring(key):find(p[1]) then return p[2], p[3] end
    end
    return "unknown", "other"
end
Import.Classify = Classify

------------------------------------------------------------
-- Convert
------------------------------------------------------------
local STEPS = { StepPositions, StepSizes, StepText, StepIcons, StepGlow, StepFade,
                StepResources, StepCastbar, StepGroups, StepAuras, StepOverrides }

function Import.Convert(src, opts)
    opts = type(opts) == "table" and opts or {}
    local out = DeepCopy(type(opts.defaults) == "table" and opts.defaults or {})
    local R = NewReport()
    if type(src) ~= "table" then return out, R end
    for _, k in ipairs({ "theme", "bars", "resources", "castbar" }) do
        if type(out[k]) ~= "table" then out[k] = {} end
    end
    local theme = out.theme
    for _, k in ipairs({ "cooldownText", "chargeText", "stackText", "icon", "border", "fade", "pandemic" }) do
        if type(theme[k]) ~= "table" then theme[k] = {} end
    end
    if type(theme.glow) ~= "table" then theme.glow = {} end
    if type(theme.glow.proc) ~= "table" then theme.glow.proc = {} end

    local ctx = { src = src, out = out, R = R, opts = opts, used = {}, skipSeen = {} }
    for _, step in ipairs(STEPS) do step(ctx) end

    for _, key in ipairs(SortedKeys(src)) do
        if ctx.used[key] then
            R.imported[#R.imported + 1] = key
        else
            local why, cat = Classify(key)
            Skip(ctx, key, why, cat)
        end
    end
    table.sort(R.skipped, function(a, b) return tostring(a.key) < tostring(b.key) end)

    -- 目前專精當場對表；其他專精留在 pendingImport
    if opts.specID and type(opts.resolve) == "function" then
        Import.ApplyPending(out, opts.specID, opts.resolve)
    end
    for specID, p in pairs(type(out.pendingImport) == "table" and out.pendingImport or {}) do
        local g, s, o = 0, 0, 0
        for _, grp in ipairs(p.groups or {}) do g = g + 1; s = s + #(grp.spells or {}) end
        o = #(p.overrides or {})
        R.pending[specID] = { groups = g, spells = s, overrides = o }
        R.counts.overridesPending = R.counts.overridesPending + o
    end
    -- 還有沒換到的法術的群組數（同一個群組可能一半換到了）
    local pendingBars = {}
    for _, p in pairs(type(out.pendingImport) == "table" and out.pendingImport or {}) do
        for _, grp in ipairs(p.groups or {}) do pendingBars[grp.bar] = true end
    end
    for _ in pairs(pendingBars) do R.counts.groupsPending = R.counts.groupsPending + 1 end
    return out, R
end

------------------------------------------------------------
-- pending 對表（純函式；Convert 對目前專精、ResolvePending 在登入後對其他專精都走這支）
--
-- resolve(spellID, kind) → cooldownID | nil。回傳：這次換好幾筆、還剩幾筆。
------------------------------------------------------------
local function SafeResolve(resolve, sid, kind)
    local ok, cd = pcall(resolve, sid, kind)
    if not ok or type(cd) ~= "number" then return nil end
    if ns.IsSecret and ns.IsSecret(cd) then return nil end
    return cd
end

function Import.ApplyPending(profile, specID, resolve)
    local all = type(profile) == "table" and profile.pendingImport
    local pend = type(all) == "table" and specID ~= nil and all[specID]
    if type(pend) ~= "table" or type(resolve) ~= "function" then return 0, 0 end
    local sp = EnsureSpec(profile, specID)
    local bars = type(profile.bars) == "table" and profile.bars or {}
    local done, left = 0, 0

    local keepGroups = {}
    for _, g in ipairs(type(pend.groups) == "table" and pend.groups or {}) do
        -- 群組被刪掉了：那一筆作廢（法術留在原本的檢視器）
        if type(g) == "table" and type(bars[g.bar]) == "table" and type(g.spells) == "table" then
            local ord = type(sp.order[g.bar]) == "table" and sp.order[g.bar] or {}
            local rest = {}
            for _, sid in ipairs(g.spells) do
                local cd = SafeResolve(resolve, sid, g.kind)
                if cd then
                    if sp.groupOf[cd] == nil then
                        sp.groupOf[cd] = g.bar
                        ord[#ord + 1] = cd
                    end
                    done = done + 1
                else
                    rest[#rest + 1] = sid
                end
            end
            if #ord > 0 then sp.order[g.bar] = ord end
            if #rest > 0 then
                keepGroups[#keepGroups + 1] = { bar = g.bar, kind = g.kind, spells = rest }
                left = left + #rest
            end
        end
    end

    local keepOv = {}
    for _, o in ipairs(type(pend.overrides) == "table" and pend.overrides or {}) do
        if type(o) == "table" and type(o.fields) == "table" then
            local cd = SafeResolve(resolve, o.spellID, o.kind)
            if cd then
                local t = type(sp.overrides[cd]) == "table" and sp.overrides[cd] or {}
                for k, v in pairs(o.fields) do if t[k] == nil then t[k] = v end end
                sp.overrides[cd] = t
                done = done + 1
            else
                keepOv[#keepOv + 1] = o
                left = left + 1
            end
        end
    end

    pend.groups = #keepGroups > 0 and keepGroups or nil
    pend.overrides = #keepOv > 0 and keepOv or nil
    if next(pend) == nil then all[specID] = nil end
    if next(all) == nil then profile.pendingImport = nil end
    return done, left
end

------------------------------------------------------------
-- spellID → cooldownID 對照（純函式）
--
-- records = { { cooldownID, kind = "cooldown"|"buff", placed = bool, spells = { spellID, … } }, … }
-- 同一個 spellID 有好幾個 cooldownID 時（技能本身與它給的增益）照優先序挑：
--   種類相同且在檢視器上 > 種類相同 > 種類不同且在檢視器上 > 其他；同分取先出現的。
------------------------------------------------------------
function Import.BuildResolver(records)
    local best = {}
    for _, r in ipairs(type(records) == "table" and records or {}) do
        local cd = type(r) == "table" and r.cooldownID
        if type(cd) == "number" then
            for _, sid in ipairs(type(r.spells) == "table" and r.spells or {}) do
                if type(sid) == "number" then
                    local slot = best[sid]
                    if not slot then slot = {}; best[sid] = slot end
                    local k = r.kind == "buff" and "buff" or "cooldown"
                    local cur = slot[k]
                    if not cur or (r.placed and not cur.placed) then
                        slot[k] = { cd = cd, placed = r.placed and true or false }
                    end
                end
            end
        end
    end
    return function(spellID, kind)
        local slot = best[spellID]
        if not slot then return nil end
        local want = kind == "buff" and "buff" or "cooldown"
        local other = want == "buff" and "cooldown" or "buff"
        local a, b = slot[want], slot[other]
        if a and (a.placed or not (b and b.placed)) then return a.cd end
        if b then return b.cd end
        return a and a.cd or nil
    end
end

------------------------------------------------------------
-- 取名（純函式）
--
-- names     對方的設定檔名（陣列，照這個順序配名字）
-- existing  本插件現有的設定檔（名字 → 任何值）
-- previous  上次匯入的對照（原名 → 當時建的名字）：重新匯入就覆蓋那一份，不再多建一份
-- fmt       原名 → 新名的基底（「Ayije：原名」）
------------------------------------------------------------
function Import.PlanNames(names, existing, previous, fmt, reserved)
    local taken = {}
    for k in pairs(type(existing) == "table" and existing or {}) do taken[k] = true end
    local out, claimed = {}, {}
    for _, n in ipairs(names) do
        local prev = type(previous) == "table" and previous[n] or nil
        if type(prev) == "string" and prev ~= "" and prev ~= reserved and not claimed[prev] then
            out[n], claimed[prev] = prev, true
            taken[prev] = true
        end
    end
    for _, n in ipairs(names) do
        if not out[n] then
            local base = fmt and fmt(n) or n
            local name, i = base, 2
            while taken[name] or name == reserved do
                name = ("%s (%d)"):format(base, i)
                i = i + 1
            end
            taken[name], out[n] = true, name
        end
    end
    return out
end

------------------------------------------------------------
-- 以下是遊戲裡才跑的部分
------------------------------------------------------------
local function Plain(v)
    if v == nil then return nil end
    if ns.IsSecret and ns.IsSecret(v) then return nil end
    local can = _G.canaccessvalue
    if can and not can(v) then return nil end
    return v
end

-- 對方的存檔在不在、有沒有這隻角色的設定
function Import.Available()
    local src = _G[SOURCE_SV]
    if type(src) ~= "table" or type(src.profiles) ~= "table" then return false end
    local key = ns.DB and ns.DB.CharKey and ns.DB.CharKey()
    local keys = src.profileKeys
    local name = type(keys) == "table" and key and keys[key]
    return type(name) == "string" and type(src.profiles[name]) == "table"
end

function Import.Imported()
    local sv = _G.MiliUI_CooldownManager_DB
    local rec = type(sv) == "table" and sv.importedFromAyije
    return type(rec) == "table" and rec or nil
end

-- 匯入當下的對照來源：直接問暴雪（這時候本插件的目錄還沒建）
local function LiveRecords()
    local CV = C_CooldownViewer
    local cats = Enum and Enum.CooldownViewerCategory
    if not (CV and CV.GetCooldownViewerCategorySet and CV.GetCooldownViewerCooldownInfo and type(cats) == "table") then
        return {}
    end
    local MAIN = { Essential = true, Utility = true, TrackedBuff = true, TrackedBar = true }
    local list = {}
    for name, value in pairs(cats) do
        if type(value) == "number" and type(name) == "string" then list[#list + 1] = { name = name, value = value } end
    end
    table.sort(list, function(a, b) return a.value < b.value end)
    local records, seen = {}, {}
    for _, c in ipairs(list) do
        local ok, ids = pcall(CV.GetCooldownViewerCategorySet, c.value, true)
        if ok and type(ids) == "table" then
            for i = 1, #ids do
                local id = Plain(ids[i])
                if type(id) == "number" and not seen[id] then
                    seen[id] = true
                    local ok2, info = pcall(CV.GetCooldownViewerCooldownInfo, id)
                    if ok2 and type(info) == "table" then
                        local spells = {}
                        for _, f in ipairs({ "spellID", "overrideSpellID", "overrideTooltipSpellID" }) do
                            local s = Plain(info[f])
                            if type(s) == "number" then spells[#spells + 1] = s end
                        end
                        local linked = Plain(info.linkedSpellIDs)
                        if type(linked) == "table" then
                            for _, s in ipairs(linked) do
                                s = Plain(s)
                                if type(s) == "number" then spells[#spells + 1] = s end
                            end
                        end
                        records[#records + 1] = {
                            cooldownID = id, spells = spells, placed = MAIN[c.name] or false,
                            kind = (c.name:find("Tracked") or c.name:find("Buff")) and "buff" or "cooldown",
                        }
                    end
                end
            end
        end
    end
    return records
end

-- 登入後的對照來源：本插件的目錄（Core/Catalog.lua 剛建好的 C.info）
local function CatalogRecords()
    local C = ns.Catalog
    if not (C and type(C.info) == "table") then return {} end
    local records = {}
    for _, id in ipairs(type(C.ordered) == "table" and C.ordered or {}) do
        local rec = C.info[id]
        if type(rec) == "table" and type(id) == "number" then
            records[#records + 1] = {
                cooldownID = id,
                spells = { rec.spellID, rec.overrideSpellID, rec.overrideTooltipSpellID },
                placed = rec.bar ~= nil,
                kind = (rec.home == "buffs" or rec.home == "buffbars") and "buff" or "cooldown",
            }
        end
    end
    return records
end

-- 目錄建好之後（Core/Catalog.lua）叫；有換到東西回 true（呼叫端據此重排）
function Import.ResolvePending(specID)
    local p = ns.profile
    if type(p) ~= "table" or type(p.pendingImport) ~= "table" or specID == nil then return false end
    if type(p.pendingImport[specID]) ~= "table" then return false end
    local done = Import.ApplyPending(p, specID, Import.BuildResolver(CatalogRecords()))
    return (done or 0) > 0
end

local function SpecName(specID)
    local fn = _G.GetSpecializationInfoByID
    if not fn then return nil end
    local ok, _, name = pcall(fn, specID)
    name = ok and Plain(name) or nil
    return type(name) == "string" and name or nil
end

------------------------------------------------------------
-- 摘要（寫進 SV，重載後登入時印；重載前印的看不到）
------------------------------------------------------------
local CATEGORY_LABEL = {
    assist           = L["Rotation assist"],
    pressOverlay     = L["Press overlay"],
    racials          = L["Racials"],
    defensives       = L["Defensives"],
    trinkets         = L["Trinkets"],
    externals        = L["External defensives"],
    castbarOverrides = L["Per-spell cast bar overrides"],
    customBuffs      = L["Timed custom buffs"],
}
local CATEGORY_ORDER = { "trinkets", "defensives", "racials", "externals", "assist", "pressOverlay",
                         "castbarOverrides", "customBuffs" }

local function Summarize(reports, profileCount)
    local s = { profiles = profileCount, groups = 0, groupsPending = 0, auras = 0, overrides = 0,
                overridesPending = 0, cats = {}, other = 0 }
    local cats, other = {}, {}
    for _, R in ipairs(reports) do
        local c = R.counts
        s.groups = s.groups + c.groups
        s.groupsPending = s.groupsPending + c.groupsPending
        s.auras = s.auras + c.auras
        s.overrides = s.overrides + c.overrides
        s.overridesPending = s.overridesPending + c.overridesPending
        for _, sk in ipairs(R.skipped) do
            if sk.why == "noEquivalent" and CATEGORY_LABEL[sk.cat] then
                cats[sk.cat] = true
            elseif sk.why ~= "obsolete" then
                other[sk.key] = true
            end
        end
    end
    for _, k in ipairs(CATEGORY_ORDER) do
        if cats[k] then s.cats[#s.cats + 1] = k end
    end
    for _ in pairs(other) do s.other = s.other + 1 end
    return s
end

function Import.SummaryLines(s, main)
    if type(s) ~= "table" then return {} end
    local lines = {}
    lines[#lines + 1] = L["Imported %d profile(s) from %s; this character now uses \"%s\"."]
        :format(s.profiles or 0, Import.SOURCE_ADDON, tostring(main))
    lines[#lines + 1] = L["Custom groups: %d (%d finish setting up the first time you play that specialization). Custom auras: %d. Per-spell settings: %d."]
        :format(s.groups or 0, s.groupsPending or 0, s.auras or 0, s.overrides or 0)
    local names = {}
    for _, k in ipairs(s.cats or {}) do names[#names + 1] = CATEGORY_LABEL[k] end
    if (s.other or 0) > 0 then names[#names + 1] = L["%d appearance details"]:format(s.other) end
    if #names > 0 then
        lines[#lines + 1] = L["Not imported (no equivalent here): %s."]:format(table.concat(names, L[", "]))
    end
    local hasTrackers = false
    for _, k in ipairs(s.cats or {}) do
        if k == "trinkets" or k == "defensives" or k == "racials" then hasTrackers = true end
    end
    if hasTrackers then
        lines[#lines + 1] = L["Trinkets, defensives and racials can be tracked with a custom group and a custom ID."]
    end
    lines[#lines + 1] = L["Settings that were never changed in %s use this addon's defaults."]:format(Import.SOURCE_ADDON)
    return lines
end

------------------------------------------------------------
-- 互斥彈窗的「匯入」鈕
------------------------------------------------------------
function Import.FromAyije()
    local src = _G[SOURCE_SV]
    if not Import.Available() then
        ns.Print(L["There's nothing to import for this character."])
        return false
    end
    if ns.RefreshSpec then ns.RefreshSpec() end
    local DB = ns.DB
    local charKey = DB.CharKey()

    local okR, records = pcall(LiveRecords)
    local resolve = Import.BuildResolver(okR and records or {})

    local sv = _G.MiliUI_CooldownManager_DB
    if type(sv) ~= "table" then
        sv = {}
        _G.MiliUI_CooldownManager_DB = sv
    end
    for _, k in ipairs({ "profiles", "profileKeys", "specProfiles", "charClasses" }) do
        if type(sv[k]) ~= "table" then sv[k] = {} end
    end
    DB.MergeDefaults(sv, DB.BuildDefaults().account)

    local prevRec = type(sv.importedFromAyije) == "table" and sv.importedFromAyije or nil
    local names = {}
    for _, n in ipairs(SortedKeys(src.profiles)) do
        if type(n) == "string" and type(src.profiles[n]) == "table" then names[#names + 1] = n end
    end
    local plan = Import.PlanNames(names, sv.profiles, prevRec and prevRec.profiles,
        function(n) return L["Ayije: %s"]:format(n) end, DB.DEFAULT_PROFILE)

    local mapping, reports, count = {}, {}, 0
    for _, n in ipairs(names) do
        local ok, profile, report = pcall(Import.Convert, src.profiles[n], {
            specID = ns.specID, resolve = resolve, defaults = DB.BuildDefaults().profile,
            class = ns.playerClass, specName = SpecName, newBar = DB.NewBarTable,
        })
        if ok and type(profile) == "table" then
            sv.profiles[plan[n]] = profile
            mapping[n] = plan[n]
            reports[#reports + 1] = report
            count = count + 1
        elseif ns.ReportError then
            ns.ReportError(profile)
        end
    end
    if count == 0 then
        ns.Print(L["Import failed; nothing was changed."])
        return false
    end

    local keys = type(src.profileKeys) == "table" and src.profileKeys or {}
    local global = type(src.global) == "table" and src.global or {}
    local main = mapping[keys[charKey]] or mapping[global.defaultProfile] or mapping.Default or mapping[names[1]]
    sv.profileKeys[charKey] = main
    sv.charClasses[charKey] = ns.playerClass
    local specMap = type(src.specProfiles) == "table" and src.specProfiles[charKey]
    if type(specMap) == "table" then
        local m = { enabled = specMap.enabled == true }
        for i = 1, 5 do
            local n = specMap[i]
            if type(n) == "string" and mapping[n] then m[i] = mapping[n] end
        end
        sv.specProfiles[charKey] = m
    end

    local summary = Summarize(reports, count)
    sv.importedFromAyije = {
        at = time and time() or 0, char = charKey, profiles = mapping, main = main,
        summary = summary, announce = true,
    }
    for _, line in ipairs(Import.SummaryLines(summary, main)) do ns.Print(line) end
    if ns.DisableAndReload then ns.DisableAndReload(Import.SOURCE_FOLDERS) end
    return true
end

-- 重載後登入：把摘要印出來（只印一次）
if ns.RegisterCallback then
    ns.RegisterCallback("Loaded", "import", function()
        local rec = Import.Imported()
        if not (rec and rec.announce) then return end
        rec.announce = nil
        for _, line in ipairs(Import.SummaryLines(rec.summary, rec.main)) do ns.Print(line) end
    end)
end

------------------------------------------------------------
-- /mcdm debug：還沒對到表的法術
------------------------------------------------------------
function Import.DebugLines()
    local p = ns.profile
    local all = type(p) == "table" and p.pendingImport
    if type(all) ~= "table" or next(all) == nil then return {} end
    local lines = {}
    for _, specID in ipairs(SortedKeys(all)) do
        local e = all[specID]
        local ids = {}
        for _, g in ipairs(type(e) == "table" and e.groups or {}) do
            for _, sid in ipairs(g.spells or {}) do ids[#ids + 1] = tostring(g.bar) .. ":" .. tostring(sid) end
        end
        for _, o in ipairs(type(e) == "table" and e.overrides or {}) do ids[#ids + 1] = "ov:" .. tostring(o.spellID) end
        lines[#lines + 1] = ("  匯入待對應 spec %s：%s"):format(tostring(specID), table.concat(ids, " "))
    end
    return lines
end
