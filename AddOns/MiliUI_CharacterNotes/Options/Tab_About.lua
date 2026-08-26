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
        ns.PREFIX_COLOR .. L["MiliUI Character Notes"] .. "|r v" .. ns.VERSION,
        "",
        L["A notebook that lives in the game: checkboxes, bullets and numbered blocks, kept either account-wide or per character."],
        L["Notes can also be bound to a dungeon or raid and to each of its bosses. Those show up on their own when you walk in and when the fight starts."],
        L["Dungeon and boss notes are account-wide: every character sees the same ones, because a route or a thing to watch out for does not change from character to character."],
        L["Any note can be shared with your group through a chat link."],
        "",
        L["Commands: |cffffd200/mnote|r opens the notebook, |cffffd200/mnote config|r opens the settings, |cffffd200/mnote dungeon|r toggles the dungeon window, |cffffd200/mnote debug|r reports recent errors"],
        "",
        L["Author: Mili (MiliUI package)"],
        "",
        L["This used to be the character notes window of the MiliUI package; your notes were imported the first time this addon ran."],
    }, "\n"))

    local reset = W.CreateButton(tab, L["Restore default settings"], "red", 200, 22)
    reset:SetPoint("BOTTOMLEFT", 24, 24)
    reset:SetScript("OnClick", function()
        if not resetPopup then
            resetPopup = W.CreateConfirmPopup(ns.Options.panel, 340,
                L["Restore every setting to its default? Your notes are not touched."],
                function() ns.DB.ResetSettings() end)
        end
        resetPopup:Show()
    end)

    local hint = tab:CreateFontString(nil, "OVERLAY")
    hint:SetFontObject(W.fontSmall)
    hint:SetPoint("LEFT", reset, "RIGHT", 12, 0)
    hint:SetText(L["Notes are never deleted by this button."])
end

ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
    if id ~= "about" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
end)
