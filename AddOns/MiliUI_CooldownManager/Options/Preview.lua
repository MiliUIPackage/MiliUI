------------------------------------------------------------
-- 設定頁的預覽（也是編輯器）
--
--   local pv = ns.Preview.Create(parent, key, width)   條頁建一次
--   pv:Refresh()                                       照目前設定重畫
--   ns.Preview.Refresh(key)                            設定改了（任何地方）叫這支
--
-- 畫的是**我們自己的假框**，不碰真實條：
--   * 真實尺寸：版面照 ns.Layout.Compute 算（每列上限、間距、兩列尺寸、成長方向），
--     比可用寬大就水平捲動，太高就垂直捲動（滾輪；有橫向溢出時 Shift＋滾輪橫捲）。
--   * 外觀走 ns.Decorate.ApplyPreview：跟真實條同一套邊框／縮放／轉圈色／文字樣式。
--   * 假資料：奇數格「冷卻中」（轉圈＋倒數「15」＋去飽和），偶數格就緒。核心／輔助技能與自訂圖示群組不畫假冷卻，
--     改由底下的效果預覽列按了才在第一個技能格演示五秒（冷卻中／增益持續時間／觸發發光／就緒發光）。技能印充能「2」、
--     增益印層數「2」；長條跑一個十五秒的循環（名字＝法術名、時間 15→0）。
--
-- 互動
--   左鍵點格         → 逐法術面板（Options/SpellPopover.lua）
--   中鍵點格         → 移除（從這條拿掉、不再顯示）。移除的不留在預覽上，要加回來按「＋」
--                      （暴雪清單上的法術記在 spells[spec].hidden、挑選器第一區列得到；自己加的項目整筆刪掉）
--   拖曳（門檻 3px） → 排序（spells[spec].order[key] 寫完整清單）；拖到左欄的自訂群組上
--                      ＝拉進那一群（groupOf），拖回原本的檢視器上＝清掉 groupOf
--   最右邊「＋」     → 挑選器（Options/Picker.lua）
-- 光環格（自訂項目 kind = "aura"）跟其他格一樣：可以拖到條上任意位置（同一張 order 表）、拖到左欄群組，
-- 中鍵＝整筆移除，左鍵照樣開逐法術面板。
-- 自訂項目（"c:<index>"／"k:<uid>"／"w:<uid>"）拖到左欄＝改它的 bar（任何一條都收，含四條檢視器與長條類的條）；
-- 職業層／戰隊層的那一筆只有一份，改 bar 等於每個看得到它的專精都跟著搬。
-- 範圍記號：職業層／戰隊層的自訂項目右上角一個 10×10 的小記號（Media/scope-class.png 盾牌、scope-shared.png
-- 兩個人像，Pillow 腳本產生），黑底、職業層染職業色、戰隊層白；滑過提示寫範圍。專精層不畫。
-- 長條格的自訂項目：名字＝法術／物品名、跑同一個十五秒假條；沒學會的自訂法術圖示灰掉。
-- 以增益取代（overrides[id].replaceWith）：那一格右下角畫一個 12×12、1px 黑邊的增益圖示當記號；
-- 被拿去取代的增益不在任何一條的清單上（Catalog.Bar 拿掉了），預覽自然不列（跟真實條一致）。
-- 格數上限＋溢出（Core/Overflow.lua；預覽用 Catalog.OverflowStatic：每一格都算顆數）：
--   來源條：溢出去的那幾格畫暗（0.35）＋右下角「→」＋提示「溢出到：X」；照樣能拖（順序決定哪幾顆溢出）、中鍵移除
--   接收條：溢來的格畫在尾端（「＋」前面）＋同樣的記號＋提示「來自：A」；外觀照這條。**不能拖**（順序屬於來源條，
--          拖了跳彈窗，附「前往那條」）；中鍵移除對來源條生效（移除本來就不分條：hidden／整筆刪掉）
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W, P = ns.W, ns.P

ns.Preview = {}
local Preview = ns.Preview

local WHITE     = "Interface\\BUTTONS\\WHITE8X8"
local QUESTION  = 134400
local PAD       = 10
local MAX_H     = 170
local MIN_H     = 56
local DRAG_MIN  = 3
local CYCLE     = 15
local AURA_SRC  = { buffs = true, buffbars = true }
-- 不畫假冷卻、改用效果預覽列的條：核心／輔助技能與自訂圖示群組（使用者 2026-10-03）。
-- 增益類（增益圖示、增益長條）本來就沒有假冷卻；長條類另有十五秒假條
local function NoFakeCD(key)
    if key == "essential" or key == "utility" then return true end
    local b = ns.DB.BarTable(key)          -- BarCfg 定義在下面，這裡直接問
    return type(b) == "table" and b.source == "custom" and b.kind ~= "bars" or false
end

-- 效果預覽列（NoFakeCD 的條才有，平常不畫假冷卻）：按一下，**第一個技能格**演示那個效果 FX_SECS 秒
--   （倒數類會拉長到門檻＋3 秒，見 StartFx）
--   （光環格、被移除的格不算；整排一起演示太吵，看一格就知道長相）
--   cooldown  冷卻中：轉圈＋倒數＋去飽和／冷卻狀態效果（倒數照設定的小數門檻與低秒變色）
--   aura      增益持續時間：同上，倒數用增益那一段的換色
--   proc／ready  觸發／就緒發光：照這條的發光設定畫在每一格上
local FX_H, FX_SECS = 30, 5
local FX_BUTTONS = {
    { kind = "cooldown", label = L["On cooldown"] },
    { kind = "aura",     label = L["Buff duration"] },
    { kind = "proc",     label = L["Proc glow"] },
    { kind = "ready",    label = L["Ready glow"] },
}

local instances = {}

------------------------------------------------------------
-- 小工具
------------------------------------------------------------
local function Cursor(frame)
    local s = frame:GetEffectiveScale()
    if not s or s <= 0 then s = 1 end
    local x, y = GetCursorPosition()
    return x / s, y / s
end

local function BarCfg(key) return ns.DB.BarTable(key) end

