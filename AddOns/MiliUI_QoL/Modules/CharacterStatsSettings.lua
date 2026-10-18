------------------------------------------------------------
-- MiliUI_QoL: 角色面板右上角的齒輪 ＋ 角色面板右側的「這一頁的設定」面板
-- （2026-10-15 從 MiliUI_Skin 搬來）
--
-- 齒輪點一下 ＝ 切換屬性清單的**編輯狀態**（`X.SetEditing`，CharacterSheetCommon.lua）：
--   面板開著 ＝ 編輯狀態 on；關掉（× 鈕、再點齒輪、關角色面板）＝ off。狀態不存檔。
--   編輯狀態裡清單可以拖曳排序、每列勾選顯示、每區換色（CharacterStats.lua）；
--   畫面上的屬性顯示（StatsHud.lua）這時也可以拖。
-- 面板的顯示條件 ＝ 編輯狀態 on 而且 `PaperDollFrame` 顯示中——切到聲望／通貨頁時面板
-- 收起來、切回來再出現；角色面板整個關掉就把編輯狀態關掉。
--
-- 這是**就地編輯器**：清單的配色／顯示哪些列、HUD 的全部選項，改了當場看得到。
-- 同一組 HUD 設定在 /mqol 的「角色面板」頁也有（Options/Controls.lua），兩邊改的是同一張表。
-- 建不建的開關（自建清單、稱號搜尋，要 /reload）只在 /mqol 那邊。
--
-- 面板的內容延到第一次打開才建。版面是這支自己的「直排表單」（標籤一行、控件一行；
-- 勾選框的名字在框的右邊），**不走** `Controls.Build`：共用層的表單是「左欄標籤 ＋
-- 右欄控件」，標籤欄寬是宿主層級的常數（這包 `Env.LABEL_W = 200`），320 寬的側邊面板
-- 扣掉它剩不到 100 給控件，滑桿與下拉都塞不下。控件本身照樣是共用層的。
-- 說明一律是控件下一列的灰字（feedback-options-toggle-description）。
--
------------------------------------------------------------
-- ## 對暴雪物件的接觸面
--
-- | 物件 | 動作 |
-- |---|---|
-- | PaperDollFrame | 齒輪的 parent（跟著角色分頁顯隱）；`HookScript("OnShow"/"OnHide")` 同步面板顯隱；讀 `IsShown()` |
-- | PaperDollSidebarTabs | **重錨一次**（`ClearAllPoints`＋`SetPoint`，建立時）：整列（三個分頁＋齒輪）置中在 InsetRight 上。使用者 2026-10-15 點名要的；暴雪對這個容器只 `Show()`／`Hide()`（PaperDollFrame.lua:1436／:1451）、從不重錨，三顆分頁都錨在容器內部所以跟著走；不是保護框、不歸編輯模式管 |
-- | PaperDollSidebarTab3 | 齒輪的錨點（第四格；只當 relativeTo，不讀不寫）；找不到才退回 CharacterFrame.InsetRight |
-- | CharacterFrame.InsetRight | 齒輪的備援錨點；讀 parentKey（pcall 包著，結構查詢） |
-- | CharacterFrame | 面板的 parent ＋ 錨點（右緣外側）；`GetFrameLevel()`（`X.TargetLevel`）——面板層級 ＝ 它 +30、齒輪 ＝ PaperDollFrame +20；`HookScript("OnHide")` 關編輯狀態 |
-- | GameTooltip | 齒輪的提示（SetOwner／SetText／Show／Hide） |
-- | ColorPickerFrame | 色票走共用層 `W.CreateColorPicker` |
--
-- 寫入暴雪欄位：無。hook：只有上面三個 HookScript（後置、只改自己的框與狀態）。
-- 面板是 CharacterFrame 的子框 ⇒ ESC 關角色面板時跟著關，不另外登記 UISpecialFrames。
-- 戰鬥：面板、齒輪、編輯狀態全是自己的框，戰鬥中開關都合法；把它們掛到暴雪框底下那一步
-- 在建立時做（X.Boot 已經把戰鬥中的建立延到脫戰）。
------------------------------------------------------------
local _, ns = ...

local X = ns.CharSheet
local C = X.C
local S = ns.Secret
local P = ns.P
local W = ns.W
local Stats = ns.Stats

