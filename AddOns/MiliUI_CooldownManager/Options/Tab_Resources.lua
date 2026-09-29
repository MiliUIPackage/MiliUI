------------------------------------------------------------
-- 「資源條」頁（profile.resources；引擎在 Modules/Resources.lua）
--
-- 控件清單照單位框架的資源條分頁改：顯示／尺寸／外觀／顏色與條件／這個專精要顯示哪幾列，
-- 多了法力的數字格式、載入條件（騎乘隱藏、只在戰鬥中、跟核心技能一起淡）與「錨定」一節
-- （跟條頁同一支 Specs.Anchor；key ＝ "resources"）。
--
-- 資源清單跟著專精走、條件規則的列數跟著規則走，所以表單照「形狀」快取（專精、候選清單、
-- 條件編輯器的結構、有沒有錨定、條清單）：形狀變了才另建一份、變回來就拿舊的
-- （frame 刪不掉，每改一次重建一次就是洩漏）。形狀的比對延一幀做（不在按鈕的處理器裡換表單）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local Options = ns.Options

ns.TabResources = {}
local Tab = ns.TabResources

local KEY = "resources"
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

local MANA_ITEMS = {
    { text = L["Full number"],           value = "none" },
    { text = L["K / M"],                 value = "k" },
    { text = L["10K / 100M (wan / yi)"], value = "wan" },
}

-- 重設整張 profile.resources（原地清空再灌：引擎抓著的是這張表的參照）
local function ResetAll()
    local p = ns.profile
    local cfg = Cfg()
    if not (p and cfg) then return end
    for k in pairs(cfg) do cfg[k] = nil end
    ns.DB.MergeDefaults(cfg, ns.DB.BuildDefaults().profile.resources)
end

local function ResetRow(label, text, confirmText, fn)
    return { type = "custom", label = label, h = 30, noReset = true, build = function(parent, x, y, width, ctx)
        local b = W.CreateButton(parent, text, "red", 180, 22)
        W.FitButton(b, 180, 22)
        b:SetPoint("LEFT", parent, "TOPLEFT", x, y - 15)
        local popup
        b:SetScript("OnClick", function()
            if not popup then
                popup = W.CreateConfirmPopup(Options.panel, 320, confirmText, function()
                    fn()
                    ctx.lastSpec = { structural = true }
                    ctx.apply()
                end)
            end
            popup:Show()
        end)
        return 30
    end }
end

