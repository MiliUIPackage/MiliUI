------------------------------------------------------------
-- 「專注目標施法」頁（profile.focuscast；引擎在 Modules/FocusCastbar.lua）
--
-- 控件照施法條頁改：沒有引導刻度／延遲／蓄力／隱藏暴雪條（那些是玩家自己的事），
-- 多了三態顏色（可斷法：斷法就緒／斷法冷卻中、不可中斷）、重要法術（發光＋「!」）、被打斷時印斷法者。
-- 頁首一顆「預覽」：跑一條十秒的假施法（當重要法術），再按一次停。「材質」上方另有一條內嵌的樣本條＋六顆狀態按鈕（SampleRow）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local Options = ns.Options

ns.TabFocusCast = {}
local Tab = ns.TabFocusCast

local KEY = "focuscast"
local FORM_W = Options.PAGE_W - 6

local function Cfg() return ns.DB.ConfigTable(KEY) end

local function BS(kind, path, label, extra)
    local s = { type = kind, root = "bar", path = path, key = path, label = label }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local function Note(label) return { type = "text", label = label } end

local FILL_ITEMS = {
    { text = L["Left to right"], value = "ltr" },
    { text = L["Right to left"], value = "rtl" },
}

local SIDE_ITEMS = {
    { text = L["Left"],  value = "LEFT" },
    { text = L["Right"], value = "RIGHT" },
}

local TIME_ITEMS = {
    { text = L["Remaining / total (0.3/1.5)"], value = "remainTotal" },
    { text = L["Elapsed / total (1.2/1.5)"],   value = "elapsedTotal" },
    { text = L["Remaining (0.3)"],             value = "remain" },
    { text = L["Elapsed (1.2)"],               value = "elapsed" },
}

local GLOW_ITEMS = {
    { text = L["Pixel lines (bar border)"],       value = "pixel" },
    { text = L["Autocast sparkles (bar border)"], value = "autocast" },
    { text = L["Proc glow (icon)"],               value = "proc" },
}

-- 材質：多一項「暴雪施法條」（同施法條頁）
local function TextureItems()
    local items = ns.Specs.TextureItems()
    return ns.Specs.InsertAfterSolid(items, { text = L["Blizzard cast bar"], value = ns.Castbar.BLIZZARD_TEXTURE })
end

-- 樣本條（引擎的 ns.FocusCastbar.CreateSample）：放在「材質」正上方，一條自己循環填滿的假施法條，零件、版面、上色、發光、
-- 「!」、打斷畫面都是畫面上那條用的同一批函式（見引擎那邊的說明）——所以它同時是「樣式有沒有套對」的檢查。
-- 底下兩排按鈕挑假施法的狀態（選中＝primary）：
--   第一排四選一    斷法就緒／斷法冷卻中／不可中斷／已打斷
--   第二排各自開關  這個法術算不算重要法術——發光、「!」各一顆。那兩樣在設定裡關著時實際不會出現，樣本也不畫，
--                   按鈕壓暗提示（照樣能按）
-- 表單引擎在值變了之後只叫 ctx.apply、不叫 refreshers ⇒ 包一層 ctx.apply 讓樣本跟著換（同 Specs 的發光預覽）。
-- 列高在建表單時定：標籤對著樣本條置中，條下方留一行給「法術打向誰」，按鈕照各語系的字寬排、放不下自己換排
local SAMPLE_BAR_ZONE = ns.FocusCastbar.SAMPLE_MAX_H + 12
local SAMPLE_TARGET_H = 14
local SAMPLE_BTN_H, SAMPLE_GAP = 20, 4
local SAMPLE_STATES = {
    { "ready",       L["Kick ready"] },
    { "cd",          L["Kick on CD"] },
    { "immune",      L["Not interruptible"] },
    { "interrupted", L["Interrupted"] },
}
local SAMPLE_MARKS = {
    { "glowOn", L["Important spell: glow"],    "glowImportant" },
    { "bangOn", L["Important spell: \"!\""], "bangImportant" },
}