-- 齒輪：排成側邊分頁的「第四格」——中心對齊 PaperDollSidebarTab3 的中心、往右一格。
-- 分頁 33 寬、間距 4（PaperDollFrame.xml:394／:506），角色／稱號／裝備／⚙ 四個中心等距。
-- 這些是暴雪 XML 的 UI 單位，不過 P.Scale。
-- 備援（找不到 Tab3）：錨 InsetRight 右上角——分頁列底貼在 InsetRight 上緣（y=-1）、
-- 高 35，所以中心在上緣 +16.5；Tab3 右緣在 -36、第四格中心在 -15.5。
local GEAR_SIZE   = 14
local GEAR_SLOT   = 33 + 4
local GEAR_FB_X   = -15.5
local GEAR_FB_Y   = 16.5

-- 分頁列置中：容器 PaperDollSidebarTabs 168×35、底貼 InsetRight 上緣（y=-1，PaperDollFrame.xml:478），
-- 三顆分頁佔容器 x∈[31,138]，所以容器中心就是三顆分頁的中心。齒輪佔第四格 ⇒ 四格一起
-- 置中要把容器往左挪半格（(33+4)/2）。y 照暴雪的 -1。
-- ⚠ 命名避開下面設定面板那排分頁鈕的 TABS_Y／TAB_H（同檔另一組 local）：兩邊各自叫
--   TABS_Y 的話，後宣告的遮蔽前者、luac 不報（.claude/notes/wow-lua-duplicate-local-after-merge.md）。
local SIDEBAR_X   = -GEAR_SLOT / 2
local SIDEBAR_Y   = -1
local GEAR_IDLE   = 0.45
local GEAR_TEX    = "Interface\\AddOns\\MiliUI_QoL\\Media\\icon-settings.png"

local PANEL_W     = 320
local PANEL_GAP   = 4      -- 面板與角色面板右緣之間
local PANEL_LEVEL = 30     -- 高過 CharacterFrame 的子孫（要蓋住別的插件掛在右側的裝備清單）
local FORM_W      = PANEL_W - 12 - 8 - 20 - 4   -- 內距 12／8、捲軸 20、右邊再留 4

local panel, gear
local refreshers = {}

local function EX() return X.DB() end
local function HDB() return X.DB().hud end

local function RefreshAll()
    for _, fn in ipairs(refreshers) do fn() end
end

-- 設定面板開著沒（畫面上的屬性顯示用它判斷可不可以拖）
function X.SettingsShown()
    return panel ~= nil and panel:IsVisible()
end

-- 面板的左緣與下緣（UIParent 單位，UIParent 左上角起算；y 往下是負的）。
-- 畫面上的屬性顯示第一次開啟時擺在面板正下方，勾下去當場就看得到。面板沒開就回 nil。
function X.SettingsRect()
    if not (panel and panel:IsVisible()) then return nil end
    local l, b = panel:GetLeft(), panel:GetBottom()
    local pl, pt = UIParent:GetLeft(), UIParent:GetTop()
    if not (l and b and pl and pt) then return nil end
    local k = (panel:GetEffectiveScale() or 1) / (UIParent:GetEffectiveScale() or 1)
    return l * k - pl, b * k - pt
end

local function Doll() return _G.PaperDollFrame end

local function SyncPanel()
    if not panel then return end
    local doll = Doll()
    local want = X.IsEditing() and doll ~= nil and S.ToBool(doll:IsShown()) == true
    panel:SetShown(want)
end

------------------------------------------------------------
-- 直排表單
--
-- spec.type：
--   header   { label }
--   toggle   { label, get, set }
--   text     { label, indent }          灰字說明；indent ＝ 對齊上一列勾選框的名字
--   slider   { label, min, max, step, get, set }
--   dropdown { label, items, get, set }
--   buttons  { buttons = { { text, onClick }, ... } }
--   custom   { build(parent, y, width) → 高度, refresh }
-- set 之後一律跑全部 refresher（下拉改了標籤顏色模式，色票要跟著顯隱）。
------------------------------------------------------------
local CHECK_TEXT_X = 24     -- 勾選框（18）＋ 名字與框的間距（6）
local HEADER_GAP   = 12

