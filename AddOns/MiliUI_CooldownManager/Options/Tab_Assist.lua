------------------------------------------------------------
-- 「戰鬥輔助」頁：下一招醒目標示（theme.assist，Core/Assist.lua）＋下一招圖示（profile.assistIcon，
-- Modules/AssistIcon.lua；面板 key "assistIcon"，Options.HostPage 把它轉到這一頁）
--
-- 一張表單讀寫兩處：醒目標示是主題層的欄位（root "theme"），圖示是面板自己的表（root "bar"）。
-- ctx 用 mode "theme"＋key "assistIcon"：root "theme" 直接讀寫 profile.theme（跟主題頁同一條路，
-- 右鍵重設回主題預設），root "bar" 走 DB.ConfigTable("assistIcon")（右鍵重設回面板預設）。
-- 頁名、選項名用暴雪自己的字（ASSISTED_COMBAT_LABEL／ASSISTED_COMBAT_HIGHLIGHT_LABEL 的各語系值）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local Options = ns.Options

ns.TabAssist = {}
local Tab = ns.TabAssist

local PAGE = "assist"
local KEY = "assistIcon"
local FORM_W = Options.PAGE_W - 6

local function Cfg() return ns.DB.ConfigTable(KEY) end

local function TS(kind, path, label, extra)
    local s = { type = kind, root = "theme", path = path, key = path, label = label }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local function BS(kind, path, label, extra)
    local s = { type = kind, root = "bar", path = path, key = path, label = label }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local function Note(label) return { type = "text", label = label } end

local function Available() return ns.Assist and ns.Assist.Available() or false end

-- 暴雪選項的名字（遊戲自己的字串；這個客戶端沒有就用我們的翻譯）
local function HighlightOptionName()
    local s = _G.ASSISTED_COMBAT_HIGHLIGHT_LABEL
    return (type(s) == "string" and s ~= "") and s or L["Assisted Highlight"]
end

local function ResetAll()
    local p = ns.profile
    if not p then return end
    local d = ns.DB.BuildDefaults().profile
    local cfg = Cfg()
    if cfg then
        for k in pairs(cfg) do cfg[k] = nil end
        ns.DB.MergeDefaults(cfg, d.assistIcon)
    end
    p.theme.assist = d.theme.assist
end

local function Controls()
    local list = {}
    local function add(s) list[#list + 1] = s end
    if not Available() then
        add(Note(L["The Combat Assistant isn't available in this version of the game, so nothing on this page has any effect."]))
    end
    add(Note(L["Nothing showing up? Turn on \"%s\" in the game's options."]:format(HighlightOptionName())))

    add({ type = "header", label = L["Next cast highlight"] })
    add(TS("toggle", "assist.highlight", L["Highlight the suggested spell"]))
    add(Note(L["Glows on the spell the Combat Assistant suggests casting next, wherever it sits on your bars (Blizzard's abilities and your own custom spells). Buffs never glow."]))
    add(TS("dropdown", "assist.type", L["Style"], { items = ns.Specs.GLOW_ITEMS }))
    add(TS("color", "assist.color", L["Color"]))
    add(ns.Specs.GlowSampleRow("assist", "assist"))

    add({ type = "header", label = L["Next cast icon"] })
    add(BS("toggle", "enabled", L["Show the next cast icon"]))
    add(Note(L["A separate icon showing the suggested spell, its keybind and the global cooldown. Display only, it can't be clicked. Drag it in Edit Mode."]))
    add(BS("slider", "size", L["Icon size"], { min = 16, max = 128, step = 1 }))
    add(BS("toggle", "onlyCombat", L["Only in combat"]))
    add(BS("toggle", "showKeybind", L["Show keybind text"]))
    add(BS("toggle", "showGCD", L["Show the global cooldown"]))
    add(Note(L["Border, zoom and keybind text follow the theme's icon settings."]))
    for _, s in ipairs(ns.Specs.Anchor(KEY)) do add(s) end

    add({ type = "header", label = L["Reset"] })
    add({ type = "custom", label = L["Restore defaults"], h = 30, noReset = true,
        build = function(parent, x, y, width, ctx)
            local b = W.CreateButton(parent, L["Restore defaults"], "red", 180, 22)
            W.FitButton(b, 180, 22)
            b:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
            local popup
            b:SetScript("OnClick", function()
                if not popup then
                    popup = W.CreateConfirmPopup(Options.panel, 320, L["Restore the Combat Assistant settings to their defaults?"], function()
                        ResetAll()
                        ctx.lastSpec = { refreshPage = true }
                        ctx.apply()
                    end)
                end
                popup:Show()
            end)
            return 30
        end })
    return list
end

local function Signature()
    local cfg = Cfg() or {}
    local p = ns.profile
    return table.concat({
        Available() and "api" or "-",
        type(cfg.anchor) == "table" and "a" or "-",
        table.concat(p and p.barOrder or {}, ","),
        ns.Specs.AnchorGraphSig(),
    }, "|")
end

function Tab.Build(parent, title)
    local page, y = Options.NewPage(parent, title)
    local pad = Options.PAGE_PAD

    local holder = CreateFrame("Frame", nil, page)
    holder:SetPoint("TOPLEFT", page, "TOPLEFT", pad - 2, y)
    holder:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 10)
    local scroll = W.CreateScrollFrame(holder)
    page.scroll = scroll
    local forms = {}

    local function OnApply(spec)
        if ns.Assist then
            ns.Assist.Refresh()
            ns.Assist.Reapply()
        end
        if ns.AssistIcon then ns.AssistIcon.Apply() end
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
            local ctx = ns.Specs.MakeCtx({ mode = "theme", key = KEY }, OnApply)
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
        self:RefreshForm()
    end
    return page
end

Options.RegisterPage(PAGE, L["Combat Assistant"], Tab.Build)

ns.RegisterCallback("BarMoved", "tab_assist", function(key)
    if key ~= KEY then return end
    local page = Options.GetPage(PAGE)
    if page and page:IsVisible() and page.RefreshForm then ns.Defer(function() page:RefreshForm() end) end
end)
