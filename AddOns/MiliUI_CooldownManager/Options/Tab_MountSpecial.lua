------------------------------------------------------------
-- 「坐騎特效按鈕」頁（profile.mountspecial；引擎在 Modules/MountSpecial.lua）
--
-- 小節：一般（開關＋灰字、跟著天空騎術條＋灰字、天空騎術條下方的位移）→ 版面（按鈕尺寸、字級）→ 錨定（共用的錨定小節）→ 恢復預設。
-- 說明一律下一列灰字。任何設定一改就重排這個面板（MountSpecial.Apply）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local Options = ns.Options

ns.TabMountSpecial = {}
local Tab = ns.TabMountSpecial

local KEY = "mountspecial"
local FORM_W = Options.PAGE_W - 6

local function Cfg() return ns.DB.ConfigTable(KEY) end
local function MS() return ns.MountSpecial end

local function BS(kind, path, label, extra)
    local s = { type = kind, root = "bar", path = path, key = path, label = label }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local function Note(label) return { type = "text", label = label } end

local function ResetAll()
    local cfg = Cfg()
    if not cfg then return end
    for k in pairs(cfg) do cfg[k] = nil end
    ns.DB.MergeDefaults(cfg, ns.DB.BuildDefaults().profile.mountspecial)
end

local function Controls()
    local list = {}
    local function add(s) list[#list + 1] = s end
    local function Off() local c = Cfg(); return not c or c.enabled == false end
    local function NoSky() return Off() or not (MS() and MS().FollowSky(Cfg())) end

    add({ type = "header", label = L["General"] })
    add(BS("toggle", "enabled", L["Show the Mount Special button"]))
    add(Note(L["A button that plays your mount's special animation (the same as /mountspecial). It shows whenever you are mounted and not gliding in skyriding."]))
    add(BS("toggle", "followSky", L["Follow the skyriding bars"], { disabled = Off }))
    add(Note(L["While the skyriding bars are showing, the button sits centered right under them instead of at its own position."]))
    add(BS("numbers", nil, L["Offset below the skyriding bars"], { sub = "sky", path = false, disabled = NoSky,
        resetPaths = { "sky.x", "sky.y" },
        fields = { { key = "x", label = "X" }, { key = "y", label = "Y" } } }))

    add({ type = "header", label = L["Layout"] })
    add(BS("numbers", nil, L["Button size"], { sub = "box", path = false, disabled = Off,
        resetPaths = { "box.w", "box.h" },
        fields = { { key = "w", label = L["W"] }, { key = "h", label = L["H"] } } }))
    add(BS("slider", "fontSize", L["Font size"], { min = 6, max = 40, step = 1, disabled = Off }))

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
                    popup = W.CreateConfirmPopup(Options.panel, 320, L["Restore the Mount Special button settings to their defaults?"], function()
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
        if ns.MountSpecial then ns.MountSpecial.Apply() end
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
        self:RefreshForm()
    end
    return page
end

Options.RegisterPage(KEY, L["Mount Special button"], Tab.Build)

-- 編輯模式拖完（拖了就脫離錨定）、錨定視窗改了值：錨定那一節重讀
local function RefreshMoved(key)
    if key ~= KEY then return end
    local page = Options.GetPage(KEY)
    if page and page:IsVisible() and page.RefreshForm then ns.Defer(function() page:RefreshForm() end) end
end
ns.RegisterCallback("BarMoved", "tab_mountspecial", RefreshMoved)
ns.RegisterCallback("AnchorChanged", "tab_mountspecial", RefreshMoved)
