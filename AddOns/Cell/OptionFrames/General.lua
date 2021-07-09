local _, Cell = ...
local L = Cell.L
local F = Cell.funcs

local generalTab = Cell:CreateFrame("CellOptionsFrame_GeneralTab", Cell.frames.optionsFrame, nil, nil, true)
Cell.frames.generalTab = generalTab
generalTab:SetAllPoints(Cell.frames.optionsFrame)
generalTab:Hide()

-------------------------------------------------
-- tooltip
-------------------------------------------------
local tooltipsText = Cell:CreateSeparator(L["Tooltips"], generalTab, 188)
tooltipsText:SetPoint("TOPLEFT", 203, -5)

local enableTooltipsCB, hideTooltipsInCombatCB, tooltipsAnchor, tooltipsAnchorText, tooltipsAnchoredTo, tooltipsAnchoredToText, tooltipsX, tooltipsY

local function UpdateTooltipsOptions()
    if strfind(CellDB["general"]["tooltipsPosition"][2], "Cursor") then
        tooltipsAnchor:SetEnabled(false)
        tooltipsAnchorText:SetTextColor(.4, .4, .4)
    else
        tooltipsAnchor:SetEnabled(true)
        tooltipsAnchorText:SetTextColor(1, 1, 1)
    end

    if CellDB["general"]["tooltipsPosition"][2] == "Cursor" then
        tooltipsX:SetEnabled(false)
        tooltipsY:SetEnabled(false)
    else
        tooltipsX:SetEnabled(true)
        tooltipsY:SetEnabled(true)
    end
end

function F:ShowTooltips(anchor, tooltipType, value)
    if not CellDB["general"]["enableTooltips"] or (CellDB["general"]["hideTooltipsInCombat"] and InCombatLockdown()) then return end
    
    if CellDB["general"]["tooltipsPosition"][2] == "Cell" then
        GameTooltip:SetOwner(Cell.frames.mainFrame, "ANCHOR_NONE")
        GameTooltip:SetPoint(CellDB["general"]["tooltipsPosition"][1], Cell.frames.mainFrame, CellDB["general"]["tooltipsPosition"][3], CellDB["general"]["tooltipsPosition"][4], CellDB["general"]["tooltipsPosition"][5])
    elseif CellDB["general"]["tooltipsPosition"][2] == "Unit Button" then
        GameTooltip:SetOwner(anchor, "ANCHOR_NONE")
        GameTooltip:SetPoint(CellDB["general"]["tooltipsPosition"][1], anchor, CellDB["general"]["tooltipsPosition"][3], CellDB["general"]["tooltipsPosition"][4], CellDB["general"]["tooltipsPosition"][5])
    elseif CellDB["general"]["tooltipsPosition"][2] == "Cursor" then
        GameTooltip:SetOwner(anchor, "ANCHOR_CURSOR")
    elseif CellDB["general"]["tooltipsPosition"][2] == "Cursor Left" then
        GameTooltip:SetOwner(anchor, "ANCHOR_CURSOR_LEFT", CellDB["general"]["tooltipsPosition"][4], CellDB["general"]["tooltipsPosition"][5])
    elseif CellDB["general"]["tooltipsPosition"][2] == "Cursor Right" then
        GameTooltip:SetOwner(anchor, "ANCHOR_CURSOR_RIGHT", CellDB["general"]["tooltipsPosition"][4], CellDB["general"]["tooltipsPosition"][5])
    end

    if tooltipType == "unit" then
        GameTooltip:SetUnit(value)
    elseif tooltipType == "spell" then
        GameTooltip:SetSpellByID(value)
    end
end

