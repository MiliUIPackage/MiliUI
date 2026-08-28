------------------------------------------------------------
-- 「關於」分頁：說明、指令、還原預設值
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab, resetPopup

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
        ns.PREFIX_COLOR .. L["MiliUI Aura Enhance"] .. "|r v" .. ns.VERSION,
        "",
        L["Restyles the duration and stack text on Blizzard's own buff and debuff icons."],
        L["It only changes how the text looks and where it sits — never what it says."],
        L["Buff and debuff icons can also get a thin package-style border; see the Icon skin tab."],
        "",
        L["Commands: |cffffd200/maura|r opens the options, |cffffd200/maura reset|r restores the defaults, |cffffd200/maura debug|r reports recent errors"],
        "",
        L["Author: Mili (MiliUI package)"],
        "",
        L["This used to be the \"Aura duration\" section of the MiliUI package; your old settings were imported the first time this addon ran."],
    }, "\n"))

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

ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
    if id ~= "about" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
end)
