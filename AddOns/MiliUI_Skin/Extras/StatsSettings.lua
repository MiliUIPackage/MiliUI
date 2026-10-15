------------------------------------------------------------
-- 自建功能：角色面板右上角的齒輪 ＋ 角色面板右側的「這一頁的設定」面板
--
-- 齒輪點一下 ＝ 切換屬性清單的**編輯狀態**（`X.SetEditing`，Common.lua）：
--   面板開著 ＝ 編輯狀態 on；關掉（× 鈕、再點齒輪、關角色面板）＝ off。狀態不存檔。
--   編輯狀態裡清單可以拖曳排序、每列勾選顯示、每區換色（CharacterStats.lua）；
--   畫面上的屬性顯示（StatsHud.lua）這時也可以拖。
-- 面板的顯示條件 ＝ 編輯狀態 on 而且 `PaperDollFrame` 顯示中 —— 切到聲望／通貨頁時面板
-- 收起來、切回來再出現；角色面板整個關掉就把編輯狀態關掉。
--
-- 面板的內容延到第一次打開才建。版面是這支自己的「直排表單」（標籤一行、控件一行；
-- 勾選框的名字在框的右邊），**不走** `Controls.Build`：共用層的表單是「左欄標籤 ＋
-- 右欄控件」，標籤欄寬是宿主層級的常數（這包 `Env.LABEL_W = 170`，給 /mskin 的長英文
-- 標籤用），320 寬的側邊面板扣掉它只剩不到 100 給控件，滑桿與下拉都塞不下。
-- 控件本身照樣是共用層的（W.CreateCheckButton／CreateSlider／CreateDropdown／
-- CreateColorPicker／CreateButton／CreateScrollFrame／CreateSectionTitle）。
-- 說明一律是控件下一列的灰字（feedback-options-toggle-description）。
--
-- 總開關關掉就不建（X.Register 的 key `statsSettings` 不在 `db.extras` 裡 ⇒ 只看總開關）。
--
------------------------------------------------------------
-- ## 對暴雪物件的接觸面
--
-- | 物件 | 動作 |
-- |---|---|
-- | PaperDollFrame | 齒輪的 parent（跟著角色分頁顯隱）；`HookScript("OnShow"/"OnHide")` 同步面板顯隱；讀 `IsShown()` |
-- | CharacterFrame.InsetRight | 齒輪的錨點；讀 parentKey（pcall 包著，結構查詢） |
-- | CharacterFrame | 面板的 parent ＋ 錨點（右緣外側）；`GetFrameLevel()`（`Engine.TargetLevel`）—— 面板層級 ＝ 它 +30、齒輪 ＝ PaperDollFrame +20；`HookScript("OnHide")` 關編輯狀態 |
-- | GameTooltip | 齒輪的提示（SetOwner／SetText／Show／Hide） |
-- | ColorPickerFrame | 色票走共用層 `W.CreateColorPicker` |
--
-- 寫入暴雪欄位：無。hook：只有上面三個 HookScript（後置、只改自己的框與狀態）。
-- 面板是 CharacterFrame 的子框 ⇒ ESC 關角色面板時跟著關，不另外登記 UISpecialFrames。
-- 戰鬥：面板、齒輪、編輯狀態全是自己的框，戰鬥中開關都合法；把它們掛到暴雪框底下那一步
-- 在建立時做（X.Boot 已經把戰鬥中的建立延到脫戰）。
------------------------------------------------------------
local _, ns = ...

local X = ns.Extras
local E = ns.Engine
local T = ns.Tokens
local S = ns.Secret
local P = ns.P
local W = ns.W
local L = ns.L

-- 齒輪：錨 InsetRight 的右上角往左、往上（裝備分頁右邊那塊空位；實機再微調）
local GEAR_SIZE   = 14
local GEAR_X      = -20
local GEAR_Y      = 16
local GEAR_IDLE   = 0.45
local GEAR_TEX    = "Interface\\AddOns\\MiliUI_Skin\\Media\\icon-settings.png"