enableTooltipsCB = Cell:CreateCheckButton(generalTab, L["Enabled"], function(checked, self)
    CellDB["general"]["enableTooltips"] = checked
    hideTooltipsInCombatCB:SetEnabled(checked)
    -- enableAuraTooltipsCB:SetEnabled(checked)
    tooltipsAnchor:SetEnabled(checked)
    tooltipsAnchoredTo:SetEnabled(checked)
    tooltipsX:SetEnabled(checked)
    tooltipsY:SetEnabled(checked)
    if checked then
        tooltipsAnchorText:SetTextColor(1, 1, 1)
        tooltipsAnchoredToText:SetTextColor(1, 1, 1)
        UpdateTooltipsOptions()
    else
        tooltipsAnchorText:SetTextColor(.4, .4, .4)
        tooltipsAnchoredToText:SetTextColor(.4, .4, .4)
    end
end)
enableTooltipsCB:SetPoint("TOPLEFT", tooltipsText, "BOTTOMLEFT", 5, -15)

hideTooltipsInCombatCB = Cell:CreateCheckButton(generalTab, L["Hide in Combat"], function(checked, self)
    CellDB["general"]["hideTooltipsInCombat"] = checked
end)
hideTooltipsInCombatCB:SetPoint("TOPLEFT", enableTooltipsCB, "BOTTOMLEFT", 0, -7)

-- auras tooltips
enableAuraTooltipsCB = Cell:CreateCheckButton(generalTab, L["Enable Auras Tooltips"], function(checked, self)
end)
enableAuraTooltipsCB:SetPoint("TOPLEFT", hideTooltipsInCombatCB, "BOTTOMLEFT", 0, -7)
enableAuraTooltipsCB:SetEnabled(false)

-- position
tooltipsAnchor = Cell:CreateDropdown(generalTab, 89)
tooltipsAnchor:SetPoint("TOPLEFT", enableAuraTooltipsCB, "BOTTOMLEFT", 0, -30)
local points = {"BOTTOM", "BOTTOMLEFT", "BOTTOMRIGHT", "LEFT", "RIGHT", "TOP", "TOPLEFT", "TOPRIGHT"}
local relativePoints = {"TOP", "TOPLEFT", "TOPRIGHT", "RIGHT", "LEFT", "BOTTOM", "BOTTOMLEFT", "BOTTOMRIGHT"}
local anchorItems = {}
for i, point in pairs(points) do
    tinsert(anchorItems, {
        ["text"] = L[point],
        ["value"] = point,
        ["onClick"] = function()
            CellDB["general"]["tooltipsPosition"][1] = point
            CellDB["general"]["tooltipsPosition"][3] = relativePoints[i]
        end,
    })
end
tooltipsAnchor:SetItems(anchorItems)

tooltipsAnchorText = generalTab:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
tooltipsAnchorText:SetText(L["Anchor Point"])
tooltipsAnchorText:SetPoint("BOTTOMLEFT", tooltipsAnchor, "TOPLEFT", 0, 1)

tooltipsAnchoredTo = Cell:CreateDropdown(generalTab, 89)
tooltipsAnchoredTo:SetPoint("TOPLEFT", tooltipsAnchor, "TOPRIGHT", 5, 0)
local relatives = {"Cell", "Unit Button", "Cursor", "Cursor Left", "Cursor Right"}
local relativeToItems = {}
for _, relative in pairs(relatives) do
    tinsert(relativeToItems, {
        ["text"] = L[relative],
        ["value"] = relative,
        ["onClick"] = function()
            CellDB["general"]["tooltipsPosition"][2] = relative
            UpdateTooltipsOptions()
        end,
    })
end
tooltipsAnchoredTo:SetItems(relativeToItems)

tooltipsAnchoredToText = generalTab:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
tooltipsAnchoredToText:SetText(L["Anchored To"])
tooltipsAnchoredToText:SetPoint("BOTTOMLEFT", tooltipsAnchoredTo, "TOPLEFT", 0, 1)