local function BuildForm(parent, specs, width)
    local y = 0
    local first = true
    for _, spec in ipairs(specs) do
        local t = spec.type
        if t == "header" then
            if not first then y = y - HEADER_GAP end
            local fs = W.CreateGroupLabel(parent, spec.label)
            fs:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
            y = y - 18

        elseif t == "toggle" then
            local cb = W.CreateCheckButton(parent, spec.label, function(checked)
                spec.set(checked)
                RefreshAll()
            end)
            cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y - 3)
            local extra = cb:SetLabelMaxWidth(width - CHECK_TEXT_X - 4)
            refreshers[#refreshers + 1] = function() cb:SetChecked(spec.get() and true or false) end
            y = y - (24 + extra)

        elseif t == "text" then
            local x = spec.indent and CHECK_TEXT_X or 0
            local fs = parent:CreateFontString(nil, "OVERLAY")
            fs:SetFontObject(W.fontSmall)
            fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
            fs:SetWidth(width - x)
            fs:SetJustifyH("LEFT")
            fs:SetWordWrap(true)
            fs:SetText(spec.label)
            y = y - ((fs:GetStringHeight() or 12) + 8)

        elseif t == "slider" or t == "dropdown" then
            local label = parent:CreateFontString(nil, "OVERLAY")
            label:SetFontObject(W.fontNormal)
            label:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y - 2)
            label:SetText(spec.label)
            y = y - 20
            if t == "slider" then
                local s = W.CreateSlider(parent, spec.min, spec.max, width, spec.step, nil, function(v)
                    spec.set(v)
                    RefreshAll()
                end)
                s:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
                refreshers[#refreshers + 1] = function() s:SetValue(tonumber(spec.get()) or spec.min) end
            else
                local dd = W.CreateDropdown(parent, width, spec.items, function(v)
                    spec.set(v)
                    RefreshAll()
                end)
                dd:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
                refreshers[#refreshers + 1] = function() dd:SetSelectedValue(spec.get()) end
            end
            y = y - 28

        elseif t == "buttons" then
            local x = 0
            for _, def in ipairs(spec.buttons) do
                local b = W.CreateButton(parent, def.text, "normal", 80, 22)
                W.FitButton(b, 80, 22)
                b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 2)
                b:SetScript("OnClick", function()
                    def.onClick()
                    RefreshAll()
                end)
                x = x + (b:GetWidth() or 80) + 6
            end
            y = y - 30

        elseif t == "custom" then
            local h, refresh = spec.build(parent, y, width)
            if refresh then refreshers[#refreshers + 1] = refresh end
            y = y - h
        end
        first = false
    end
    return -y
end

------------------------------------------------------------
-- 設定項
------------------------------------------------------------
local SECTION_KEYS = { "attributes", "secondary", "tertiary", "attack", "defense" }

-- 「預設配色」：MiliUI ＝ 清掉覆寫（回共用層的五色）；職業色 ＝ 五區全部寫成職業色
function X.ApplyPalette(v)
    local ex = EX()
    ex.statsPalette = v
    ex.statsColors = {}
    if v == "class" then
        local r, g, b = X.Accent()
        for _, k in ipairs(SECTION_KEYS) do ex.statsColors[k] = { r, g, b } end
    end
    X.NotifyStatsChanged("colors")
end

function X.ResetOrder()
    local ex = EX()
    ex.statsOrder, ex.statsCollapsed, ex.statsHidden = {}, {}, {}
    X.NotifyStatsChanged("order")
end

local function HudSpec(key, t, label, extra)
    local spec = {
        type = t, label = label,
        get = function() return HDB()[key] end,
        set = function(v)
            HDB()[key] = v
            if X.Hud then X.Hud.Apply() end
        end,
    }
    for k, v in pairs(extra or {}) do spec[k] = v end
    return spec
end

-- 畫面顯示的屬性清單：一列一個（勾選框＋名字＋右端色票；色票只在「自訂」顏色時出現）
local HUD_ROW = 22

local function BuildHudStats(parent, y, width)
    local stats = X.Hud and X.Hud.STATS or {}
    local ctx = Stats.BuildContext()
    local items = {}
    for i, st in ipairs(stats) do
        local def = Stats.DefByKey[st.def]
        local name = def and def.label(ctx) or st.key
        local rowY = y - (i - 1) * HUD_ROW
        local cb = W.CreateCheckButton(parent, name, function(checked)
            HDB().stats[st.key] = checked
            X.Hud.Apply()
        end)
        cb:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, rowY - 2)
        cb:SetLabelMaxWidth(width - CHECK_TEXT_X - 24)
        local sw = W.CreateColorPicker(parent, nil, false, function(r, g, b)
            local colors = HDB().colors
            if type(colors) ~= "table" then colors = {}; HDB().colors = colors end
            colors[st.key] = { r, g, b }
            X.Hud.Apply()
        end)
        sw:SetPoint("RIGHT", parent, "TOPLEFT", width - 2, rowY - 11)
        items[i] = { st = st, cb = cb, sw = sw }
    end
    local function refresh()
        local h = HDB()
        for _, it in ipairs(items) do
            it.cb:SetChecked(h.stats[it.st.key] and true or false)
            it.sw:SetShown(h.colorMode == "custom")
            local c = X.Hud.StatColor(it.st)
            it.sw:SetColor({ r = c[1], g = c[2], b = c[3], a = 1 })
        end
    end
    return #stats * HUD_ROW + 4, refresh
end

-- HUD 的設定項（/mqol 的「角色面板」頁也拿這份清單去排，Options/Controls.lua）
X.HUD_LABEL_ITEMS = {
    { text = "完整", value = "full" },
    { text = "縮寫", value = "short" },
    { text = "不顯示", value = "none" },
}
X.HUD_COLOR_ITEMS = {
    { text = "分區色", value = "section" },
    { text = "職業色", value = "class" },
    { text = "自訂", value = "custom" },
}
X.HUD_OUTLINE_ITEMS = {
    { text = "無", value = "" },
    { text = "描邊", value = "OUTLINE" },
    { text = "粗描邊", value = "THICKOUTLINE" },
    -- 單色＝關掉反鋸齒：像素字體用（MiliUI_AuraEnhance 的 OUTLINE_ITEMS 同一組）
    { text = "單色描邊", value = "MONOCHROME,OUTLINE" },
    { text = "單色粗描邊", value = "MONOCHROME,THICKOUTLINE" },
}
X.HUD_WHEN_ITEMS = {
    { text = "永遠", value = "always" },
    { text = "只在戰鬥中", value = "combat" },
    { text = "只在副本中", value = "instance" },
}
X.PALETTE_ITEMS = {
    { text = "米利UI", value = "miliui" },
    { text = "職業色", value = "class" },
}

local function ListSpecs()
    return {
        {
            type = "dropdown", label = "顯示數值",
            items = X.ValueFormatItems(),
            get = function() return Stats.ValueFormat(EX().statsValueFormat) end,
            set = function(v) EX().statsValueFormat = v; X.NotifyStatsChanged("rating") end,
        },
        {
            type = "dropdown", label = "預設配色",
            items = X.PALETTE_ITEMS,
            get = function() return EX().statsPalette or "miliui" end,
            set = X.ApplyPalette,
        },
        {
            type = "buttons",
            buttons = {
                { text = "重設顏色", onClick = function() X.ApplyPalette("miliui") end },
                { text = "重設排序與顯示", onClick = X.ResetOrder },
            },
        },
        { type = "text", label = "面板開著時：拖曳區標題可以排序、每列前面的勾選框決定顯示、區標題右端的色票換顏色。" },

        { type = "header", label = "其他" },
        { type = "text", label = "自建屬性清單與稱號搜尋的開關在 /mqol 的「角色面板」分頁。" },
    }
end

local function HudSpecs()
    return {
        HudSpec("enabled", "toggle", "在畫面上顯示屬性"),
        { type = "text", indent = true, label = "設定面板或暴雪編輯模式開著時可以拖曳。" },
        { type = "custom", build = BuildHudStats },
        HudSpec("labelStyle", "dropdown", "標籤", { items = X.HUD_LABEL_ITEMS }),
        HudSpec("valueFormat", "dropdown", "顯示數值", { items = X.ValueFormatItems() }),
        { type = "text", label = "主屬性、耐力、攻擊／法術強度、護甲沒有百分比，一律顯示整數。" },
        HudSpec("percentSign", "toggle", "顯示 % 符號"),
        HudSpec("hideZero", "toggle", "不顯示數值為 0 的屬性"),
        { type = "text", indent = true, label = "只對次要與第三屬性；戰鬥中讀不到數值時沿用脫戰時的判斷。" },
        HudSpec("colorMode", "dropdown", "標籤顏色", { items = X.HUD_COLOR_ITEMS }),
        HudSpec("valueColored", "toggle", "數值同標籤顏色"),
        HudSpec("fontSize", "slider", "字型大小", { min = 8, max = 24, step = 1 }),
        HudSpec("outline", "dropdown", "描邊", { items = X.HUD_OUTLINE_ITEMS }),
        HudSpec("shadow", "toggle", "文字陰影"),
        HudSpec("scale", "slider", "縮放", { min = 0.6, max = 2, step = 0.05 }),
        HudSpec("backdrop", "toggle", "背景"),
        HudSpec("when", "dropdown", "顯示時機", { items = X.HUD_WHEN_ITEMS }),
        {
            type = "buttons",
            buttons = {
                { text = "重設位置", onClick = function() if X.Hud then X.Hud.ResetPosition() end end },
            },
        },
    }
end

------------------------------------------------------------
-- 面板
------------------------------------------------------------
-- 兩個分頁（屬性清單／畫面顯示）：分頁鈕一排在標題下，各自一個捲動表單，同一時間只顯示一個。
-- 分頁鈕的寫法同 Options/Panel.lua（`accent-hover` ＋ `W.CreateButtonGroup`）。
local TABS_Y    = -42      -- 分頁鈕那一排的上緣
local TAB_H     = 22
local TAB_MIN_W = 84
local TAB_PAD   = 20

local function BuildContent()
    local tabs = {
        { id = "list", label = "屬性清單", specs = ListSpecs },
        { id = "hud",  label = "畫面顯示", specs = HudSpecs },
    }
    local buttons, pages = {}, {}
    local prev
    for i, tab in ipairs(tabs) do
        local b = W.CreateButton(panel, tab.label, "accent-hover", TAB_MIN_W, TAB_H)
        b.id = tab.id
        local fs = b:GetFontString()
        local w = TAB_MIN_W
        if fs then w = math.max(TAB_MIN_W, math.ceil(fs:GetStringWidth()) + TAB_PAD) end
        P.Size(b, w, TAB_H)
        if prev then
            b:SetPoint("TOPLEFT", prev, "TOPRIGHT", 3, 0)
        else
            b:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, TABS_Y)
        end
        prev = b
        buttons[i] = b

        local holder = CreateFrame("Frame", nil, panel)
        holder:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, TABS_Y - TAB_H - 6)
        holder:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 10)
        local scroll = W.CreateScrollFrame(holder)
        local content = CreateFrame("Frame", nil, scroll.child)
        content:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 4, -4)
        content:SetSize(FORM_W, 1)
        local h = BuildForm(content, tab.specs(), FORM_W)
        content:SetHeight(h + 8)
        scroll:SetContentHeight(h + 16)
        holder:Hide()
        pages[tab.id] = holder
    end

    local function ShowTab(id)
        W.CloseDropdowns()
        for tabId, page in pairs(pages) do page:SetShown(tabId == id) end
    end
    local highlight = W.CreateButtonGroup(buttons, ShowTab)
    highlight(buttons[1])
    ShowTab(tabs[1].id)