local PANEL_W     = 320
local PANEL_GAP   = 4      -- 面板與角色面板右緣之間
local PANEL_LEVEL = 30     -- 高過 CharacterFrame 的子孫（要蓋住別的插件掛在右側的裝備清單）
local FORM_W      = PANEL_W - 12 - 8 - 20 - 4   -- 內距 12／8、捲軸 20、右邊再留 4

local panel, gear
local refreshers = {}

local function EX() return ns.db.extras end
local function HDB() return ns.db.extras.hud end

local function RefreshAll()
    for _, fn in ipairs(refreshers) do fn() end
end

-- 設定面板開著沒（畫面上的屬性顯示用它判斷可不可以拖）
function X.SettingsShown()
    return panel ~= nil and panel:IsVisible()
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

-- 「預設配色」：MiliUI ＝ 清掉覆寫（回 Tokens 的五色）；職業色 ＝ 五區全部寫成職業色
local function ApplyPalette(v)
    local ex = EX()
    ex.statsPalette = v
    ex.statsColors = {}
    if v == "class" then
        local r, g, b = T.Accent()
        for _, k in ipairs(SECTION_KEYS) do ex.statsColors[k] = { r, g, b } end
    end
    X.NotifyStatsChanged("colors")
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
    local ctx = X.BuildStatContext()
    local items = {}
    for i, st in ipairs(stats) do
        local def = X.StatDefs[st.def]
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

local function Specs()
    return {
        { type = "header", label = L["Stat list"] },
        {
            type = "dropdown", label = L["Show values"],
            items = X.ValueFormatItems(),
            get = function() return X.ValueFormat(EX().statsValueFormat) end,
            set = function(v) EX().statsValueFormat = v; X.NotifyStatsChanged("rating") end,
        },
        {
            type = "dropdown", label = L["Default colors"],
            items = {
                { text = L["MiliUI"], value = "miliui" },
                { text = L["Class color"], value = "class" },
            },
            get = function() return EX().statsPalette or "miliui" end,
            set = ApplyPalette,
        },
        {
            type = "buttons",
            buttons = {
                { text = L["Reset colors"], onClick = function() ApplyPalette("miliui") end },
                { text = L["Reset order and visibility"], onClick = function()
                    local ex = EX()
                    ex.statsOrder, ex.statsCollapsed, ex.statsHidden = {}, {}, {}
                    X.NotifyStatsChanged("order")
                end },
            },
        },
        { type = "text", label = L["While this panel is open: drag a section title to reorder, the checkbox in front of each row decides whether it shows, and the swatch at the right end of a section title changes its color."] },

        { type = "header", label = L["On-screen stats"] },
        HudSpec("enabled", "toggle", L["Show stats on screen"]),
        { type = "text", indent = true, label = L["Can be dragged while this panel or Blizzard's Edit Mode is open."] },
        { type = "custom", build = BuildHudStats },
        HudSpec("labelStyle", "dropdown", L["Labels"], { items = {
            { text = L["Full"], value = "full" },
            { text = L["Abbreviated"], value = "short" },
            { text = L["Don't show"], value = "none" },
        } }),
        HudSpec("valueFormat", "dropdown", L["Show values"], { items = X.ValueFormatItems() }),
        { type = "text", label = L["Primary stat, Stamina, power and Armor have no percentage: they always show a whole number."] },
        HudSpec("percentSign", "toggle", L["Show percent sign"]),
        HudSpec("colorMode", "dropdown", L["Label color"], { items = {
            { text = L["Section colors"], value = "section" },
            { text = L["Class color"], value = "class" },
            { text = L["Custom"], value = "custom" },
        } }),
        HudSpec("valueColored", "toggle", L["Values use the label color"]),
        HudSpec("fontSize", "slider", L["Font size"], { min = 8, max = 24, step = 1 }),
        HudSpec("outline", "dropdown", L["Outline"], { items = {
            { text = L["None"], value = "" },
            { text = L["Outline"], value = "OUTLINE" },
            { text = L["Thick outline"], value = "THICKOUTLINE" },
            -- 單色＝關掉反鋸齒：像素字體用（MiliUI_AuraEnhance 的 OUTLINE_ITEMS 同一組）
            { text = L["Monochrome outline"], value = "MONOCHROME,OUTLINE" },
            { text = L["Monochrome thick outline"], value = "MONOCHROME,THICKOUTLINE" },
        } }),
        HudSpec("shadow", "toggle", L["Text shadow"]),
        HudSpec("scale", "slider", L["Scale"], { min = 0.6, max = 2, step = 0.05 }),
        HudSpec("backdrop", "toggle", L["Background"]),
        HudSpec("when", "dropdown", L["When to show"], { items = {
            { text = L["Always"], value = "always" },
            { text = L["In combat only"], value = "combat" },
            { text = L["In instances only"], value = "instance" },
        } }),
        {
            type = "buttons",
            buttons = {
                { text = L["Reset position"], onClick = function() if X.Hud then X.Hud.ResetPosition() end end },
            },
        },

        { type = "header", label = L["Other"] },
        { type = "text", label = L["The custom stat list and title search switches are in the \"Character Sheet\" tab of /mskin."] },
    }
