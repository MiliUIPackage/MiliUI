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
        ns.PREFIX_COLOR .. L["MiliUI Quest Tracker"] .. "|r v" .. ns.VERSION,
        "",
        L["Blizzard still draws the tracker. This addon restyles it, puts a MiliUI title bar on top of it, and decides when to fold it away."],
        L["Nothing here reads or changes your quests — the list you see is the game's own."],
        "",
        L["Commands: |cffffd200/mquest|r opens the options, |cffffd200/mquest fold|r folds or unfolds the list, |cffffd200/mquest trace|r logs the quest automation, |cffffd200/mquest reset|r restores the defaults, |cffffd200/mquest debug|r reports recent errors"],
        "",
        L["Author: Mili (MiliUI package)"],
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