-- 長條寬 0 ＝ 跟核心技能第一列同寬（跟 Bars 的算法同一條）
local function Sizing(key, bar)
    local layout = type(bar.layout) == "table" and bar.layout or {}
    if bar.kind ~= "bars" then return layout end
    local cfg = type(bar.bar) == "table" and bar.bar or {}
    local w = tonumber(cfg.width) or 0
    if w <= 0 then
        local ess = BarCfg("essential")
        w = ess and ns.Layout.FirstRowWidth(#ns.Catalog.Bar("essential"), ess.layout) or 0
        if w <= 0 then w = (type(layout.size) == "table" and tonumber(layout.size.w)) or 200 end
    end
    local h = tonumber(cfg.height) or 20
    return { maxPerRow = 1, spacing = layout.spacing, grow = layout.grow, size = { w = w, h = h } }
end

local function SetupFont(fs, size)
    ns.Media.SetFont(fs, size or 12, "OUTLINE")
    fs:SetText("")
end

------------------------------------------------------------
-- 範圍記號（職業層／戰隊層的自訂項目）：右上角 10×10，黑底＋圖案（Pillow 腳本畫的白色圖案，染色用 SetVertexColor）
------------------------------------------------------------
local SCOPE_MARK_TEX = {
    shared = "Interface\\AddOns\\MiliUI_CooldownManager\\Media\\scope-shared.png",
    class  = "Interface\\AddOns\\MiliUI_CooldownManager\\Media\\scope-class.png",
}
local SCOPE_MARK = 10

local function NewScopeMark(ov, anchor)
    local m = CreateFrame("Frame", nil, ov)
    m:SetSize(SCOPE_MARK, SCOPE_MARK)
    m:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
    m:SetFrameLevel(ov:GetFrameLevel() + 2)
    local bg = m:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 1)
    m.icon = m:CreateTexture(nil, "ARTWORK")
    m.icon:SetPoint("TOPLEFT", 1, -1)
    m.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    m:Hide()
    return m
end

-- scope ＝ "shared"｜"class" 才畫；其餘收起來（格子是池化的，一定要明確收）
local function PaintScopeMark(m, scope)
    if not m then return end
    local tex = SCOPE_MARK_TEX[scope]
    if not tex then m:Hide() return end
    m.icon:SetTexture(tex)
    if scope == "class" then
        m.icon:SetVertexColor(W.Accent(1))
    else
        m.icon:SetVertexColor(1, 1, 1, 1)
    end
    m:Show()
end

------------------------------------------------------------
-- 格子
------------------------------------------------------------
local function NewIconCell(canvas)
    local c = CreateFrame("Frame", nil, canvas)
    c:EnableMouse(true)
    c.Icon = c:CreateTexture(nil, "ARTWORK")
    c.Icon:SetAllPoints()
    local ok, cd = pcall(CreateFrame, "Cooldown", nil, c, "CooldownFrameTemplate")
    if ok and cd then
        cd:SetAllPoints()
        if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        if cd.SetDrawEdge then cd:SetDrawEdge(false) end
        if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, WHITE, 1, 1, 1, 1) end
        -- 循環：轉完一圈重來（自己的框，隨便掛）
        cd:SetScript("OnCooldownDone", function(self)
            if c.onCD and c:IsVisible() then self:SetCooldown(GetTime(), CYCLE) end
        end)
        c.Cooldown = cd
    end
    local ov = CreateFrame("Frame", nil, c)
    ov:SetAllPoints()
    ov:SetFrameLevel(c:GetFrameLevel() + 5)
    c.overlay = ov
    c.cdText = ov:CreateFontString(nil, "OVERLAY")
    SetupFont(c.cdText, 16)
    c.chargeText = ov:CreateFontString(nil, "OVERLAY")
    SetupFont(c.chargeText, 12)
    c.stackText = ov:CreateFontString(nil, "OVERLAY")
    SetupFont(c.stackText, 12)
    -- 以增益取代的記號：右下角一個小圖示（外框 1px 黑），層級在倒數／充能字的上面
    local mark = CreateFrame("Frame", nil, ov)
    mark:SetSize(14, 14)
    mark:SetPoint("BOTTOMRIGHT", ov, "BOTTOMRIGHT", 0, 0)
    mark:SetFrameLevel(ov:GetFrameLevel() + 2)
    local mbg = mark:CreateTexture(nil, "BACKGROUND")
    mbg:SetAllPoints()
    mbg:SetColorTexture(0, 0, 0, 1)
    mark.icon = mark:CreateTexture(nil, "ARTWORK")
    mark.icon:SetPoint("TOPLEFT", 1, -1)
    mark.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    mark.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    mark:Hide()
    c.replaceMark = mark
    -- 溢出記號（來源條溢出去的格、接收條溢來的格）：右下角一個「→」；有取代記號時排在它左邊
    local om = ov:CreateFontString(nil, "OVERLAY")
    ns.Media.SetFont(om, 12, "OUTLINE")
    om:SetText("→")
    om:SetTextColor(1, 0.82, 0, 1)
    om:Hide()
    c.ovMark = om
    c.scopeMark = NewScopeMark(ov, ov)
    c.kind = "icons"
    c.isPlus, c.hiddenItem, c.dragging = false, false, false
    return c
end

local function NewBarCell(canvas)
    local c = CreateFrame("Frame", nil, canvas)
    c:EnableMouse(true)
    local icon = CreateFrame("Frame", nil, c)
    icon.Icon = icon:CreateTexture(nil, "ARTWORK")
    icon.Icon:SetAllPoints()
    icon.Applications = icon:CreateFontString(nil, "OVERLAY")
    SetupFont(icon.Applications, 12)
    c.Icon = icon
    local bar = CreateFrame("StatusBar", nil, c)
    bar:SetMinMaxValues(0, 1)
    bar:SetStatusBarTexture(WHITE)
    bar.BarBG = bar:CreateTexture(nil, "BACKGROUND")
    bar.Name = bar:CreateFontString(nil, "OVERLAY")
    SetupFont(bar.Name, 12)
    bar.Duration = bar:CreateFontString(nil, "OVERLAY")
    SetupFont(bar.Duration, 12)
    -- 火花（bar.spark）：填充末端一條 2px 亮線；錨點與顯示由 Decorate 的 ApplyBarLook 管（ownPip）
    bar.Pip = bar:CreateTexture(nil, "OVERLAY")
    bar.Pip:SetTexture(WHITE)
    bar.Pip:SetVertexColor(1, 1, 1, 0.9)
    bar.Pip:SetWidth(2)
    bar.Pip:SetAlpha(0)
    bar.ownPip = true
    c.Bar = bar
    local ov = CreateFrame("Frame", nil, c)
    ov:SetAllPoints()
    ov:SetFrameLevel(c:GetFrameLevel() + 5)
    c.overlay = ov
    c.scopeMark = NewScopeMark(ov, icon)       -- 長條：記號在左邊圖示那一格的右上角
    c.kind = "bars"
    c.isPlus, c.hiddenItem, c.dragging = false, false, false
    return c
end

local function NewPlusCell(canvas)
    local c = CreateFrame("Frame", nil, canvas, "BackdropTemplate")
    c:EnableMouse(true)
    W.Stylize(c, { 0.115, 0.115, 0.115, 1 }, { W.Accent(0.6) })
    local fs = c:CreateFontString(nil, "OVERLAY")
    fs:SetFontObject(W.fontTitle)
    fs:SetPoint("CENTER")
    fs:SetText("+")
    c.label = fs
    c.isPlus, c.hiddenItem, c.dragging = true, false, false
    c:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.23, 0.23, 0.23, 1)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(L["Add spells to this bar"])
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.115, 0.115, 0.115, 1)
        GameTooltip:Hide()
    end)
    return c
