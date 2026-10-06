------------------------------------------------------------
-- 「天空騎術」頁（profile.skyriding；引擎在 Modules/Skyriding.lua）
--
-- 小節：一般（開關、位置：接力／獨立擺放、藏起冷卻管理器、地面上活力全滿時隱藏）→ 顯示哪些 → 版面（寬、間距）→
--（獨立擺放時）錨定 → 恢復預設。說明一律下一列灰字。
-- 「顯示哪些」照資源條頁「這個專精要顯示哪些」的長相（Tab_Resources 出借的 Tab.OrderRow）：四列（速度條、旋轉急衝、
-- 活力、重新振作）各一列勾選框＋上下移＋「設定」。上下移寫 order（Skyriding.MoveRow），順序進表單簽章 ⇒ 換一份表單；
-- 每一列的高、外觀、顏色、文字、旋轉急衝的效果與圖示在那一列的設定視窗（Options/SkyridingSettings.lua）。
-- 法術名（重新振作、旋轉急衝、快意翱翔、貼地飛掠）執行期讀官方譯名（ns.Skyriding.SpellName）。
--
-- 套用：任何設定一改就重排這個面板（Skyriding.Apply）；placement 換了走 Bars.SkyPlacementChanged
-- （錨定關係整套換掉）；placement 或 hideCdm 換了再 Bars.RequestAll＋Visibility.ApplyAll（會影響所有的條）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local Options = ns.Options

ns.TabSkyriding = {}
local Tab = ns.TabSkyriding

local KEY = "skyriding"
local FORM_W = Options.PAGE_W - 6

local function Cfg() return ns.DB.ConfigTable(KEY) end
local function SR() return ns.Skyriding end
local function Spell(which) return SR() and SR().SpellName(which) or which end

local function BS(kind, path, label, extra)
    local s = { type = kind, root = "bar", path = path, key = path, label = label }
    if extra then for k, v in pairs(extra) do s[k] = v end end
    return s
end

local function Note(label) return { type = "text", label = label } end

local PLACEMENT_ITEMS = {
    { text = L["Relay (resource bar's spot)"], value = "relay" },
    { text = L["Standalone"],                  value = "standalone" },
}

local function ResetAll()
    local cfg = Cfg()
    if not cfg then return end
    for k in pairs(cfg) do cfg[k] = nil end
    ns.DB.MergeDefaults(cfg, ns.DB.BuildDefaults().profile.skyriding)
end

local function Relay() return SR() and SR().IsRelay(Cfg()) or false end

