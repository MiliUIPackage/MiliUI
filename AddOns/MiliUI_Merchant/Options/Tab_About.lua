------------------------------------------------------------
-- 「關於」分頁：說明、指令、休眠狀態、還原預設值
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab, status, resetPopup

local function Init()
    if tab then return end
    tab = ns.Options.NewTabFrame()

    local text = tab:CreateFontString(nil, "OVERLAY")
    text:SetFontObject(W.fontNormal)
    text:SetPoint("TOPLEFT", 24, -26)
    text:SetWidth(ns.Options.FORM_W)
    text:SetJustifyH("LEFT")
    text:SetSpacing(6)
    text:SetText(table.concat({
        ns.PREFIX_COLOR .. L["MiliUI Merchant"] .. "|r v" .. ns.VERSION,
        "",
        L["Blizzard still draws every merchant slot. This addon only adds more of them and dims the ones you already own."],
        L["Item numbering is never rewritten, so anything else that decorates merchant slots keeps working."],
        "",
        L["Commands: |cffffd200/mmerchant|r opens the options, |cffffd200/mmerchant debug|r prints the current state"],
        "",
        L["Author: Mili (MiliUI package)"],
    }, "\n"))

    -- 休眠狀態：唯一會讓整支插件什麼都不做的情況，要看得到
    status = tab:CreateFontString(nil, "OVERLAY")
    status:SetFontObject(W.fontNormal)
    status:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -18)
    status:SetWidth(ns.Options.FORM_W)
    status:SetJustifyH("LEFT")

    local reset = W.CreateButton(tab, L["Restore defaults"], "red", 160, 22)
    reset:SetPoint("BOTTOMLEFT", 24, 24)
    reset:SetScript("OnClick", function()
        if not resetPopup then
            resetPopup = W.CreateConfirmPopup(ns.Options.panel, 320,
                L["Restore every setting to its default?"],
                function() ns.DB.ResetAll() end)
        end
        resetPopup:Show()
    end)
end

local function Refresh()
    if ns.dormant then
        status:SetText("|cffff5555"
            .. L["Standing down: another add-on is already extending the merchant window."] .. "|r")
    else
        status:SetText("|cff55ff55" .. L["Active."] .. "|r")
    end
end

ns.Options.RegisterTab("about", function(show)
    if not show then
        if tab then tab:Hide() end
        return
    end
    Init()
    Refresh()
    tab:Show()
end)