end

------------------------------------------------------------
-- 寫入（本專精的 spells 表）
------------------------------------------------------------
local function Changed(level, ...)
    for i = 1, select("#", ...) do
        local k = select(i, ...)
        if k then Preview.Refresh(k) end
    end
    ns.Options.ApplyEngine(level or "membership")
    -- 群組的內容變了：左欄「這個專精沒有內容」的標記跟著對一次
    if ns.Sidebar and ns.Sidebar.RefreshEmpty then ns.Sidebar.RefreshEmpty() end
end

function Preview.SetHidden(key, id, hidden)
    local sp = ns.DB.SpecSpells(true)
    if not sp or id == nil then return end
    sp.hidden[id] = hidden and true or nil
    Changed("membership", key)
end

-- 移除：從這條拿掉、不再顯示。對使用者只有這一個動作（設定面板上有什麼，畫面上就有什麼）：
--   * 暴雪清單上的法術 → 記進 spells[spec].hidden（暴雪那邊的清單我們不動；逐法術設定留著，加回來照舊）
--   * 自己用「＋」加的項目 → 整筆刪掉
-- 加回來一律走「＋」。
function Preview.Remove(key, id)
    if id == nil then return false end
    if ns.Catalog.IsCustom(id) then return Preview.RemoveCustom(key, id) end
    if ns.SpellPopover and ns.SpellPopover.Close then ns.SpellPopover.Close() end
    Preview.SetHidden(key, id, true)
    return true
end

-- 確認彈窗（共用一顆；文字與確定後要做的事每次換）
local confirmPopup, confirmAction
function Preview.Confirm(text, onAccept)
    if not confirmPopup then
        confirmPopup = W.CreateConfirmPopup(ns.Options.panel, 340, "", function()
            local fn = confirmAction
            confirmAction = nil
            if fn then fn() end
        end)
        ns.RegisterCallback("OptionsHidden", "preview_confirm", function() confirmPopup:Hide() end)
    end
    confirmAction = onAccept
    confirmPopup.text:SetText(text)
    confirmPopup:Show()
end

-- 移除自訂項目（玩家自己用「＋」加的）：整筆刪掉，它的逐法術設定一起走。
-- 職業層／戰隊層的一筆：刪掉＝看得到它的每個專精（戰隊層：每個角色）都沒了 ⇒ 先問（專精層照舊不問）
function Preview.RemoveCustom(key, id)
    if not ns.Catalog.IsCustom(id) then return false end
    if ns.SpellPopover and ns.SpellPopover.Close then ns.SpellPopover.Close() end
    local function Do()
        if not ns.DB.RemoveCustom(id) then return false end
        Preview.Refresh(key)
        if ns.TabBar and ns.TabBar.RefreshForm then ns.TabBar.RefreshForm(key) end
        ns.Options.ApplyEngine("membership")
        if ns.Sidebar and ns.Sidebar.RefreshEmpty then ns.Sidebar.RefreshEmpty() end
        return true
    end
    local scope = ns.DB.ParseCustomID(id)
    if scope == "class" or scope == "shared" then
        Preview.Confirm(scope == "shared"
            and L["Remove it for every character and specialization using this profile?"]
            or L["Remove it from every specialization of this class?"], Do)
        return true
    end
    return Do()
end

-- 把 id 拉進 target（nil 或它原本的檢視器 ＝ 清掉 groupOf）
-- 自訂項目沒有「原本的檢視器」：直接改它的 bar
function Preview.MoveTo(id, target, fromKey)
    if ns.Catalog.IsCustom(id) then
        if not target or not ns.DB.SetCustomBar(id, target) then return end
        Changed("membership", fromKey, target)
        return
    end
    local sp = ns.DB.SpecSpells(true)
    if not sp or id == nil then return end
    local origin = ns.Catalog.SourceOf(id)
    if target == origin then target = nil end
    sp.groupOf[id] = target
    Changed("membership", fromKey, target or origin)
end

-- 拖到哪幾條上是合法的：同類型（長條只收長條）的自訂群組，以及它原本的檢視器
function Preview.DropCandidates(key, id)
    local out = {}
    if ns.Catalog.IsCustom(id) then
        -- 自訂項目：任何一條（圖示類、長條類都收；放在長條上時畫成長條，見 Modules/Custom.lua）
        local p = ns.profile
        for k, bar in pairs(p and p.bars or {}) do
            if k ~= key and type(bar) == "table" then out[k] = true end
        end
        return out
    end
    local origin = ns.Catalog.SourceOf(id)
    local originBar = origin and BarCfg(origin)
    local wantBars = originBar and originBar.kind == "bars"
    local p = ns.profile
    for k, bar in pairs(p and p.bars or {}) do
        if k ~= key and type(bar) == "table" and not ns.DB.IsBuiltinBar(k)
            and (bar.kind == "bars") == (wantBars and true or false) then
            out[k] = true
        end
    end
    if origin and origin ~= key then out[origin] = true end
    return out
end

-- 拖到左欄某一條上卻放不進去的原因（給使用者看；nil ＝ 不用說，例如拖回自己這條、不是條的頁面）
--   * 內建條之間：清單是暴雪冷卻管理器分的。同一家族（核心↔輔助、增益圖示↔增益長條）暴雪面板裡拖得過去，
--     指過去；不同家族暴雪也不收
--   * 自訂群組：圖示類的法術只進圖示群組、長條類只進長條群組（DropCandidates 同一條規則）
local FAMILY = { essential = "cd", utility = "cd", buffs = "aura", buffbars = "aura" }
function Preview.DropRefusal(key, id, target)
    if not target or target == key or id == nil or ns.Catalog.IsCustom(id) then return nil end
    local bar = BarCfg(target)
    if type(bar) ~= "table" then return nil end
    local name = ns.Options.BarTitle(target) or target
    local origin = ns.Catalog.SourceOf(id)
    if ns.DB.IsBuiltinBar(target) then
        if origin and FAMILY[origin] and FAMILY[origin] == FAMILY[target] then
            return L["To move it to %s, drag it there in Blizzard's Cooldown Manager."]:format(name)
        end
        return L["%s only shows what Blizzard's Cooldown Manager puts on it."]:format(name)
    end
    local originBar = origin and BarCfg(origin)
    if originBar and originBar.kind == "bars" then
        return L["Spells from a bar list can only go into bar groups."]
    end
    return L["Spells from an icon list can only go into icon groups."]
end

------------------------------------------------------------
-- 預覽物件
------------------------------------------------------------
local Proto = {}
Proto.__index = Proto

