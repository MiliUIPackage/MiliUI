------------------------------------------------------------
-- 「關於」分頁
------------------------------------------------------------
local _, ns = ...

local L = ns.L
local W = ns.W

local tab

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
        ns.PREFIX_COLOR .. L["MiliUI Minimap"] .. "|r v" .. ns.VERSION,
        "",
        L["A square minimap in the MiliUI house style, plus one strip of who is online."],
        L["Black translucent panel, 1px border in your class colour, white text, square corners — the same look as the damage meter windows and the unit frames."],
        "",
        L["The info bar reads nothing in the background: the guild and friend lists are only walked while the tooltip is actually open."],
        "",
        L["Commands: |cffffd200/mmap|r opens the options, |cffffd200/mmap bag|r opens the addon-button bag, |cffffd200/mmap lock|r and |cffffd200/mmap unlock|r toggle dragging, |cffffd200/mmap reset|r restores defaults, |cffffd200/mmap debug|r reports recent errors"],
        "",
        L["Author: Mili (MiliUI package)"],
    }, "\n"))
end

ns.RegisterCallback("ShowOptionsTab", "aboutTab", function(id)
    if id ~= "about" then
        if tab then tab:Hide() end
        return
    end
    Init()
    tab:Show()
end)
