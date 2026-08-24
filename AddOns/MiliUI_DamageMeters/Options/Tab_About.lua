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
        ns.PREFIX_COLOR .. L["MiliUI Damage Meters"] .. "|r v" .. ns.VERSION,
        "",
        L["A damage meter that draws, but does not tally."],
        L["Blizzard's own C_DamageMeter API does the aggregation, so this addon never touches the combat log. Its cost scales with the number of visible rows, not with raid size or how fast the fight is going."],
        "",
        L["Left-click a bar to break it down by spell. Right-click anywhere on a window for its menu. Drag the title bar to move it, or move it in Edit Mode."],
        "",
        L["Commands: |cffffd200/mdm|r opens the options, |cffffd200/mdm reset|r clears the recorded segments, |cffffd200/mdm debug|r reports recent errors"],
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