end

local function BuildPanel()
    local cf = _G.CharacterFrame
    panel = CreateFrame("Frame", nil, cf)
    panel:SetPoint("TOPLEFT", cf, "TOPRIGHT", PANEL_GAP, 0)
    panel:SetPoint("BOTTOMLEFT", cf, "BOTTOMRIGHT", PANEL_GAP, 0)
    panel:SetWidth(PANEL_W)
    panel:SetFrameLevel((X.TargetLevel(cf) or 1) + PANEL_LEVEL)
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:Hide()
    X.Backdrop(panel, C.fill, C.border)

    local title = W.CreateSectionTitle(panel, "角色面板", PANEL_W - 32)
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -14)

    -- × 關閉鈕：同設定視窗（Options/Panel.lua 的 CreateCloseButton）
    local close = W.CreateButton(panel, "", "red", 20, 20)
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -3, -3)
    close:SetFrameLevel(panel:GetFrameLevel() + 10)
    local x = close:CreateTexture(nil, "OVERLAY")
    x:SetTexture("Interface\\Buttons\\UI-StopButton")
    x:SetSize(12, 12)
    x:SetPoint("CENTER")
    x:SetVertexColor(1, 0.85, 0.85)
    close:SetScript("OnClick", function() X.SetEditing(false) end)

    local built = false
    panel:SetScript("OnShow", function()
        if not built then
            built = true
            BuildContent()
        end
        RefreshAll()
        if X.Hud then X.Hud.UpdateDraggable() end
    end)
    panel:SetScript("OnHide", function()
        W.CloseDropdowns()
        if X.Hud then X.Hud.UpdateDraggable() end
    end)