local function Controls(cand)
    local R = ns.Resources
    local list = {
        BS("toggle", "enabled", L["Show resource bars"], { level = "structure" }),
        Note(L["Which resources appear follows your specialization and switches automatically. Specs that cast with mana get a mana row at the bottom."]),
        { type = "header", label = L["Layout"] },
        BS("slider", "width", L["Width"], { min = 0, max = 600, step = 1 }),
        Note(L["0 matches the first row of Essential Cooldowns."]),
        BS("slider", "rowHeight", L["Row height"], { min = 2, max = 30, step = 1 }),
        BS("slider", "rowSpacing", L["Row spacing"], { min = 0, max = 12, step = 1 }),
        BS("slider", "segmentSpacing", L["Segment spacing"], { min = 0, max = 8, step = 1 }),
        Note(L["Segment spacing only affects point-style resources (Holy Power, combo points and the like)."]),
        BS("dropdown", "fillDirection", L["Fill direction"], { items = FILL_ITEMS }),
        Note(L["Right to left also lights point-style resources from the right: the first point is the rightmost segment."]),
        { type = "header", label = L["Appearance"] },
        BS("dropdown", "texture", L["Texture"], { items = ns.Specs.TextureItems }),
        BS("slider", "barAlpha", L["Fill opacity"], { min = 0.1, max = 1, step = 0.05 }),
        BS("toggle", "smooth", L["Smooth bar changes"]),
        BS("toggle", "showText", L["Show value on the bar"]),
        BS("slider", "textSize", L["Font size"], { min = 6, max = 24, step = 1 }),
        BS("dropdown", "manaAbbrev", L["Mana number format"], { items = MANA_ITEMS }),
        BS("toggle", "manaPercent", L["Mana as percent"]),
        Note(L["Numbers are only printed while the game lets addons read them; the bar itself always moves."]),
    }
    local function add(s) list[#list + 1] = s end

    if #cand > 0 then
        add({ type = "header", label = L["Colors and conditions"] })
        for _, key in ipairs(cand) do
            local info = R.Info(key)
            -- 標籤直接用資源名（暴雪的官方譯名）
            add(BS("color", "colors." .. key .. ".color", info and info.name or key, { hasAlpha = false }))
            if key == "ComboPoints" then
                add(BS("color", "colors.ComboPoints.chargedColor", L["Charged color"], { hasAlpha = false }))
                add(BS("color", "colors.ComboPoints.chargedEmptyColor", L["Charged (empty)"], { hasAlpha = false }))
                add(Note(L["Some combo points become charged (the Rogue's Supercharger, the Feral druid's Overflowing Power). The dim shade marks a charged point you haven't filled yet."]))
            end
        end
        ns.ResourceConditionsUI.Append(list, cand)
    end

    add({ type = "header", label = L["Show for this specialization"] })
    if #cand == 0 then
        add(Note(L["This specialization has no resource to show here."]))
    else
        for _, key in ipairs(cand) do
            local info = R.Info(key)
            local path = "rows." .. key
            add(BS("toggle", path, info and info.name or key, {
                get = function() local c = Cfg(); return not (c and type(c.rows) == "table" and c.rows[key] == false) end,
                set = function(_, on)
                    local c = Cfg()
                    if not c then return end
                    if type(c.rows) ~= "table" then c.rows = {} end
                    c.rows[key] = (not on) and false or nil
                end,
            }))
        end
    end
    add(Note(L["Absorb-style resources (Stagger, Ironfur, Ignore Pain) are secret values in 12.1 — addons can't read the numbers, so they aren't listed."]))

    add({ type = "header", label = L["Load conditions"] })
    add(BS("toggle", "loadConditions.hideMounted", L["Hide while mounted"]))
    add(Note(L["Mounted includes riding a vehicle."]))
    add(BS("toggle", "loadConditions.onlyCombat", L["Only in combat"]))
    add(BS("toggle", "fadeWithEssential", L["Fade with Essential Cooldowns"]))
    add(Note(L["Takes Essential Cooldowns' current opacity, including its visibility conditions and fades."]))

    for _, s in ipairs(ns.Specs.Anchor(KEY)) do add(s) end

    add({ type = "header", label = L["Reset"] })
    add(ResetRow(L["Restore defaults"], L["Restore resource defaults"],
        L["Restore the resource bar settings to their defaults?"], ResetAll))
    return list
end

------------------------------------------------------------
-- 頁面
------------------------------------------------------------
local function Signature()
    local cand, specID = ns.Resources.Candidates()
    local cfg = Cfg() or {}
    local p = ns.profile
    return table.concat({
        tostring(specID), table.concat(cand, ","),
        ns.ResourceConditionsUI.FormSignature(cand),
        type(cfg.anchor) == "table" and "a" or "-",
        table.concat(p and p.barOrder or {}, ","),
        ns.Specs.AnchorGraphSig(),
    }, "|")
end
Tab.Signature = Signature

function Tab.Build(parent, title)
    local page, y = Options.NewPage(parent, title)
    local pad = Options.PAGE_PAD

    local note = page:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetTextColor(0.65, 0.65, 0.65)
    note:SetPoint("TOPLEFT", page, "TOPLEFT", pad + 2, y)
    note:SetWidth(Options.PAGE_W - 4)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(L["One row per resource, stacked; drag it in Edit Mode or anchor it to a bar below."])

    local holder = CreateFrame("Frame", nil, page)
    holder:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -2, -6)
    holder:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 10)
    local scroll = W.CreateScrollFrame(holder)
    page.scroll = scroll
    local forms = {}

    local function OnApply(spec)
        ns.Resources.Apply()
        if ns.EditMode and ns.EditMode.active and ns.EditMode.RequestRefresh then ns.EditMode.RequestRefresh() end
        if ns.Fire then ns.Fire("BarsListChanged") end
        -- 形狀可能變了（規則增刪、錨定開關、開關列）：延一幀再比對，不在按鈕的處理器裡換表單
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
            form = ns.Specs.BuildForm(scroll.child, Controls((ns.Resources.Candidates())), ctx, FORM_W)
            forms[sig] = form
        end
        for _, fm in pairs(forms) do fm.content:SetShown(fm == form) end
        if self.form ~= form then scroll:SetVerticalScroll(0) end
        self.form, self.sig = form, sig
        scroll:SetContentHeight(form.height)
        form:Refresh()
    end

    function page:OnShowPage()
        self:RefreshForm()
    end

    return page
end

Options.RegisterPage(KEY, Options.PageTitle(KEY), Tab.Build)

-- 專精／天賦換了、編輯模式拖完（拖了就脫離錨定）：開著的這一頁照新的形狀重讀
local function Reread()
    local page = Options.GetPage(KEY)
    if page and page:IsVisible() and page.RefreshForm then
        ns.Defer(function() page:RefreshForm() end)
    end
end
ns.RegisterCallback("SpecChanged", "tab_resources", Reread)
ns.RegisterCallback("BarMoved", "tab_resources", function(key) if key == KEY then Reread() end end)
