------------------------------------------------------------
-- 「主題」頁：全域主題（條勾著「跟隨全域主題」的那幾節讀這裡）
--
-- 跟條頁的圖示／文字／效果三節是**同一支 builder**（Specs.Themed），root 換成主題、
-- 沒有跟隨列與覆寫數；多了字型與描邊（放在文字那一節的最前面）。
------------------------------------------------------------
local _, ns = ...

local L = ns.L

local W = ns.W

local Options = ns.Options

Options.RegisterPage("theme", Options.PageTitle("theme"), function(parent, title)
    local page, y = Options.NewPage(parent, title)

    local note = page:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetTextColor(0.65, 0.65, 0.65)
    note:SetPoint("TOPLEFT", page, "TOPLEFT", Options.PAGE_PAD + 2, y)
    note:SetWidth(Options.PAGE_W - 4)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText(L["Parts of a bar that don't have \"Follow global theme\" checked aren't affected by this page."])

    local holder = CreateFrame("Frame", nil, page)
    holder:SetPoint("TOPLEFT", note, "BOTTOMLEFT", -2, -6)
    holder:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -8, 10)
    local scroll = W.CreateScrollFrame(holder)

    local ctx = ns.Specs.MakeCtx({ mode = "theme" }, function()
        ns.Preview.RefreshAll()
        Options.ApplyEngine("layout")
    end)
    local form = ns.Specs.BuildForm(scroll.child, ns.Specs.Themed("theme"), ctx, Options.PAGE_W - 6)
    scroll:SetContentHeight(form.height)
    page.form = form

    function page:OnShowPage() form:Refresh() end
    return page
end)
