------------------------------------------------------------
-- 「除錯」分頁：/mdm debug 的全文，玩家全選複製貼給作者（比翻存檔直覺）
--
-- 分頁鈕平常藏著，/mdm debug 之後才現身（這次登入期間一直在），見 Options/Panel.lua。
-- 內容是程式產生的：一被輸入就還原（跟 W.CreateCopyBox 同一招），
-- 但報告很長、要捲得動，所以直接用 W.CreateScrollEditBox。
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab

local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()
    local PANEL_W = ns.Options.PANEL_W
    local PAD = 16

    local title = W.CreateSectionTitle(tab, L["Debug"], PANEL_W - PAD * 2)
    title:SetPoint("TOPLEFT", PAD, -14)

    local note = tab:CreateFontString(nil, "OVERLAY")
    note:SetFontObject(W.fontSmall)
    note:SetTextColor(0.65, 0.65, 0.65)
    note:SetPoint("TOPLEFT", PAD + 4, -42)
    note:SetWidth(PANEL_W - PAD * 2 - 8)
    note:SetJustifyH("LEFT")
    note:SetText(L["Click Select all, press Ctrl+C to copy, then paste it to the author."])

    local BTN_ROW = 22 + 12
    local box = W.CreateScrollEditBox(tab, PANEL_W - PAD * 2, 1)
    box:SetPoint("TOPLEFT", PAD, -64)
    box:SetPoint("BOTTOMRIGHT", -PAD, 12 + BTN_ROW)
    local eb = box.editBox
    eb:SetFontObject(W.fontSmall)

    local text = ""
    local function Fill()
        eb:SetText(text)
        eb:SetCursorPosition(0)
    end
    eb:SetScript("OnTextChanged", function(_, userInput)
        if userInput then Fill() end
    end)

    local function Regenerate()
        local ok, t = xpcall(ns.DebugText, ns.ReportError)
        text = ok and t or ""
        Fill()
    end

    local selectBtn = W.CreateButton(tab, L["Select all"], "primary", 100, 22)
    W.FitButton(selectBtn, 100, 22)
    selectBtn:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -12)
    selectBtn:SetScript("OnClick", function()
        eb:SetFocus()
        eb:HighlightText()
    end)

    local regenBtn = W.CreateButton(tab, L["Refresh"], "normal", 100, 22)
    W.FitButton(regenBtn, 100, 22)
    regenBtn:SetPoint("LEFT", selectBtn, "RIGHT", 6, 0)
    regenBtn:SetScript("OnClick", Regenerate)

    tab:SetScript("OnShow", Regenerate)
end

ns.RegisterCallback("ShowOptionsTab", "debugTab", function(id)
    if id ~= "debug" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
end)