local function Controls()
    local list = {}
    local function add(s) list[#list + 1] = s end

    add({ type = "header", label = L["General"] })
    add(BS("toggle", "enabled", L["Show the skyriding bars"]))
    add(Note(L["Your speed, the %s cooldown and your %s while skyriding, one row each."]:format(Spell("surge"), Spell("vigor"))))
    add(BS("dropdown", "placement", L["Position"], { items = PLACEMENT_ITEMS, refreshPage = true, level = "structure",
        get = function() return Relay() and "relay" or "standalone" end,
        set = function(_, v) SR().SetPlacement(v) end }))
    add(Note(L["Relay: shares the resource bar's spot and takes turns with it while skyriding. Drag the resource bar to move both. Standalone: its own position, drag it in Edit Mode."]))
    add(BS("toggle", "hideCdm", L["Hide the Cooldown Manager while skyriding"]))
    add(Note(L["Every other bar and panel fades out while these bars are showing. Edit Mode still shows everything."]))
    add(BS("toggle", "hideGroundedFull", L["Hide on the ground with full %s"]:format(Spell("vigor"))))

    -- 顯示哪些：四列，順序就是由上往下的順序
    add({ type = "header", label = L["Rows to show"] })
    local order = SR().Order(Cfg())
    for i, key in ipairs(order) do
        add(ns.TabResources.OrderRow({
            label = SR().RowName(key), first = i == 1, last = i == #order,
            get   = function() return SR().RowOn(Cfg(), key) end,
            set   = function(on, ctx)
                local c = Cfg()
                if not c then return end
                ns.DB.SetPath(c, "rows." .. key .. ".enabled", on and true or false)
                ctx.lastSpec = nil
                ctx.apply()
            end,
            move  = function(dir, ctx)
                if not SR().MoveRow(Cfg(), key, dir) then return end
                -- 順序進了表單簽章：換一份表單（延一幀，OnApply 裡比）
                ctx.lastSpec = { refreshPage = true }
                ctx.apply()
            end,
            open  = function() ns.SkyridingSettings.Open(key) end,
        }))
    end
    add(Note(L["The arrows set the order from top to bottom. Height, look, colors and text are set per row: click Settings on its row."]))

    add({ type = "header", label = L["Layout"] })
    add(BS("slider", "width", L["Width"], { min = 0, max = 600, step = 1 }))
    add(Note(L["0 matches the first row of Essential Cooldowns."]))
    add(BS("slider", "gap", L["Spacing"], { min = 0, max = 20, step = 1 }))

    if not Relay() then
        for _, s in ipairs(ns.Specs.Anchor(KEY)) do add(s) end
    end

    add({ type = "header", label = L["Reset"] })
    add({ type = "custom", label = L["Restore defaults"], h = 30, noReset = true,
        build = function(parent, x, y, width, ctx)
            local b = W.CreateButton(parent, L["Restore defaults"], "red", 180, 22)
            W.FitButton(b, 180, 22)
            b:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
            local popup
            b:SetScript("OnClick", function()
                if not popup then
                    popup = W.CreateConfirmPopup(Options.panel, 320, L["Restore the skyriding settings to their defaults?"], function()
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
        Relay() and "relay" or "standalone",
        table.concat(SR() and SR().Order(cfg) or {}, ","),
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
    -- 上次套用時的 placement／hideCdm（右鍵重設、恢復預設也算：比值不比是哪個控件）
    local lastPlacement, lastHide

    local function OnApply(spec)
        local cfg = Cfg() or {}
        local placement = Relay() and "relay" or "standalone"
        local hide = cfg.hideCdm ~= false
        local placementChanged = lastPlacement ~= nil and placement ~= lastPlacement
        local wide = placementChanged or (lastHide ~= nil and hide ~= lastHide)
        lastPlacement, lastHide = placement, hide
        -- 換位置模式先整套換錨定（拆掉貼在它身上的條再貼），再重排面板；反過來的話面板先貼新目標會撞上舊的錨定鏈
        if placementChanged and ns.Bars.SkyPlacementChanged then ns.Bars.SkyPlacementChanged() end
        if ns.Skyriding then ns.Skyriding.Apply() end
        if wide then
            ns.Bars.RequestAll("structure")
            if ns.Visibility then ns.Visibility.ApplyAll() end
        end
        if ns.EditMode and ns.EditMode.Editing() and ns.EditMode.RequestRefresh then ns.EditMode.RequestRefresh() end
        if ns.Fire then ns.Fire("BarsListChanged") end
        ns.Defer(function()
            -- 每一列的設定視窗開著的話一起重讀（活力的「重新振作底色」跟著重新振作那一列的開關停用）
            if ns.SkyridingSettings then ns.SkyridingSettings.Refresh() end
            if page:IsVisible() and (page.sig ~= Signature() or (spec and spec.refreshPage)) then
                page:RefreshForm()
            end
        end)
    end

    function page:RefreshForm()
        local cfg = Cfg()
        if not cfg then return end
        -- 發佈前的欄位搬家（見 Skyriding.Upgrade）：表單讀的是 rows／order
        if SR() then SR().Upgrade(cfg) end
        if lastPlacement == nil then
            lastPlacement, lastHide = Relay() and "relay" or "standalone", cfg.hideCdm ~= false
        end
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

    -- 離開這一頁：每一列的設定視窗一起收（它不是暴雪框，沒有別的地方會關它）
    page:HookScript("OnHide", function() if ns.SkyridingSettings then ns.SkyridingSettings.Close() end end)
    return page
end

Options.RegisterPage(KEY, ns.SkyridingTitle and ns.SkyridingTitle() or L["Skyriding"], Tab.Build)

ns.RegisterCallback("BarMoved", "tab_skyriding", function(key)
    if key ~= KEY then return end
    local page = Options.GetPage(KEY)
    if page and page:IsVisible() and page.RefreshForm then ns.Defer(function() page:RefreshForm() end) end
end)
