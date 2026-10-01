------------------------------------------------------------
-- 「條」的頁面：四條檢視器與自訂群組共用這一支
--
-- 由上到下：
--   標題（自訂群組多一顆「改名」）＋ 開暴雪冷卻管理器／開暴雪警示設定
--   預覽即編輯器（Options/Preview.lua）
--   一行灰字操作說明
--   捲動表單：版面／圖示／文字／效果／顯示條件／錨定（規格在 Options/Specs.lua）
--
-- 表單照「形狀」（Specs.BarSignature：第二列尺寸開關、有沒有錨定、條清單）快取：
-- 形狀變了才另建一份、變回來就拿舊的（frame 刪不掉，每改一次重建一次就是洩漏）。
--
-- 套用兩層：值寫進去的當下只重畫預覽；真實條由 Options.ApplyEngine 合併 0.2 秒一次
-- （Controls 自己已經把滑桿拖動合併成 0.05 秒一次 apply）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

ns.TabBar = {}
local TabBar = ns.TabBar

local Options = ns.Options

------------------------------------------------------------
-- 暴雪冷卻管理器的設定面板
--
-- 警示（聲音／文字提醒）在暴雪面板裡是逐法術右鍵設定的，面板本身沒有「警示」分頁；
-- 所以這裡只有一顆「開暴雪冷卻管理器」。
------------------------------------------------------------
function TabBar.OpenBlizzard()
    if InCombatLockdown() then return end
    -- 不關自己的設定視窗（使用者指定）：兩邊並排對照著改
    if not _G.CooldownViewerSettings and C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_CooldownViewer")
    end
    local f = _G.CooldownViewerSettings
    if f then securecall("ShowUIPanel", f) end
end

------------------------------------------------------------
-- 頁面
------------------------------------------------------------
local FORM_W = Options.PAGE_W - 6

local function Concat(...)
    local out = {}
    for i = 1, select("#", ...) do
        for _, s in ipairs((select(i, ...))) do out[#out + 1] = s end
    end
    return out
end

local function HelpText(pv)
    local parts = {}
    if pv.count == 0 then parts[#parts + 1] = L["This bar has no spells right now."] end
    parts[#parts + 1] = L["Left-click an icon for its own settings, middle-click removes it from this bar, drag to reorder or onto a group on the left. \"+\" adds spells, including ones you removed."]
    if pv.hasLocked then parts[#parts + 1] = L["Red slots are fixed and can't be moved."] end
    if ns.Catalog.IsPaused() then
        parts[#parts + 1] = L["Blizzard's Cooldown Manager settings are open; changes there show up here once you close them."]
    end
    if not ns.specID then parts[#parts + 1] = L["Pick a specialization first: order, hiding and per-spell settings are saved per specialization."] end
    return table.concat(parts, " ")
end

function TabBar.Build(parent, title, key)
    local page, y = Options.NewPage(parent, title)
    page.key = key
    local pad = Options.PAGE_PAD

    -- 按鈕列
    local btnHolder = CreateFrame("Frame", nil, page)
    btnHolder:SetPoint("TOPLEFT", page, "TOPLEFT", pad, y)
    btnHolder:SetSize(Options.PAGE_W, 22)
    local buttons = {}
    local open = W.CreateButton(btnHolder, L["Open Blizzard Cooldown Manager"], "normal", 150, 22)
    W.FitButton(open, 150, 22)
    open:SetScript("OnClick", function() TabBar.OpenBlizzard() end)
    buttons[#buttons + 1] = open
    if not ns.DB.IsBuiltinBar(key) then
        local rename = W.CreateButton(btnHolder, L["Rename"], "normal", 80, 22)
        W.FitButton(rename, 80, 22)
        rename:SetScript("OnClick", function() ns.Sidebar.RenameGroup(key) end)
        buttons[#buttons + 1] = rename
    end
    local _, bh = W.FlowLayout(btnHolder, buttons, Options.PAGE_W, 6, 4, 22)
    btnHolder:SetHeight(bh)
    y = y - bh - 8

    -- 預覽
    local pv = ns.Preview.Create(page, key, Options.PAGE_W)
    pv.frame:SetPoint("TOPLEFT", page, "TOPLEFT", pad, y)
    page.preview = pv

    local note = page:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetTextColor(0.65, 0.65, 0.65)
    note:SetPoint("TOPLEFT", pv.frame, "BOTTOMLEFT", 2, -5)
    note:SetWidth(Options.PAGE_W - 4)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    pv.onRefresh = function() note:SetText(HelpText(pv)) end

    -- 表單
    local holder = CreateFrame("Frame", nil, page)
    holder:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -2, -6)
    holder:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 10)
    local scroll = W.CreateScrollFrame(holder)
    page.scroll = scroll
    local forms = {}

    local function OnApply(spec)
        if spec and spec.refreshPage then page:RefreshForm() end
        ns.Preview.Refresh(key)
        Options.ApplyEngine("structure")
    end

    function page:RefreshForm()
        if not ns.DB.BarTable(key) then return end
        local sig = ns.Specs.BarSignature(key)
        local form = forms[sig]
        if not form then
            local Sp = ns.Specs
            local controls = Concat(Sp.Layout(key), Sp.Themed("bar", key), Sp.Visibility(), Sp.Anchor(key))
            local ctx = Sp.MakeCtx({ mode = "bar", key = key }, OnApply)
            form = Sp.BuildForm(scroll.child, controls, ctx, FORM_W)
            forms[sig] = form
        end
        for _, f in pairs(forms) do f.content:SetShown(f == form) end
        -- 表單換了形狀（規則增刪、開關長出新列）：**維持原本的捲動位置**，只在第一次建這頁時歸零。
        -- 換表單就跳回最上面的話，按一下「新增規則」整頁飛走、玩家還得拉回來找自己在哪
        local keep = self.form and scroll:GetVerticalScroll() or 0
        if self.form ~= form and not self.form then scroll:SetVerticalScroll(0) end
        self.form = form
        scroll:SetContentHeight(form.height)
        if keep > 0 then
            local maxScroll = math.max(0, form.height - (scroll:GetHeight() or 0))
            scroll:SetVerticalScroll(math.min(keep, maxScroll))
        end
        form:Refresh()
    end

    function page:OnShowPage()
        if self.head and self.head.text then self.head.text:SetText(Options.PageTitle(key) or key) end
        self:RefreshForm()
        pv:Refresh()
    end

    return page
end

function TabBar.RefreshForm(key)
    local page = Options.GetPage(key)
    if page and page.form then page.form:Refresh() end
end

-- 四條檢視器的頁面（自訂群組由 Options.SyncBarPages 動態登記）
for _, key in ipairs({ "essential", "utility", "buffs", "buffbars" }) do
    Options.RegisterPage(key, Options.PageTitle(key), TabBar.Build)
end

-- 編輯模式拖完：錨定那一節可能變了（拖了就脫離錨定）
ns.RegisterCallback("BarMoved", "tabbar", function(key)
    local page = Options.GetPage(key)
    if page and page:IsVisible() and page.RefreshForm then page:RefreshForm() end
end)
-- 暴雪那邊的清單變了（面板關掉、換天賦）：看得到的預覽重畫
ns.RegisterCallback("CatalogChanged", "tabbar", function() ns.Preview.RefreshAll() end)
ns.RegisterCallback("CatalogResumed", "tabbar", function() ns.Preview.RefreshAll() end)