local function SampleRow()
    return { type = "custom", label = L["Preview"], h = SAMPLE_BAR_ZONE, noReset = true,
        build = function(parent, x, y, width, ctx)
            local s = ns.FocusCastbar.CreateSample(parent)
            s:SetPoint("LEFT", parent, "TOPLEFT", x, y - SAMPLE_BAR_ZONE / 2)
            local stateBtns, markBtns = {}, {}
            local function PaintButtons()
                local cfg = Cfg() or {}
                for _, b in ipairs(stateBtns) do
                    W.SetButtonVariant(b, s.state == b.key and "primary" or "normal")
                end
                for _, b in ipairs(markBtns) do
                    W.SetButtonVariant(b, s[b.key] and "primary" or "normal")
                    b:SetAlpha(cfg[b.setting] and 1 or 0.45)
                end
            end
            local function ButtonRow(defs, list, top, onClick)
                local holder = CreateFrame("Frame", nil, parent)
                holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - top)
                for _, def in ipairs(defs) do
                    local b = W.CreateButton(holder, def[2], "normal", 60, SAMPLE_BTN_H)
                    W.FitButton(b, 60, SAMPLE_BTN_H)
                    b.key, b.setting = def[1], def[3]
                    b:SetScript("OnClick", function()
                        onClick(b)
                        s:Paint()
                        PaintButtons()
                    end)
                    list[#list + 1] = b
                end
                local _, h = W.FlowLayout(holder, list, width, SAMPLE_GAP, SAMPLE_GAP, SAMPLE_BTN_H)
                holder:SetSize(width, h)
                return h
            end
            local top = SAMPLE_BAR_ZONE + SAMPLE_TARGET_H
            local h1 = ButtonRow(SAMPLE_STATES, stateBtns, top, function(b) s.state = b.key end)
            local h2 = ButtonRow(SAMPLE_MARKS, markBtns, top + h1 + SAMPLE_GAP, function(b) s[b.key] = not s[b.key] end)
            local function Refresh()
                s:Refresh(width)
                PaintButtons()
            end
            local apply = ctx.apply
            ctx.apply = function(...)
                apply(...)
                Refresh()
            end
            return top + h1 + SAMPLE_GAP + h2 + 8, Refresh
        end }
end

local function ResetAll()
    local cfg = Cfg()
    if not cfg then return end
    for k in pairs(cfg) do cfg[k] = nil end
    ns.DB.MergeDefaults(cfg, ns.DB.BuildDefaults().profile.focuscast)
end