tooltipsX = Cell:CreateSlider(L["X Offset"], generalTab, -50, 50, 89, 1)
tooltipsX:SetPoint("TOPLEFT", tooltipsAnchor, "BOTTOMLEFT", 0, -25)
tooltipsX.afterValueChangedFn = function(value)
    CellDB["general"]["tooltipsPosition"][4] = value
end

tooltipsY = Cell:CreateSlider(L["Y Offset"], generalTab, -50, 50, 89, 1)
tooltipsY:SetPoint("TOPLEFT", tooltipsAnchoredTo, "BOTTOMLEFT", 0, -25)
tooltipsY.afterValueChangedFn = function(value)
    CellDB["general"]["tooltipsPosition"][5] = value
end

-------------------------------------------------
-- visibility
-------------------------------------------------
local visibilityText = Cell:CreateSeparator(L["Visibility"], generalTab, 188)
visibilityText:SetPoint("TOPLEFT", 5, -5)

local showSoloCB, showPartyCB, showPartyPetsCB

showSoloCB = Cell:CreateCheckButton(generalTab, L["Show Solo"], function(checked, self)
    CellDB["general"]["showSolo"] = checked
    Cell:Fire("UpdateVisibility", "solo")
end, L["Show Solo"], L["Show while not in a group"], L["To open options frame, use /cell options"])
showSoloCB:SetPoint("TOPLEFT", visibilityText, "BOTTOMLEFT", 5, -15)

showPartyCB = Cell:CreateCheckButton(generalTab, L["Show Party"], function(checked, self)
    CellDB["general"]["showParty"] = checked
    Cell:Fire("UpdateVisibility", "party")
    showPartyPetsCB:SetEnabled(checked)
end, L["Show Party"], L["Show while in a party"], L["To open options frame, use /cell options"])
showPartyCB:SetPoint("TOPLEFT", showSoloCB, "BOTTOMLEFT", 0, -7)

showPartyPetsCB = Cell:CreateCheckButton(generalTab, L["Show Party Pets"], function(checked, self)
    CellDB["general"]["showPartyPets"] = checked
    Cell:Fire("UpdateVisibility", "pets")
end, L["Show Party Pets"], L["Show pets while in a party"])
showPartyPetsCB:SetPoint("TOPLEFT", showPartyCB, "BOTTOMLEFT", 0, -7)

-------------------------------------------------
-- misc
-------------------------------------------------
local miscText = Cell:CreateSeparator(L["Misc"], generalTab, 188)
miscText:SetPoint("TOPLEFT", 5, -110)

-- local blizzardText = Cell:CreateSeparator(L["Blizzard Frames"], generalTab, 188)
-- blizzardText:SetPoint("TOPLEFT", 5, -5)
local hideBlizzardCB = Cell:CreateCheckButton(generalTab, L["Hide Blizzard Raid / Party"], function(checked, self)
    CellDB["general"]["hideBlizzard"] = checked
end, L["Hide Blizzard Frames"], L["Require reload of the UI"])
hideBlizzardCB:SetPoint("TOPLEFT", miscText, "BOTTOMLEFT", 5, -15)

local lockCB = Cell:CreateCheckButton(generalTab, L["Lock Cell Frame"], function(checked, self)
    CellDB["general"]["locked"] = checked
    F:UpdateFrameLock(checked)
end)
lockCB:SetPoint("TOPLEFT", hideBlizzardCB, "BOTTOMLEFT", 0, -7)

local fadeoutCB = Cell:CreateCheckButton(generalTab, L["Fade Out Menu"], function(checked, self)
    CellDB["general"]["fadeOut"] = checked
    F:UpdateMenuFadeOut(checked)
end, L["Fade Out Menu"], L["Fade out menu buttons on mouseout"])
fadeoutCB:SetPoint("TOPLEFT", lockCB, "BOTTOMLEFT", 0, -7)

local sortByRoleCB = Cell:CreateCheckButton(generalTab, L["Sort Party By Role"], function(checked, self)
    CellDB["general"]["sortPartyByRole"] = checked
    Cell:Fire("UpdateSortMethod")
end)
sortByRoleCB:SetPoint("TOPLEFT", fadeoutCB, "BOTTOMLEFT", 0, -7)

