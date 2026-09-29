------------------------------------------------------------
-- 「施法條」頁（profile.castbar；引擎在 Modules/Castbar.lua）
--
-- 控件照單位框架的施法條設定改（單位固定是自己，所以沒有施法目標、斷法者、重要法術），
-- 多了引導刻度、延遲條、蓄力四階顏色、隱藏暴雪施法條、「錨定」一節（Specs.Anchor；key ＝ "castbar"）。
-- 頁首一顆「預覽」：跑一條十秒的假施法，再按一次停。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local Options = ns.Options

ns.TabCastbar = {}
local Tab = ns.TabCastbar

local KEY = "castbar"
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

local function ResetAll()
    local cfg = Cfg()
    if not cfg then return end
    for k in pairs(cfg) do cfg[k] = nil end
    ns.DB.MergeDefaults(cfg, ns.DB.BuildDefaults().profile.castbar)
end

local function Controls()
    local list = {
        BS("toggle", "enabled", L["Show the cast bar"]),
        BS("toggle", "hideBlizzard", L["Hide Blizzard's player cast bar"]),
        Note(L["Only stops Blizzard's bar from listening to your casts; unchecking brings it right back, unless the unit frames are hiding it too."]),
        { type = "header", label = L["Layout"] },
        BS("slider", "width", L["Width"], { min = 0, max = 600, step = 1 }),
        Note(L["0 matches the first row of Essential Cooldowns (icon included)."]),
        BS("slider", "height", L["Height"], { min = 6, max = 60, step = 1 }),
        BS("dropdown", "texture", L["Texture"], { items = ns.Specs.TextureItems }),
        BS("color", "bgColor", L["Background color"]),
        BS("dropdown", "fillDirection", L["Fill direction"], { items = FILL_ITEMS }),
        { type = "header", label = L["Colors"] },
        BS("toggle", "useClassColor", L["Use the class color for the fill"]),
        Note(L["One color for casting and channeling alike. Empowered stages, non-interruptible and interrupt-ready still apply on top."]),
        BS("color", "colors.cast", L["Casting"], { hasAlpha = false }),
        BS("color", "colors.channel", L["Channeling"], { hasAlpha = false }),
        BS("color", "colors.uninterruptible", L["Non-interruptible"], { hasAlpha = false }),
        BS("color", "colors.interrupted", L["Interrupted or failed"], { hasAlpha = false }),
        BS("color", "colors.empowerStage1", L["Empowered stage %d"]:format(1), { hasAlpha = false }),
        BS("color", "colors.empowerStage2", L["Empowered stage %d"]:format(2), { hasAlpha = false }),
        BS("color", "colors.empowerStage3", L["Empowered stage %d"]:format(3), { hasAlpha = false }),
        BS("color", "colors.empowerStage4", L["Empowered stage %d"]:format(4), { hasAlpha = false }),
        Note(L["An empowered cast takes the color of the stage it would release at right now."]),
        BS("toggle", "interruptReady", L["Tint while your interrupt is ready"]),
        BS("color", "colors.interruptReady", L["Interrupt-ready color"], { hasAlpha = false }),
        Note(L["Tints the bar while your own interrupt is off cooldown. A non-interruptible cast still wins."]),
        { type = "header", label = L["Icon"] },
        BS("toggle", "showIcon", L["Show icon"]),
        BS("dropdown", "iconSide", L["Icon position"], { items = SIDE_ITEMS }),
        BS("slider", "iconGap", L["Icon gap"], { min = 0, max = 10, step = 1 }),
        { type = "header", label = L["Text"] },
        BS("toggle", "showName", L["Show spell name"]),
        BS("slider", "nameMaxChars", L["Max characters"], { min = 0, max = 40, step = 1 }),
        Note(L["0 shows the whole name."]),
        BS("toggle", "showTime", L["Show time"]),
        BS("dropdown", "timeFormat", L["Time format"], { items = TIME_ITEMS }),
        BS("slider", "textSize", L["Font size"], { min = 6, max = 30, step = 1 }),
        { type = "header", label = L["Effects"] },
        BS("toggle", "showSpark", L["Spark at the leading edge"]),
        BS("toggle", "ticks", L["Channel ticks"]),
        Note(L["Marks each tick of a channeled spell (fixed tick counts for known spells)."]),
        BS("toggle", "latency", L["Latency"]),
        Note(L["Shades the end of the bar by your latency: releasing the next cast inside it is safe."]),
        Note(L["Ticks, latency and empowered stages need readable cast times; in restricted content they may not show while the bar keeps moving."]),
        { type = "header", label = L["Visibility"] },
        BS("toggle", "hideWhenNotCasting", L["Hide when not casting"]),
        Note(L["Unchecked, an empty bar stays on screen. Edit Mode always shows it."]),
    }
    for _, s in ipairs(ns.Specs.Anchor(KEY)) do list[#list + 1] = s end
    list[#list + 1] = { type = "header", label = L["Reset"] }
    list[#list + 1] = { type = "custom", label = L["Restore defaults"], h = 30, noReset = true,
        build = function(parent, x, y, width, ctx)
            local b = W.CreateButton(parent, L["Restore cast bar defaults"], "red", 180, 22)
            W.FitButton(b, 180, 22)
            b:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
            local popup
            b:SetScript("OnClick", function()
                if not popup then
                    popup = W.CreateConfirmPopup(Options.panel, 320, L["Restore the cast bar settings to their defaults?"], function()
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

    -- 預覽：跑一條十秒的假施法（真的施法一開始就讓位）
    local preview = W.CreateButton(page, L["Preview"], "normal", 100, 22)
    W.FitButton(preview, 100, 22)
    preview:SetPoint("TOPLEFT", page, "TOPLEFT", pad, y)
    local function PreviewText()
        preview:SetText(ns.Castbar.IsPreviewing() and L["Stop preview"] or L["Preview"])
        W.FitButton(preview, 100, 22)
    end
    preview:SetScript("OnClick", function()
        if ns.Castbar.IsPreviewing() then
            ns.Castbar.StopPreview()
        elseif not ns.Castbar.StartPreview() then
            ns.Print(L["The cast bar is off or you're casting right now."])
        end
        PreviewText()
    end)
    ns.RegisterCallback("CastbarPreview", "tab_castbar", PreviewText)
    y = y - 22 - 8

    local holder = CreateFrame("Frame", nil, page)
    holder:SetPoint("TOPLEFT", page, "TOPLEFT", pad - 2, y)
    holder:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 10)
    local scroll = W.CreateScrollFrame(holder)
    page.scroll = scroll
    local forms = {}

    local function OnApply(spec)
        ns.Castbar.Apply()
        if ns.EditMode and ns.EditMode.active and ns.EditMode.RequestRefresh then ns.EditMode.RequestRefresh() end
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
        if self.form ~= form then scroll:SetVerticalScroll(0) end
        self.form, self.sig = form, sig
        scroll:SetContentHeight(form.height)
        form:Refresh()
    end

    function page:OnShowPage()
        PreviewText()
        self:RefreshForm()
    end

    -- 離開這一頁或關掉視窗：預覽收掉（不要留一條假施法在畫面上）
    page:HookScript("OnHide", function() ns.Castbar.StopPreview() end)
    return page
end

Options.RegisterPage(KEY, Options.PageTitle(KEY), Tab.Build)

ns.RegisterCallback("BarMoved", "tab_castbar", function(key)
    if key ~= KEY then return end
    local page = Options.GetPage(KEY)
    if page and page:IsVisible() and page.RefreshForm then ns.Defer(function() page:RefreshForm() end) end
end)