end

------------------------------------------------------------
-- 面板
------------------------------------------------------------
local function BuildContent()
    local holder = CreateFrame("Frame", nil, panel)
    holder:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -44)
    holder:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -8, 10)
    local scroll = W.CreateScrollFrame(holder)
    local content = CreateFrame("Frame", nil, scroll.child)
    content:SetPoint("TOPLEFT", scroll.child, "TOPLEFT", 4, -4)
    content:SetSize(FORM_W, 1)
    local h = BuildForm(content, Specs(), FORM_W)
    content:SetHeight(h + 8)
    scroll:SetContentHeight(h + 16)
end

local function BuildPanel()
    local cf = _G.CharacterFrame
    panel = CreateFrame("Frame", nil, cf)
    panel:SetPoint("TOPLEFT", cf, "TOPRIGHT", PANEL_GAP, 0)
    panel:SetPoint("BOTTOMLEFT", cf, "BOTTOMRIGHT", PANEL_GAP, 0)
    panel:SetWidth(PANEL_W)
    panel:SetFrameLevel((E.TargetLevel(cf) or 1) + PANEL_LEVEL)
    panel:EnableMouse(true)
    panel:EnableMouseWheel(true)
    panel:Hide()
    X.Backdrop(panel, T.fill, T.border)

    local title = W.CreateSectionTitle(panel, L["Character Sheet"], PANEL_W - 32)
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
    local c = lit and T.text or T.textDim
    gear.icon:SetVertexColor(c[1], c[2], c[3], 1)
    gear:SetAlpha(lit and 1 or GEAR_IDLE)
end

local function BuildGear(doll)
    local inset
    pcall(function() inset = _G.CharacterFrame.InsetRight end)
    if not inset then
        E.Missing("CharacterFrame.InsetRight")
        return
    end
    gear = CreateFrame("Button", nil, doll)
    gear:SetSize(GEAR_SIZE, GEAR_SIZE)
    gear:SetPoint("TOPRIGHT", inset, "TOPRIGHT", GEAR_X, GEAR_Y)
    gear:SetFrameLevel((E.TargetLevel(doll) or 1) + 20)
    local icon = gear:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(GEAR_TEX)
    icon:SetAllPoints(gear)
    gear.icon = icon
    PaintGear(false)

    gear:SetScript("OnEnter", function(self)
        PaintGear(true)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Character sheet settings"], 1, 1, 1)
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
        E.Missing("PaperDollFrame")
        return
    end
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

X.Register("statsSettings", Build)
