------------------------------------------------------------
-- 「主題」頁：全域主題（條勾著「跟隨全域主題」的那幾節讀這裡）
--
-- 跟條頁的圖示／文字／效果三節是**同一支 builder**（Specs.Themed），root 換成主題、
-- 沒有跟隨列與覆寫數；多了字型與描邊（放在文字那一節的最前面）。
--
-- 分頁（J）：圖示｜文字｜效果｜音效，照 Specs.Themed 的四個頂層 header（Specs.SplitTabs）。
-- 每個分頁一張表單，第一次切過去才建；記得上次看的分頁（只存執行期，同單一法術小窗）。
-- 文字分頁有兩組子分頁（倒數的冷卻｜增益持續時間、充能｜層數，K）：每種選法也是一張表單（Specs.FilterSubTab）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local Options = ns.Options

Options.RegisterPage("theme", Options.PageTitle("theme"), function(parent, title)
    local page, y = Options.NewPage(parent, title)
    local Sp = ns.Specs
    local FORM_W = Options.PAGE_W_FULL - 6

    local note = page:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetTextColor(0.65, 0.65, 0.65)
    note:SetPoint("TOPLEFT", page, "TOPLEFT", Options.PAGE_PAD + 2, y)
    note:SetWidth(Options.PAGE_W_FULL - 4)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(L["Parts of a bar that don't have \"Follow global theme\" checked aren't affected by this page."])

    local byTab, ids = Sp.SplitTabs(Sp.Themed("theme"))
    local forms, curTab = {}, ids[1]
    local curSub = Sp.NewSubTabs()     -- 文字分頁的子分頁（冷卻｜增益持續時間、充能｜層數，K）
    local ShowTab

    local strip = Sp.CreateTabStrip(page, Options.PAGE_W_FULL - 4, function(id) ShowTab(id) end)
    strip:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -2, -8)

    local holder = CreateFrame("Frame", nil, page)
    holder:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -6)
    holder:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 10)
    local scroll = W.CreateScrollFrame(holder)

    local function OnApply()
        ns.Preview.RefreshAll()
        Options.ApplyEngine("layout")
    end

    function ShowTab(id)
        if not byTab[id] then id = ids[1] end
        local switched = id ~= curTab or not page.form
        curTab = id
        strip:SetTabs(ids, id)
        -- 子分頁（K）：每個子分頁一張表單；換子分頁捲動位置不動（子分頁鈕上面的列兩張一樣）
        local specs, hasSub = Sp.FilterSubTab(byTab[id], curSub)
        local fkey = hasSub and (id .. "/" .. Sp.SubTabKey(curSub)) or id
        local form = forms[fkey]
        if not form then
            local ctx = Sp.MakeCtx({ mode = "theme" }, OnApply)
            ctx.subTab = CopyTable(curSub)
            ctx.onSubTab = function(group, sub)
                curSub[group] = sub
                ShowTab(curTab)
            end
            form = Sp.BuildForm(scroll.child, specs, ctx, FORM_W)
            forms[fkey] = form
        end
        for _, f in pairs(forms) do f.content:SetShown(f == form) end
        local keep = (not switched) and scroll:GetVerticalScroll() or 0
        page.form = form
        scroll:SetContentHeight(form.height)
        if switched then
            scroll:SetVerticalScroll(0)
        elseif keep > 0 then
            scroll:SetVerticalScroll(math.min(keep, math.max(0, form.height - (scroll:GetHeight() or 0))))
        end
        form:Refresh()
    end

    -- 第一次建好之後 Options.ShowPage 也會叫這支 ⇒ 表單在這裡才建
    function page:OnShowPage() ShowTab(curTab) end
    return page
end)