-------------------------------------------------
-- raid tools
-------------------------------------------------
local toolsText = Cell:CreateSeparator(L["Raid Tools"].." |cFF777777"..L["Only in Group"], generalTab, 387)
toolsText:SetPoint("TOPLEFT", 5, -240)

local unlockBtn = Cell:CreateButton(generalTab, L["Unlock"], "class-hover", {50, 17})
unlockBtn:SetPoint("RIGHT", -5, 0)
unlockBtn:SetPoint("BOTTOM", toolsText)
unlockBtn.locked = true
unlockBtn:SetScript("OnClick", function(self)
    if self.locked then
        unlockBtn:SetText(L["Lock"])
        self.locked = false
        Cell:Fire("ShowMover", true)
    else
        unlockBtn:SetText(L["Unlock"])
        self.locked = true
        Cell:Fire("ShowMover", false)
    end
end)

-- reBuff checks
local reBuffCB = Cell:CreateCheckButton(generalTab, L["Show ReBuff Checks"], function(checked, self)
    CellDB["raidTools"]["showReBuffChecks"] = checked
end, L["Show ReBuff Checks"], L["Check if your group members need some raid buffs"])
reBuffCB:SetPoint("TOPLEFT", toolsText, "BOTTOMLEFT", 5, -15)
reBuffCB:SetEnabled(false)

-- battle res
local resCB = Cell:CreateCheckButton(generalTab, L["Show Battle Res Timer"], function(checked, self)
    CellDB["raidTools"]["showBattleRes"] = checked
    Cell:Fire("UpdateRaidTools", "battleRes")
end, L["Show Battle Res Timer"], L["Only show during encounter or in mythic+"])
resCB:SetPoint("LEFT", reBuffCB, "RIGHT", 150, 0)

-- ready & pull
local pullText, pullDropdown, secDropdown
local readyPullCB = Cell:CreateCheckButton(generalTab, L["Show ReadyCheck and PullTimer buttons"], function(checked, self)
    CellDB["raidTools"]["showButtons"] = checked
    pullDropdown:SetEnabled(checked)
    secDropdown:SetEnabled(checked)
    if checked then
        pullText:SetTextColor(1, 1, 1)
    else
        pullText:SetTextColor(.4, .4, .4)
    end
    Cell:Fire("UpdateRaidTools", "buttons")
end, L["Show ReadyCheck and PullTimer buttons"], L["Only show when you have permission to do this"], L["pullTimerTips"])
readyPullCB:SetPoint("TOPLEFT", reBuffCB, "BOTTOMLEFT", 0, -15)

pullText = generalTab:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
pullText:SetText(L["Pull Timer"])
pullText:SetPoint("TOPLEFT", readyPullCB, "BOTTOMRIGHT", 5, -10)

pullDropdown = Cell:CreateDropdown(generalTab, 75)
pullDropdown:SetPoint("LEFT", pullText, "RIGHT", 10, 0)
pullDropdown:SetItems({
    {
        ["text"] = "ExRT",
        ["onClick"] = function()
            CellDB["raidTools"]["pullTimer"][1] = "ExRT"
            Cell:Fire("UpdateRaidTools", "pullTimer")
        end,
    },
    {
        ["text"] = "DBM",
        ["onClick"] = function()
            CellDB["raidTools"]["pullTimer"][1] = "DBM"
            Cell:Fire("UpdateRaidTools", "pullTimer")
        end,
    },
    {
        ["text"] = "BW",
        ["onClick"] = function()
            CellDB["raidTools"]["pullTimer"][1] = "BW"
            Cell:Fire("UpdateRaidTools", "pullTimer")
        end,
    },
})