end

------------------------------------------------------------
-- 齒輪
------------------------------------------------------------
local function PaintGear(hover)
    local lit = hover or X.IsEditing()
    local c = lit and C.text or C.textDim
    gear.icon:SetVertexColor(c[1], c[2], c[3], 1)
    gear:SetAlpha(lit and 1 or GEAR_IDLE)
end

-- 分頁列置中（見檔頭接觸面表的 PaperDollSidebarTabs 那列）。找不到容器或 InsetRight 就不動，
-- 齒輪照樣排在第四格——那時整列還是暴雪原本靠右的位置，只是沒置中。
local function CenterSidebarTabs()
    local host = _G.PaperDollSidebarTabs
    local inset
    pcall(function() inset = _G.CharacterFrame.InsetRight end)
    if not host or not inset then
        X.Missing(host and "CharacterFrame.InsetRight" or "PaperDollSidebarTabs")
        return
    end
    host:ClearAllPoints()
    host:SetPoint("BOTTOM", inset, "TOP", SIDEBAR_X, SIDEBAR_Y)
end

local function BuildGear(doll)
    local tab3 = _G.PaperDollSidebarTab3
    local inset
    if not tab3 then
        X.Missing("PaperDollSidebarTab3")
        pcall(function() inset = _G.CharacterFrame.InsetRight end)
        if not inset then
            X.Missing("CharacterFrame.InsetRight")
            return
        end
    end
    gear = CreateFrame("Button", nil, doll)
    gear:SetSize(GEAR_SIZE, GEAR_SIZE)
    if tab3 then
        gear:SetPoint("CENTER", tab3, "CENTER", GEAR_SLOT, 0)
    else
        gear:SetPoint("CENTER", inset, "TOPRIGHT", GEAR_FB_X, GEAR_FB_Y)
    end
    gear:SetFrameLevel((X.TargetLevel(doll) or 1) + 20)
    local icon = gear:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(GEAR_TEX)
    icon:SetAllPoints(gear)
    gear.icon = icon
    PaintGear(false)

    gear:SetScript("OnEnter", function(self)
        PaintGear(true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("角色面板設定", 1, 1, 1)
        GameTooltip:Show()
    end)
    gear:SetScript("OnLeave", function(self)
        PaintGear(false)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
    gear:SetScript("OnClick", function(self)
        -- 面板會從同一側展開，提示留著會蓋到它（project-miliui-hud-skin 的提示那條）
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
        X.SetEditing(not X.IsEditing())
    end)
end

------------------------------------------------------------
-- 進入點
------------------------------------------------------------
local function Build()
    local doll, cf = Doll(), _G.CharacterFrame
    if not doll or not cf then
        X.Missing("PaperDollFrame")
        return
    end
    CenterSidebarTabs()
    BuildGear(doll)
    BuildPanel()

    doll:HookScript("OnShow", SyncPanel)
    doll:HookScript("OnHide", SyncPanel)
    -- 角色面板整個關掉 ＝ 編輯結束（下次打開是一般的清單）
    cf:HookScript("OnHide", function() X.SetEditing(false) end)

    X.OnEditChanged(function()
        SyncPanel()
        if gear then PaintGear(gear:IsMouseOver()) end
    end)
end

-- 齒輪不看任何開關（面板裡的 HUD 分頁在清單關掉時也有用）；模組有載入就建
X.Register(nil, Build)