function Preview.Create(parent, key, width)
    local pv = setmetatable({ key = key, width = width, cells = { icons = {}, bars = {} }, used = {} }, Proto)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    W.Stylize(f, { 0.06, 0.06, 0.06, 1 }, { 0, 0, 0, 1 })
    P.Size(f, width, MIN_H)
    pv.frame = f

    local scroll = CreateFrame("ScrollFrame", nil, f)
    scroll:SetPoint("TOPLEFT", 1, -1)
    scroll:SetPoint("BOTTOMRIGHT", -1, 1)
    local canvas = CreateFrame("Frame", nil, scroll)
    canvas:SetSize(width, MIN_H)
    scroll:SetScrollChild(canvas)
    pv.scroll, pv.canvas = scroll, canvas

    -- 橫向捲軸（溢出才出現）：細條＋職業色拇指
    local hbar = CreateFrame("Slider", nil, f, "BackdropTemplate")
    hbar:SetOrientation("HORIZONTAL")
    hbar:SetPoint("BOTTOMLEFT", 2, 2)
    hbar:SetPoint("BOTTOMRIGHT", -2, 2)
    hbar:SetHeight(6)
    W.Stylize(hbar, { 0.115, 0.115, 0.115, 1 }, { 0, 0, 0, 1 })
    local thumb = hbar:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture(WHITE)
    thumb:SetVertexColor(W.Accent(0.8))
    thumb:SetSize(40, 6)
    hbar:SetThumbTexture(thumb)
    hbar:SetMinMaxValues(0, 0)
    hbar:SetValueStep(1)
    hbar:SetScript("OnValueChanged", function(_, v) scroll:SetHorizontalScroll(v) end)
    hbar:Hide()
    pv.hbar = hbar

    f:EnableMouseWheel(true)
    f:SetScript("OnMouseWheel", function(_, delta)
        local maxX = pv.maxX or 0
        local maxY = pv.maxY or 0
        if maxX > 0 and (maxY <= 0 or IsShiftKeyDown()) then
            local v = math.min(maxX, math.max(0, (scroll:GetHorizontalScroll() or 0) - delta * 40))
            hbar:SetValue(v)
        elseif maxY > 0 then
            scroll:SetVerticalScroll(math.min(maxY, math.max(0, (scroll:GetVerticalScroll() or 0) - delta * 30)))
        end
    end)

    -- 插入位置的職業色線、拖曳中的鬼影
    local line = canvas:CreateTexture(nil, "OVERLAY", nil, 7)
    line:SetTexture(WHITE)
    line:Hide()
    pv.line = line

    -- 長條的十五秒循環、效果預覽的倒數（只在顯示中跑）
    local acc = 0
    f:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.05 then return end
        acc = 0
        pv:Tick()
        pv:FxTick()
    end)

    -- 效果預覽列：預覽框底下那一條（捲動區與橫向捲軸往上讓出 FX_H）
    if NoFakeCD(key) then
        scroll:SetPoint("BOTTOMRIGHT", -1, 1 + FX_H)
        hbar:ClearAllPoints()
        hbar:SetPoint("BOTTOMLEFT", 2, 2 + FX_H)
        hbar:SetPoint("BOTTOMRIGHT", -2, 2 + FX_H)
        local row = CreateFrame("Frame", nil, f)
        row:SetPoint("BOTTOMLEFT", 1, 1)
        row:SetPoint("BOTTOMRIGHT", -1, 1)
        row:SetHeight(FX_H)
        local label = row:CreateFontString(nil, "OVERLAY")
        label:SetFontObject(W.fontNormal)
        label:SetPoint("LEFT", row, "LEFT", PAD, 0)
        label:SetText(L["Preview:"])
        local x = PAD + math.ceil(label:GetStringWidth() or 0) + 6
        for _, def in ipairs(FX_BUTTONS) do
            local b = W.CreateButton(row, def.label, "normal", 70, 20)
            W.FitButton(b, 70, 20)
            b:SetPoint("LEFT", row, "LEFT", x, 0)
            b:SetScript("OnClick", function() pv:StartFx(def.kind) end)
            x = x + (b:GetWidth() or 70) + 6
        end
        pv.fxRow = row
    end

    instances[key] = pv
    return pv
end

function Preview.Refresh(key)
    local pv = instances[key]
    if pv and pv.frame:IsVisible() then pv:Refresh() end
    -- 溢出的兩端互相牽動（來源條改順序／移除，接收條尾端跟著變；反之亦然）
    local pairsList = ns.Catalog.OverflowPairs and ns.Catalog.OverflowPairs()
    for _, pr in ipairs(pairsList or {}) do
        local other = (pr.src == key and pr.dst) or (pr.dst == key and pr.src) or nil
        local opv = other and instances[other]
        if opv and opv.frame:IsVisible() then opv:Refresh() end
    end
end

-- 引擎那邊「畫不出來的格子」變了：預覽跟著重畫
ns.RegisterCallback("MissingChanged", "preview", function(key) Preview.Refresh(key) end)

function Preview.RefreshAll()
    for _, pv in pairs(instances) do
        if pv.frame:IsVisible() then pv:Refresh() end
    end
end

function Proto:Height()
    return self.frame:GetHeight() or MIN_H
end

function Proto:Acquire(kind)
    local pool = self.cells[kind]
    local n = (self.used[kind] or 0) + 1
    self.used[kind] = n
    local c = pool[n]
    if not c then
        c = kind == "bars" and NewBarCell(self.canvas) or NewIconCell(self.canvas)
        pool[n] = c
        self:Wire(c)
    end
    return c
end