local function Controls()
    local list = {
        BS("toggle", "enabled", L["Show the focus cast bar"]),
        Note(L["Shows what your focus target is casting and colors the bar by whether you can interrupt it."]),
        { type = "header", label = L["Layout"] },
        BS("slider", "width", L["Width"], { min = 0, max = 600, step = 1 }),
        Note(L["0 matches the first row of the icon group it follows; otherwise Essential Cooldowns (icon included)."]),
        BS("slider", "height", L["Height"], { min = 6, max = 60, step = 1 }),
        SampleRow(),
        BS("dropdown", "texture", L["Texture"], { items = TextureItems }),
        Note(L["Blizzard cast bar: the gradient look of the game's own cast bar, tinted with the colors below."]),
        BS("color", "bgColor", L["Background color"]),
        BS("dropdown", "fillDirection", L["Fill direction"], { items = FILL_ITEMS }),
        -- 邊緣陰影（Core/Shape.lua 的 SH.EdgeShadow）：條身與每顆圖示各一圈
        BS("toggle", "shadow", L["Shadow"], { refreshPage = true }),
        BS("slider", "shadowSize", L["Shadow size"], { min = 1, max = 8, step = 1,
            disabled = function() local c = Cfg(); return not (c and c.shadow) end }),
        BS("slider", "shadowAlpha", L["Shadow opacity"], { min = 10, max = 100, step = 5, scale = 100,
            disabled = function() local c = Cfg(); return not (c and c.shadow) end }),
        Note(L["The shadow is drawn outside the bar and each of its icons, one ring each."]),
        { type = "header", label = L["Colors"] },
        BS("color", "colors.ready", L["Interruptible (kick ready)"], { hasAlpha = false }),
        BS("color", "colors.cd", L["Interruptible (kick on CD)"], { hasAlpha = false }),
        BS("color", "colors.immune", L["Not interruptible"], { hasAlpha = false }),
        BS("color", "colors.interrupted", L["Interrupted"], { hasAlpha = false }),
        Note(L["Kick ready follows your own interrupt's cooldown. A non-interruptible cast always shows that color."]),
        { type = "header", label = L["Important spells"] },
        BS("toggle", "glowImportant", L["Glow when the focus casts an important spell"]),
        BS("toggle", "bangImportant", L["Add \"!\" before important spell names"]),
        Note(L["Blizzard decides which spells count as important."]),
        BS("dropdown", "glowStyle", L["Glow style"], { items = GLOW_ITEMS }),
        BS("color", "colors.glow", L["Glow color"], { hasAlpha = false }),
        { type = "header", label = L["Icon"] },
        BS("toggle", "showIcon", L["Show icon"]),
        BS("dropdown", "iconSide", L["Icon position"], { items = SIDE_ITEMS }),
        BS("slider", "iconGap", L["Icon gap"], { min = 0, max = 10, step = 1 }),
        BS("toggle", "showKick", L["Show your interrupt at the end of the bar"]),
        Note(L["Your interrupt's icon sits at the far end with its cooldown sweep: bright when ready, dim while on cooldown. Hidden when this specialization has no interrupt."]),
        { type = "header", label = L["Text"] },
        BS("toggle", "showName", L["Show spell name"]),
        BS("toggle", "showCaster", L["Show the caster's name before the spell"]),
        BS("slider", "nameMaxChars", L["Max characters"], { min = 0, max = 40, step = 1 }),
        Note(L["0 shows the whole name."]),
        BS("dropdown", "font", L["Name font"], { items = ns.Specs.ElementFontItems,
            get = function() local c = Cfg(); return ns.Specs.InheritOr(c and c.font) end }),
        BS("slider", "textSize", L["Name size"], { min = 6, max = 30, step = 1 }),
        BS("numbers", nil, L["Name offset"], { sub = "nameOffset", path = false, resetPaths = { "nameOffset" },
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }),
        BS("toggle", "showTime", L["Show time"]),
        BS("dropdown", "timeFormat", L["Time format"], { items = TIME_ITEMS }),
        BS("dropdown", "timeFont", L["Time font"], { items = ns.Specs.ElementFontItems,
            get = function() local c = Cfg(); return ns.Specs.InheritOr(c and c.timeFont) end }),
        BS("slider", "timeTextSize", L["Time size"], { min = 6, max = 30, step = 1 }),
        BS("numbers", nil, L["Time offset"], { sub = "timeOffset", path = false, resetPaths = { "timeOffset" },
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }),
        BS("toggle", "showTarget", L["Show who the spell is aimed at"]),
        Note(L["The spell's target sits under the bar's right edge, smaller than the spell name, in the target's class color."]),
        BS("toggle", "targetClassColor", L["Color the target's name by class"]),
        BS("slider", "targetTextSize", L["Target size"], { min = 6, max = 30, step = 1 }),
        BS("numbers", nil, L["Target offset"], { sub = "targetOffset", path = false, resetPaths = { "targetOffset" },
            fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }),
        { type = "header", label = L["Effects"] },
        BS("toggle", "showSpark", L["Spark at the leading edge"]),
        BS("toggle", "showInterrupter", L["Show who interrupted it"]),
        Note(L["When the cast is interrupted, the bar turns red and shows the interrupter's name in class color for a second."]),
        { type = "header", label = L["Visibility"] },
        BS("toggle", "hideWhenNotCasting", L["Hide when not casting"]),
        Note(L["Unchecked, an empty bar stays on screen. Edit Mode always shows it."]),
    }
    for _, s in ipairs(ns.Specs.Anchor(KEY)) do list[#list + 1] = s end
    list[#list + 1] = { type = "header", label = L["Reset"] }
    list[#list + 1] = { type = "custom", label = L["Restore defaults"], h = 30, noReset = true,
        build = function(parent, x, y, width, ctx)
            local b = W.CreateButton(parent, L["Restore focus cast bar defaults"], "red", 180, 22)
            W.FitButton(b, 180, 22)
            b:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
            local popup
            b:SetScript("OnClick", function()
                if not popup then
                    popup = W.CreateConfirmPopup(Options.panel, 320, L["Restore the focus cast bar settings to their defaults?"], function()
                        ResetAll()
                        ctx.lastSpec = { refreshPage = true }
                        ctx.apply()
                    end)
                end
                popup:Show()
            end)
            return 30
        end }
    return list
end

local function Signature()
    local cfg = Cfg() or {}
    local p = ns.profile
    return table.concat({
        type(cfg.anchor) == "table" and "a" or "-",
        table.concat(p and p.barOrder or {}, ","),
        ns.Specs.AnchorGraphSig(),
    }, "|")
end

function Tab.Build(parent, title)
    local page, y = Options.NewPage(parent, title)
    local pad = Options.PAGE_PAD

    -- 預覽：跑一條十秒的假施法（專注目標真的開唱就讓位）
    local preview = W.CreateButton(page, L["Preview"], "normal", 100, 22)
    W.FitButton(preview, 100, 22)
    preview:SetPoint("TOPLEFT", page, "TOPLEFT", pad, y)
    local function PreviewText()
        preview:SetText(ns.FocusCastbar.IsPreviewing() and L["Stop preview"] or L["Preview"])
        W.FitButton(preview, 100, 22)
    end
    preview:SetScript("OnClick", function()
        if ns.FocusCastbar.IsPreviewing() then
            ns.FocusCastbar.StopPreview()
        elseif not ns.FocusCastbar.StartPreview() then
            ns.Print(L["The focus cast bar is off or your focus is casting right now."])
        end
        PreviewText()
    end)
    ns.RegisterCallback("FocusCastPreview", "tab_focuscast", PreviewText)
    y = y - 22 - 8

    local holder = CreateFrame("Frame", nil, page)
    holder:SetPoint("TOPLEFT", page, "TOPLEFT", pad - 2, y)
    holder:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 10)
    local scroll = W.CreateScrollFrame(holder)
    page.scroll = scroll
    local forms = {}

    local function OnApply(spec)
        ns.FocusCastbar.Apply()
        if ns.EditMode and ns.EditMode.Editing() and ns.EditMode.RequestRefresh then ns.EditMode.RequestRefresh() end
        if ns.Fire then ns.Fire("BarsListChanged") end
        ns.Defer(function()
            if page:IsVisible() and (page.sig ~= Signature() or (spec and spec.refreshPage)) then
                page:RefreshForm()
            end
        end)
    end

    function page:RefreshForm()
        if not Cfg() then return end
        local sig = Signature()
        local form = forms[sig]
        if not form then
            local ctx = ns.Specs.MakeCtx({ mode = "panel", key = KEY }, OnApply)
            form = ns.Specs.BuildForm(scroll.child, Controls(), ctx, FORM_W)
            forms[sig] = form
        end
        for _, fm in pairs(forms) do fm.content:SetShown(fm == form) end
        local keep = self.form and scroll:GetVerticalScroll() or 0
        if self.form ~= form and not self.form then scroll:SetVerticalScroll(0) end
        self.form, self.sig = form, sig
        scroll:SetContentHeight(form.height)
        if keep > 0 then
            local maxScroll = math.max(0, form.height - (scroll:GetHeight() or 0))
            scroll:SetVerticalScroll(math.min(keep, maxScroll))
        end
        form:Refresh()
    end

    function page:OnShowPage()
        PreviewText()
        self:RefreshForm()
    end

    page:HookScript("OnHide", function() ns.FocusCastbar.StopPreview() end)
    return page
end

Options.RegisterPage(KEY, L["Focus Cast Bar"], Tab.Build)

-- 編輯模式拖完（拖了就脫離錨定）、錨定視窗改了值：錨定那一節重讀
local function RefreshMoved(key)
    if key ~= KEY then return end
    local page = Options.GetPage(KEY)
    if page and page:IsVisible() and page.RefreshForm then ns.Defer(function() page:RefreshForm() end) end
end
ns.RegisterCallback("BarMoved", "tab_focuscast", RefreshMoved)
ns.RegisterCallback("AnchorChanged", "tab_focuscast", RefreshMoved)