secDropdown = Cell:CreateDropdown(generalTab, 70)
secDropdown:SetPoint("LEFT", pullDropdown, "RIGHT", 5, 0)
secDropdown:SetItems({
    {
        ["text"] = 5,
        ["onClick"] = function()
            CellDB["raidTools"]["pullTimer"][2] = 5
            Cell:Fire("UpdateRaidTools", "pullTimer")
        end,
    },
    {
        ["text"] = 7,
        ["onClick"] = function()
            CellDB["raidTools"]["pullTimer"][2] = 7
            Cell:Fire("UpdateRaidTools", "pullTimer")
        end,
    },
    {
        ["text"] = 10,
        ["onClick"] = function()
            CellDB["raidTools"]["pullTimer"][2] = 10
            Cell:Fire("UpdateRaidTools", "pullTimer")
        end,
    },
    {
        ["text"] = 15,
        ["onClick"] = function()
            CellDB["raidTools"]["pullTimer"][2] = 15
            Cell:Fire("UpdateRaidTools", "pullTimer")
        end,
    },
    {
        ["text"] = 20,
        ["onClick"] = function()
            CellDB["raidTools"]["pullTimer"][2] = 20
            Cell:Fire("UpdateRaidTools", "pullTimer")
        end,
    },
    {
        ["text"] = 25,
        ["onClick"] = function()
            CellDB["raidTools"]["pullTimer"][2] = 25
            Cell:Fire("UpdateRaidTools", "pullTimer")
        end,
    },
    {
        ["text"] = 30,
        ["onClick"] = function()
            CellDB["raidTools"]["pullTimer"][2] = 30
            Cell:Fire("UpdateRaidTools", "pullTimer")
        end,
    },
})

-- marks bar
local marksCB, worldMarksCB, bothCB
local marksBarCB = Cell:CreateCheckButton(generalTab, L["Show Marks Bar"], function(checked, self)
    CellDB["raidTools"]["showMarks"] = checked
    marksCB:SetEnabled(checked)
    worldMarksCB:SetEnabled(checked)
    bothCB:SetEnabled(checked)
    Cell:Fire("UpdateRaidTools", "marks")
end, L["Show Marks Bar"], L["Only show when you have permission to do this"], L["marksTips"])
marksBarCB:SetPoint("TOPLEFT", readyPullCB, "BOTTOMLEFT", 0, -40)

marksCB = Cell:CreateCheckButton(generalTab, L["Target Marks"], function(checked, self)
    CellDB["raidTools"]["marks"] = "target"
    marksCB:SetChecked(true)
    worldMarksCB:SetChecked(false)
    bothCB:SetChecked(false)
    Cell:Fire("UpdateRaidTools", "marks")
end)
marksCB:SetPoint("TOPLEFT", marksBarCB, "BOTTOMRIGHT", 5, -10)

worldMarksCB = Cell:CreateCheckButton(generalTab, L["World Marks"], function(checked, self)
    CellDB["raidTools"]["marks"] = "world"
    marksCB:SetChecked(false)
    worldMarksCB:SetChecked(true)
    bothCB:SetChecked(false)
    Cell:Fire("UpdateRaidTools", "marks")
end)
worldMarksCB:SetPoint("LEFT", marksCB, "RIGHT", 101, 0)

bothCB = Cell:CreateCheckButton(generalTab, L["Both"], function(checked, self)
    CellDB["raidTools"]["marks"] = "both"
    marksCB:SetChecked(false)
    worldMarksCB:SetChecked(false)
    bothCB:SetChecked(true)
    Cell:Fire("UpdateRaidTools", "marks")
end)
bothCB:SetPoint("LEFT", worldMarksCB, "RIGHT", 101, 0)