function Proto:Refresh()
    local key = self.key
    local bar = BarCfg(key)
    for _, pool in pairs(self.cells) do for _, c in ipairs(pool) do c:Hide() end end
    self.used = {}
    self.fxTaken = false
    if not bar then return end
    local kind = bar.kind == "bars" and "bars" or "icons"
    self.kind = kind

    -- 移除的不畫在預覽上（要加回來按「＋」）：預覽上有什麼，畫面上就有什麼
    local visible, hidden = ns.Catalog.Bar(key, true)
    hidden = hidden or {}
    local entries = {}
    -- 溢出（圖示類才有）：來源條要畫暗的那幾顆、接收條尾端要補畫的那幾顆
    local ov = kind == "icons" and ns.Catalog.OverflowStatic and ns.Catalog.OverflowStatic() or nil
    local goneSet = ov and ov.toSet[key]
    local goneTo = ov and ov.target[key]
    for _, id in ipairs(visible) do
        entries[#entries + 1] = { id = id, overflowTo = goneSet and goneSet[id] and goneTo or nil }
    end
    local from = ov and ov.from[key]
    if from then
        for _, id in ipairs(ov.out[key]) do
            if from[id] then entries[#entries + 1] = { id = id, incoming = from[id] } end
        end
    end
    entries[#entries + 1] = { plus = true }
    self.count, self.hiddenCount = #visible, #hidden

    local sizing = Sizing(key, bar)
    local rects, totalW, totalH = ns.Layout.Compute(entries, sizing, kind)

    -- 視窗：寬固定（頁面寬），高跟著內容、上限 MAX_H；內容比較窄時置中
    local viewW = self.width
    local contentW, contentH = totalW + PAD * 2, totalH + PAD * 2
    local viewH = math.max(MIN_H, math.min(MAX_H, contentH + 2))
    local ox = contentW < viewW and math.floor((viewW - totalW) / 2) or PAD
    self.maxX = math.max(0, contentW - viewW + 2)
    self.maxY = math.max(0, contentH - viewH + 2)
    if self.maxX > 0 then viewH = math.min(MAX_H + 8, viewH + 8) end   -- 讓出捲軸那一條
    P.Size(self.frame, viewW, viewH + (self.fxRow and FX_H or 0))
    self.canvas:SetSize(math.max(viewW, contentW), math.max(viewH, contentH))
    self.hbar:SetShown(self.maxX > 0)
    self.hbar:SetMinMaxValues(0, self.maxX)
    if self.maxX <= 0 then self.scroll:SetHorizontalScroll(0) end
    if self.maxY <= 0 then self.scroll:SetVerticalScroll(0) end

    local now = GetTime()
    self.slots = {}
    for i, e in ipairs(entries) do
        local r = rects[i]
        local c
        if e.plus then
            c = self.plus
            if not c then
                c = NewPlusCell(self.canvas)
                self.plus = c
                self:Wire(c)
            end
        else
            c = self:Acquire(kind)
        end
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", ox + r.x, -(PAD + r.y))
        c:SetSize(r.w, r.h)
        c.id, c.hiddenItem, c.index = e.id, e.hidden and true or false, i
        c.overflowTo, c.incoming = e.overflowTo or false, e.incoming or false
        if not e.plus then
            self:Fill(c, e, i, r, now)
            -- 溢來的格不進 slots：拖曳排序寫的是這條自己的 order，它的順序屬於來源條
            if not e.hidden and not e.incoming then self.slots[#self.slots + 1] = c end
        end
        -- 清單上有、暴雪卻沒給框的：畫面上不會有，這裡標暗（提示有說明），不要假裝它在
        c.missing = (not e.plus and ns.Bars and ns.Bars.IsMissing and ns.Bars.IsMissing(key, e.id)) and true or false
        -- 天賦條件不成立（Core/Catalog.lua）：畫面上不顯示，預覽照樣列出來（點得到才改得回來），一樣標暗
        c.talentBlocked = (not e.plus and ns.Catalog.TalentBlocked(e.id)) and true or false
        -- 冷卻狀態效果：Decorate.ApplyPreview 照設定算好的 alpha（變暗＝設定值、兩種隱藏＝0.25）
        c:SetAlpha((e.hidden or c.missing or c.talentBlocked or e.overflowTo) and 0.35 or (not e.plus and c.stateAlpha) or 1)
        c:Show()
    end
    if self.onRefresh then self.onRefresh(self) end
end

-- 預覽格右下的充能數：真的有充能（GetSpellCharges 明文 maxCharges > 1）才印它的上限，
-- 問不到／秘密值／沒充能一律不印——整排假「2」會誤導（使用者 2026-10-03）
local function PreviewCharges(info)
    if not info or info.kind == "aura" or info.kind == "item" or info.kind == "slot" then return nil end
    local spellID = info.overrideSpellID or info.spellID
    local fn = C_Spell and C_Spell.GetSpellCharges
    if type(spellID) ~= "number" or not fn then return nil end
    local ok, ci = pcall(fn, spellID)
    if not ok or type(ci) ~= "table" then return nil end
    local ok2, m = pcall(function() return ci.maxCharges end)
    m = ok2 and ns.Catalog.Plain(m) or nil
    if type(m) == "number" and m > 1 then return m end
    return nil
end

function Proto:Fill(c, e, i, r, now)
    local key, id = self.key, e.id
    local info = ns.Catalog.Info(id)
    c.charges = PreviewCharges(info)
    -- 自訂圖示（逐法術覆寫）也照畫；光環格不支援（ns.IconFor 自己會略過）
    local tex = ns.IconFor(key, id, info) or QUESTION
    if info and info.custom then
        c.aura = info.kind == "aura"
        c.custom, c.known = info.kind, info.isKnown ~= false
        c.scope = info.scope or "spec"
    else
        local src = ns.Catalog.SourceOf(id)
        c.aura = AURA_SRC[src] and true or false
        c.custom, c.known = false, true    -- false 不是 nil：格子是池化的框，欄位要明確蓋掉
        c.scope = false
    end
    PaintScopeMark(c.scopeMark, c.scope)
    -- 核心／輔助技能（暴雪那兩條）不畫假冷卻：轉圈、倒數、去飽和一律不上，看起來就是就緒的樣子（使用者 2026-10-03）
    c.onCD = (not c.aura) and (i % 2 == 1) and not e.hidden and not NoFakeCD(key)
    -- 效果預覽：只有第一個技能格演示（Refresh 開頭把 fxTaken 歸零）
    local fx = self:ActiveFx()
    if fx and (c.aura or e.hidden or self.fxTaken) then fx = nil end
    if fx then self.fxTaken = true end
    local fxTimer = fx and (fx.kind == "cooldown" or fx.kind == "aura")
    if fxTimer then c.onCD = (not c.aura) and not e.hidden end
    -- 假冷卻的格每隔一格當成「還在倒增益的持續時間」（倒數換 durationColor）；自訂項目沒有那一段
    c.auraPhase = (c.onCD and not c.custom and (i % 4 == 1)) and true or false
    if fxTimer then c.auraPhase = (c.onCD and fx.kind == "aura") and true or false end
    c.name = (info and info.name) or ("#" .. tostring(id))
    c.decorated = nil
    if c.kind == "bars" then
        c.Icon.Icon:SetTexture(tex)
        -- 沒學會的自訂法術：問號＋灰（圖示格那邊由轉圈的假冷卻表達，長條沒有）
        c.Icon.Icon:SetDesaturated((c.custom and not c.known) and true or false)
        c.cycleOffset = (i * 3) % CYCLE
    else
        c.Icon:SetTexture(tex)
        if c.Cooldown then
            if c.onCD and fxTimer then
                c.Cooldown:SetCooldown(fx.start, fx.secs)
            elseif c.onCD then
                c.Cooldown:SetCooldown(now - ((i * 2) % CYCLE), CYCLE)
            else
                c.Cooldown:Clear()
            end
        end
    end
    ns.Decorate.ApplyPreview(c, key, id, r.w, r.h)
    -- 沒學會的自訂法術：圖示格以前靠假冷卻的去飽和表達，假冷卻拿掉之後自己灰（同長條）
    if c.kind ~= "bars" and c.custom and not c.known and c.Icon and c.Icon.SetDesaturated then
        c.Icon:SetDesaturated(true)
    end
    self:FxGlow(c, (fx and (fx.kind == "proc" or fx.kind == "ready") and not c.aura and not e.hidden) and fx.kind or nil)
    -- 生效發光：勾了的增益在預覽上常亮（樣式、顏色照單一法術小窗的設定）。長條亮在圖示那一格
    if ns.Glow and ns.Glow.PreviewActive then
        if not c.glowHost then
            c.glowHost = CreateFrame("Frame", nil, c)
            c.glowHost:SetAllPoints(c.kind == "bars" and c.Icon or c)
            c.glowHost:SetFrameLevel(c:GetFrameLevel() + 3)
        end
        ns.Glow.PreviewActive(c.glowHost, key, (c.aura and not e.hidden) and id or nil)
    end
    if c.kind == "bars" then
        c.Bar.Name:SetText(c.name)
        c.Icon.Applications:SetText("")      -- 假層數不印（礙眼；增益圖示的預覽同樣不印）
    else
        c.cdText:SetText(fxTimer and self:FxText(c) or "15")
        c.chargeText:SetText(c.charges and tostring(c.charges) or "")
        c.stackText:SetText("2")
    end
    -- 以增益取代：成立的才畫記號（設了但增益現在不在 ⇒ 不畫，真實條上也是技能本身）
    if c.replaceMark then
        local b = (not e.hidden) and ns.Catalog.ReplaceTarget(id) or nil
        local binfo = b and ns.Catalog.Info(b)
        if b then
            c.replaceMark.icon:SetTexture((binfo and binfo.icon) or QUESTION)
            c.replaceMark:Show()
        else
            c.replaceMark:Hide()
        end
    end
    -- 溢出記號：溢出去的（來源條）與溢來的（接收條）都畫；有取代記號時排在它左邊
    if c.ovMark then
        local om = c.ovMark
        om:ClearAllPoints()
        if c.replaceMark and c.replaceMark:IsShown() then
            om:SetPoint("BOTTOMRIGHT", c.replaceMark, "BOTTOMLEFT", -1, 0)
        else
            om:SetPoint("BOTTOMRIGHT", c.overlay, "BOTTOMRIGHT", -1, 1)
        end
        om:SetShown((e.overflowTo or e.incoming) and true or false)
    end
end

-- 長條的時間跑 15→0（名字＝法術名）。**只印整數**：真的長條秒數是暴雪每幀用秘密的剩餘時間寫的
-- （RefreshCooldownInfo 的 COOLDOWN_DURATION_SEC），插件換不了格式，小數門檻對長條無效；
-- 預覽印小數會讓玩家以為設定沒生效（2026-10-03 使用者回報）
function Proto:Tick()
    if self.kind ~= "bars" then return end
    local pool = self.cells.bars
    local now = GetTime()
    for n = 1, self.used.bars or 0 do
        local c = pool[n]
        if c and c:IsShown() then
            local left = CYCLE - ((now + (c.cycleOffset or 0)) % CYCLE)
            c.Bar:SetValue(left / CYCLE)
            c.Bar.Duration:SetFormattedText("%d", math.ceil(left))
        end
    end
end

------------------------------------------------------------
-- 滑鼠：點、中鍵、拖曳
------------------------------------------------------------
local ghost
local function Ghost()
    if ghost then return ghost end
    ghost = CreateFrame("Frame", nil, UIParent)
    ghost:SetFrameStrata("TOOLTIP")
    ghost:SetSize(32, 32)
    ghost.tex = ghost:CreateTexture(nil, "ARTWORK")
    ghost.tex:SetAllPoints()
    ghost:SetAlpha(0.8)
    ghost:Hide()
    return ghost
end

local function ShowTip(c)
    if c.isPlus or c.dragging then return end
    GameTooltip:SetOwner(c, "ANCHOR_TOP")
    GameTooltip:SetText(c.name or "")
    if c.custom and not c.known then
        GameTooltip:AddLine(L["Not learned"], 1, 0.3, 0.3)
    end
    if c.talentBlocked then
        GameTooltip:AddLine(L["Talent condition not met, so it isn't shown on screen."], 1, 0.3, 0.3, true)
    end
    if c.missing then
        GameTooltip:AddLine(L["Blizzard's Cooldown Manager isn't showing this one right now, so it can't appear on the bar."], 1, 0.3, 0.3, true)
        local info = ns.Catalog.Info(c.id)
        if info and info.equipSlot then
            GameTooltip:AddLine(L["Blizzard's trinket tracking is unreliable. Use the \"Equipment slot\" button instead: it follows whatever is equipped in that slot."], 1, 0.82, 0, true)
        end
    end
    if c.custom == "aura" then
        -- 光環格：只講它什麼時候出現；位置跟其他格一樣可以拖
        GameTooltip:AddLine(L["Aura slot: only appears while the aura is up."], 1, 0.82, 0, true)
    end
    -- 自訂項目的適用範圍（職業層／戰隊層右上角有記號，這裡寫明）
    if c.custom and c.scope then
        GameTooltip:AddLine(L["Scope: %s"]:format(ns.Picker.ScopeText(c.scope)), 0.8, 0.8, 0.8)
    end
    -- 溢出：去向／來源（條名）
    if c.overflowTo then
        GameTooltip:AddLine(L["Overflows to: %s"]:format(ns.Options.BarTitle(c.overflowTo) or c.overflowTo), 1, 0.82, 0, true)
    end
    if c.incoming then
        GameTooltip:AddLine(L["From: %s"]:format(ns.Options.BarTitle(c.incoming) or c.incoming), 1, 0.82, 0, true)
    end
    GameTooltip:AddLine(L["Left-click: settings for this spell"], 0.8, 0.8, 0.8)
    GameTooltip:AddLine(L["Middle-click: remove"], 0.8, 0.8, 0.8)
    if not c.incoming then
        GameTooltip:AddLine(L["Drag: reorder, or drop on a group on the left"], 0.8, 0.8, 0.8)
    end
    GameTooltip:Show()
end

function Proto:Wire(c)
    local pv = self
    if not c.isPlus then
        c:SetScript("OnEnter", ShowTip)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    c:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" or self.isPlus or self.hiddenItem then return end
        local x, y = Cursor(pv.canvas)
        pv.press = { cell = self, x = x, y = y }
        pv.frame:SetScript("OnUpdate", function(_, elapsed) pv:DragTick(elapsed) end)
    end)
    c:SetScript("OnMouseUp", function(self, button)
        local press = pv.press
        if press and press.dragging then pv:EndDrag(true) return end
        pv.press = nil
        pv:RestoreTicker()
        -- 溢來的格被拖、已經跳了彈窗：這次放手不算點擊（不管按了多久）
        if self.suppressClick then self.suppressClick = nil return end
        -- 拖曳剛在 OnUpdate 那邊收掉（放手的那一幀先跑到 DragTick）：這一下不算點擊
        if pv.dragEnded and GetTime() - pv.dragEnded < 0.2 then return end
        if not self:IsMouseOver() then return end
        if self.isPlus then
            if button == "LeftButton" and ns.Picker then ns.Picker.Open(pv.key, self) end
        elseif button == "MiddleButton" then
            -- 中鍵＝移除（不問）。要的話再按「＋」加回來
            GameTooltip:Hide()
            Preview.Remove(pv.key, self.id)
        elseif button == "LeftButton" then
            if ns.SpellPopover then ns.SpellPopover.Open(pv.key, self.id, self) end
        end
    end)
end

function Proto:RestoreTicker()
    local pv = self
    local acc = 0
    self.frame:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 0.05 then return end
        acc = 0
        pv:Tick()
        pv:FxTick()
    end)
end

------------------------------------------------------------
-- 效果預覽（核心／輔助技能）
------------------------------------------------------------
-- 進行中的效果（過期的當沒有：計時器收尾前那幾幀也不會畫錯）
function Proto:ActiveFx()
    local fx = self.fx
    if fx and GetTime() < fx.start + fx.secs then return fx end
    return nil
end

function Proto:StartFx(kind)
    -- 倒數類（冷卻中／增益持續時間）要看得到「正常 → 低秒變色／小數」的轉換：從門檻（低秒、小數取大的）
    -- 再往上 3 秒開始倒，至少 FX_SECS；預設門檻 5 ⇒ 倒 8 秒。發光類固定 FX_SECS
    local secs = FX_SECS
    if kind == "cooldown" or kind == "aura" then
        local ct = ns.Decorate.Resolve(self.key).cooldownText or {}
        local th = math.max(tonumber(ct.lowBelow) or 0, tonumber(ct.decimalsBelow) or 0)
        secs = math.max(FX_SECS, math.ceil(th) + 3)
    end
    local fx = { kind = kind, start = GetTime(), secs = secs }
    self.fx = fx
    self:Refresh()
    C_Timer.After(secs, function()
        if self.fx ~= fx then return end         -- 期間又按了別的：讓新的那個收尾
        self.fx = nil
        if self.frame:IsVisible() then self:Refresh() else self:ClearFxGlows() end
    end)
end

-- 一格的效果發光：which ＝ "proc"／"ready"／nil（收掉）。發光框是格子上自己的子框（池化的格子一起重用）
function Proto:FxGlow(c, which)
    local G = ns.Glow
    if not (G and G.PaintOn) then return end
    local cur = c.fxGlow
    if cur and cur.which == which then return end
    if cur then
        G.StopOn(c.fxHost, cur.t, "pvfx")
        c.fxGlow = nil
    end
    if not which then return end
    if not c.fxHost then
        c.fxHost = CreateFrame("Frame", nil, c)
        c.fxHost:SetFrameLevel(c:GetFrameLevel() + 4)
    end
    c.fxHost:ClearAllPoints()
    c.fxHost:SetAllPoints(c.kind == "bars" and c.Icon or c)
    local cfg = ns.Setting(self.key, "glow." .. which)
    local t = G.PaintOn(c.fxHost, type(cfg) == "table" and cfg or {}, which, "pvfx", true)
    if t then c.fxGlow = { which = which, t = t } end
end

-- 頁面關著時效果到期：發光直接收掉（下次 Refresh 也會收，這裡只是不讓它在背景一直轉）
function Proto:ClearFxGlows()
    for _, pool in pairs(self.cells) do
        for _, c in ipairs(pool) do self:FxGlow(c, nil) end
    end
end

-- 倒數字：照這條「倒數文字」的小數門檻；回傳字串
function Proto:FxText(c)
    local fx = self:ActiveFx()
    if not fx then return "" end
    local left = math.max(0, fx.start + fx.secs - GetTime())
    local ct = ns.Decorate.Resolve(self.key).cooldownText or {}
    local dec = tonumber(ct.decimalsBelow) or 0
    if left < dec then return ("%.1f"):format(left) end
    return tostring(math.ceil(left))
end

local function RGBA(t, r, g, b, a)
    if type(t) ~= "table" then return r, g, b, a end
    return t.r or r, t.g or g, t.b or b, t.a or a
end

-- 冷卻中／增益持續時間：倒數每 0.05 秒重寫一次，低秒變色照設定（增益那一段用它自己的低秒色）
function Proto:FxTick()
    local fx = self:ActiveFx()
    if not fx or (fx.kind ~= "cooldown" and fx.kind ~= "aura") or self.kind == "bars" then return end
    local style = ns.Decorate.Resolve(self.key)
    local ct = style.cooldownText or {}
    local left = fx.start + fx.secs - GetTime()
    local low = left < (tonumber(ct.lowBelow) or 0)
    for _, c in ipairs(self.slots or {}) do
        if c.onCD and c.cdText then
            c.cdText:SetText(self:FxText(c))
            if low then
                local lc = (c.durColor and style.durationLowColor) or ct.lowColor
                c.cdText:SetTextColor(RGBA(lc, 1, 0.3, 0.3, 1))
            else
                c.cdText:SetTextColor(RGBA(c.durColor or ct.color, 1, 1, 1, 1))
            end
        end
    end
end

function Proto:BeginDrag()
    local press = self.press
    local c = press.cell
    press.dragging = true
    c.dragging = true
    GameTooltip:Hide()
    local g = Ghost()
    local info = ns.Catalog.Info(c.id)
    g.tex:SetTexture(ns.IconFor(self.key, c.id, info) or QUESTION)
    g:Show()
    for _, s in ipairs(self.slots) do
        if s ~= c then s:SetAlpha(0.5) end
    end
    c:SetAlpha(0.25)
    press.candidates = Preview.DropCandidates(self.key, c.id)
    ns.Sidebar.BeginDrop(press.candidates)
end

-- 游標底下的插入位置：離游標最近的格，決定插在它前面或後面。
-- 「後面」是清單順序的方向，不一定是右邊／下面：條往上長（長條、直向圖示）時第 1 格在最下面、
-- 往左長時第 1 格在最右邊。方向照相鄰格的實際位置量（同一列的鄰格最近，換列那格比較遠），
-- 只有一格時才退回預設（長條往下、圖示往右）。
-- 回傳 pos, 格子, 插入線畫在格子的哪一邊（"TOP"／"BOTTOM"／"LEFT"／"RIGHT"）
function Proto:InsertionAt()
    if not self.frame:IsMouseOver() then return nil end
    local cx, cy = Cursor(self.canvas)
    local best, bestD
    for i, s in ipairs(self.slots) do
        local x, y = s:GetCenter()
        if x then
            local d = (x - cx) ^ 2 + (y - cy) ^ 2
            if not bestD or d < bestD then best, bestD = i, d end
        end
    end
    if not best then return nil end
    local s = self.slots[best]
    local x, y = s:GetCenter()
    -- 清單順序往後的方向向量（dx, dy）
    local dx, dy
    local nearD
    for _, j in ipairs({ best - 1, best + 1 }) do
        local n = self.slots[j]
        -- ⚠ 不能寫 `n and n:GetCenter()`：and 只留第一個回傳值，ny 會是 nil
        local nx, ny
        if n then nx, ny = n:GetCenter() end
        if nx and ny then
            local d = (nx - x) ^ 2 + (ny - y) ^ 2
            if d > 0 and (not nearD or d < nearD) then
                nearD = d
                if j > best then dx, dy = nx - x, ny - y else dx, dy = x - nx, y - ny end
            end
        end
    end
    if not dx then
        if self.kind == "bars" then dx, dy = 0, -1 else dx, dy = 1, 0 end
    end
    local after = (cx - x) * dx + (cy - y) * dy > 0
    local side
    if math.abs(dx) >= math.abs(dy) then
        side = ((dx > 0) == after) and "RIGHT" or "LEFT"
    else
        side = ((dy > 0) == after) and "TOP" or "BOTTOM"
    end
    return best + (after and 1 or 0), s, side
end

function Proto:DragTick()
    local press = self.press
    if not press then return end
    if not IsMouseButtonDown("LeftButton") then
        if press.dragging then self:EndDrag(true) else self.press = nil; self:RestoreTicker() end
        return
    end
    local x, y = Cursor(self.canvas)
    if not press.dragging then
        if math.abs(x - press.x) < DRAG_MIN and math.abs(y - press.y) < DRAG_MIN then return end
        -- 溢來的格：順序屬於來源條，這裡不能拖 ⇒ 收掉這次按下、跳彈窗說明（附「前往那條」）
        if press.cell.incoming then
            local src = press.cell.incoming
            self.press = nil
            press.cell.suppressClick = true  -- 放手那一下不算點擊（不開逐法術面板）
            self:RestoreTicker()
            GameTooltip:Hide()
            Preview.ShowIncomingRefusal(src)
            return
        end
        self:BeginDrag()
    end
    local g = Ghost()
    local ux, uy = Cursor(UIParent)
    g:ClearAllPoints()
    g:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ux + 12, uy - 12)

    local line = self.line
    if ns.Sidebar.DropTargetAtCursor() or ns.Sidebar.ButtonAtCursor() then
        line:Hide()
        press.pos = nil
        return
    end
    local pos, s, side = self:InsertionAt()
    press.pos = pos
    if not pos then line:Hide() return end
    line:SetVertexColor(W.Accent(1))
    line:ClearAllPoints()
    local t = P.Scale(2)
    if side == "BOTTOM" then
        line:SetPoint("TOPLEFT", s, "BOTTOMLEFT", 0, -1)
        line:SetSize(s:GetWidth(), t)
    elseif side == "TOP" then
        line:SetPoint("BOTTOMLEFT", s, "TOPLEFT", 0, 1)
        line:SetSize(s:GetWidth(), t)
    elseif side == "RIGHT" then
        line:SetPoint("TOPLEFT", s, "TOPRIGHT", 1, 0)
        line:SetSize(t, s:GetHeight())
    else
        line:SetPoint("TOPRIGHT", s, "TOPLEFT", -1, 0)
        line:SetSize(t, s:GetHeight())
    end
    line:Show()
end

-- 放在放不進去的左欄按鈕上：彈窗說原因，附一顆開暴雪冷卻管理器（跨暴雪清單只能在那裡搬）。
-- 不關自己的視窗：開暴雪面板的慣例是兩邊並排（Tab_Bar.OpenBlizzard）
local refusePopup
local function ShowRefusal(reason)
    if not refusePopup then
        refusePopup = W.CreateChoicePopup(ns.Options.panel, 360, "", {
            { text = L["Open Blizzard Cooldown Manager"], color = "primary",
              onClick = function() if ns.TabBar and ns.TabBar.OpenBlizzard then ns.TabBar.OpenBlizzard() end end },
            { text = L["Close"], color = "normal" },
        })
    end
    refusePopup.text:SetText(reason)
    refusePopup:Hide()          -- 重開才會跑 OnShow 依字數重算高度
    refusePopup:Show()
end
Preview.ShowRefusal = ShowRefusal

-- 溢來的格被拖：說明它的位置跟著來源條，附一顆「前往那條」（切到來源條的頁面）
local incomingPopup, incomingSrc
function Preview.ShowIncomingRefusal(src)
    incomingSrc = src
    if not incomingPopup then
        incomingPopup = W.CreateChoicePopup(ns.Options.panel, 360, "", {
            { text = L["Go to that bar"], color = "primary",
              onClick = function() if incomingSrc then ns.Options.ShowPage(incomingSrc) end end },
            { text = L["Close"], color = "normal" },
        })
    end
    local name = ns.Options.BarTitle(src) or tostring(src)
    incomingPopup.text:SetText(L["This icon overflows here from %s. Its place follows the order on that bar, so reorder it there."]:format(name))
    incomingPopup:Hide()        -- 重開才會跑 OnShow 依字數重算高度
    incomingPopup:Show()
end

function Proto:EndDrag(commit)
    local press = self.press
    self.press = nil
    self:RestoreTicker()
    self.line:Hide()
    if ghost then ghost:Hide() end
    if not (press and press.dragging) then return end
    self.dragEnded = GetTime()
    local c = press.cell
    c.dragging = false
    local target = ns.Sidebar.DropTargetAtCursor()
    local over = ns.Sidebar.ButtonAtCursor()
    ns.Sidebar.EndDrop()
    if not commit then self:Refresh() return end
    if target and press.candidates and press.candidates[target] then
        Preview.MoveTo(c.id, target, self.key)
        return
    end
    if over then
        self:Refresh()
        local reason = Preview.DropRefusal(self.key, c.id, over)
        if reason then ShowRefusal(reason) end
        return
    end
    local pos = press.pos
    if not pos then self:Refresh() return end
    -- 新順序：可見的照畫面順序、拖的那顆移到插入位置；隱藏的接在後面
    local ids, from = {}, nil
    for i, s in ipairs(self.slots) do
        ids[i] = s.id
        if s == c then from = i end
    end
    if not from then self:Refresh() return end
    if pos == from or pos == from + 1 then self:Refresh() return end
    table.remove(ids, from)
    if pos > from then pos = pos - 1 end
    table.insert(ids, pos, c.id)
    local _, hidden = ns.Catalog.Bar(self.key, true)
    for _, id in ipairs(hidden or {}) do ids[#ids + 1] = id end
    local sp = ns.DB.SpecSpells(true)
    if not sp then self:Refresh() return end
    sp.order[self.key] = ids
    Changed("membership", self.key)
end
