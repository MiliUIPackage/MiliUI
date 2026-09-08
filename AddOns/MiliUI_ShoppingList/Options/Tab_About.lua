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
        ns.PREFIX_COLOR .. L["MiliUI Shopping List"] .. "|r v" .. ns.VERSION,
        "",
        L["A shopping list for professions: add a recipe from the profession window or from a crafting order, say how many you want to make, and the reagents multiply along with it."],
        L["The list tells you what is still missing, and at the auction house it searches for those reagents and buys them — always behind an explicit confirmation."],
        "",
        L["Commands: |cffffd200/mlist|r opens the list, |cffffd200/mlist config|r opens the settings"],
        "",
        L["Author: Mili (MiliUI package)"],
        L["Inspired by Profession Shop."],
    }, "\n"))

    local reset = W.CreateButton(tab, L["Restore default settings"], "red", 200, 22)
    reset:SetPoint("BOTTOMLEFT", 24, 24)
    reset:SetScript("OnClick", function()
        if not resetPopup then
            resetPopup = W.CreateConfirmPopup(ns.Options.panel, 340,
                L["Restore every setting to its default? Your shopping list is not touched."],
                function() ns.DB.ResetSettings() end)
        end
        resetPopup:Show()
    end)

    local hint = tab:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("LEFT", reset, "RIGHT", 12, 0)
    hint:SetText(L["The list itself is never cleared by this button."])
end

ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
    if id ~= "about" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
end)