-------------------------------------------------
-- functions
-------------------------------------------------
local loaded
local function ShowTab(tab)
    if tab == "general" then
        generalTab:Show()
        if loaded then return end
        loaded = true

        -- tooltips
        enableTooltipsCB:SetChecked(CellDB["general"]["enableTooltips"])
        hideTooltipsInCombatCB:SetEnabled(CellDB["general"]["enableTooltips"])
        hideTooltipsInCombatCB:SetChecked(CellDB["general"]["hideTooltipsInCombat"])
        -- enableAuraTooltipsCB:SetEnabled(CellDB["general"]["enableTooltips"])
        -- enableAuraTooltipsCB:SetChecked(CellDB["general"]["enableAurasTooltips"])
        tooltipsAnchor:SetEnabled(CellDB["general"]["enableTooltips"])
        tooltipsAnchor:SetSelectedValue(CellDB["general"]["tooltipsPosition"][1])
        tooltipsAnchoredTo:SetEnabled(CellDB["general"]["enableTooltips"])
        tooltipsAnchoredTo:SetSelectedValue(CellDB["general"]["tooltipsPosition"][2])
        tooltipsX:SetEnabled(CellDB["general"]["enableTooltips"])
        tooltipsX:SetValue(CellDB["general"]["tooltipsPosition"][4])
        tooltipsY:SetEnabled(CellDB["general"]["enableTooltips"])
        tooltipsY:SetValue(CellDB["general"]["tooltipsPosition"][5])
        if CellDB["general"]["enableTooltips"] then
            tooltipsAnchorText:SetTextColor(1, 1, 1)
            tooltipsAnchoredToText:SetTextColor(1, 1, 1)
            UpdateTooltipsOptions()
        else
            tooltipsAnchorText:SetTextColor(.4, .4, .4)
            tooltipsAnchoredToText:SetTextColor(.4, .4, .4)
        end

        -- visibility
        showSoloCB:SetChecked(CellDB["general"]["showSolo"])
        showPartyCB:SetChecked(CellDB["general"]["showParty"])
        showPartyPetsCB:SetChecked(CellDB["general"]["showPartyPets"])
        showPartyPetsCB:SetEnabled(CellDB["general"]["showParty"])

        -- misc
        hideBlizzardCB:SetChecked(CellDB["general"]["hideBlizzard"])
        lockCB:SetChecked(CellDB["general"]["locked"])
        fadeoutCB:SetChecked(CellDB["general"]["fadeOut"])
        sortByRoleCB:SetChecked(CellDB["general"]["sortPartyByRole"])

        -- raid tools
        reBuffCB:SetChecked(CellDB["raidTools"]["showReBuffChecks"])
        resCB:SetChecked(CellDB["raidTools"]["showBattleRes"])

        readyPullCB:SetChecked(CellDB["raidTools"]["showButtons"])
        pullDropdown:SetSelected(CellDB["raidTools"]["pullTimer"][1])
        secDropdown:SetSelected(CellDB["raidTools"]["pullTimer"][2])
        pullDropdown:SetEnabled(CellDB["raidTools"]["showButtons"])
        secDropdown:SetEnabled(CellDB["raidTools"]["showButtons"])
        if CellDB["raidTools"]["showButtons"] then
            pullText:SetTextColor(1, 1, 1)
        else
            pullText:SetTextColor(.4, .4, .4)
        end

        marksBarCB:SetChecked(CellDB["raidTools"]["showMarks"])
        marksCB:SetEnabled(CellDB["raidTools"]["showMarks"])
        worldMarksCB:SetEnabled(CellDB["raidTools"]["showMarks"])
        bothCB:SetEnabled(CellDB["raidTools"]["showMarks"])
        if CellDB["raidTools"]["marks"] == "target" then
            marksCB:SetChecked(true)
        elseif CellDB["raidTools"]["marks"] == "world" then
            worldMarksCB:SetChecked(true)
        else
            bothCB:SetChecked(true)
        end
    else
        generalTab:Hide()
    end
end
Cell:RegisterCallback("ShowOptionsTab", "GeneralTab_ShowTab", ShowTab)
