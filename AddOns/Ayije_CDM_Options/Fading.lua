local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local UI = ns.ConfigUI
local L = Runtime.L


local function CreateFadingTab(page, tabId)
    local scrollChild = page

    local mainHeader = UI.CreateHeader(scrollChild, L["Fading"])
    mainHeader:SetPoint("TOPLEFT", 35, -40)

    local setControlsEnabled
    page.controls.fadingEnabled = UI.CreateModernCheckbox(
        scrollChild,
        L["Enable Fading"],
        CDM.db.fadingEnabled or false,
        function(checked)
            CDM.db.fadingEnabled = checked
            if setControlsEnabled then setControlsEnabled(checked) end
            API:Refresh()
        end
    )
    page.controls.fadingEnabled:SetPoint("TOPLEFT", mainHeader, "BOTTOMLEFT", 0, -15)

    local triggerHeader = UI.CreateSubHeader(scrollChild, L["Fade Triggers"])
    triggerHeader:SetPoint("TOPLEFT", page.controls.fadingEnabled, "BOTTOMLEFT", 0, -15)

    local noTargetCb, oocCb

    noTargetCb = UI.CreateModernCheckbox(
        scrollChild,
        L["Fade when no target"],
        CDM.db.fadingTriggerNoTarget ~= false,
        function(checked)
            CDM.db.fadingTriggerNoTarget = checked
            if checked then
                CDM.db.fadingTriggerOOC = false
                oocCb:SetChecked(false)
            end
            API:Refresh()
        end
    )
    noTargetCb:SetPoint("TOPLEFT", triggerHeader, "BOTTOMLEFT", 0, -10)
    page.controls.noTargetCheckbox = noTargetCb

    oocCb = UI.CreateModernCheckbox(
        scrollChild,
        L["Fade out of combat"],
        CDM.db.fadingTriggerOOC or false,
        function(checked)
            CDM.db.fadingTriggerOOC = checked
            if checked then
                CDM.db.fadingTriggerNoTarget = false
                noTargetCb:SetChecked(false)
            end
            API:Refresh()
        end
    )
    oocCb:SetPoint("TOPLEFT", noTargetCb, "BOTTOMLEFT", 0, -5)
    page.controls.oocCheckbox = oocCb

    page.controls.mountedCheckbox = UI.CreateModernCheckbox(
        scrollChild,
        L["Fade when mounted"],
        CDM.db.fadingTriggerMounted or false,
        function(checked)
            CDM.db.fadingTriggerMounted = checked
            API:Refresh()
        end
    )
    page.controls.mountedCheckbox:SetPoint("TOPLEFT", page.controls.oocCheckbox, "BOTTOMLEFT", 0, -5)

    page.controls.fadingOpacity = UI.CreateModernSlider(
        scrollChild, L["Faded Opacity"], 0, 100, CDM.db.fadingOpacity or 0,
        function(v)
            CDM.db.fadingOpacity = v
            API:Refresh()
        end
    )
    page.controls.fadingOpacity:SetPoint("TOPLEFT", page.controls.mountedCheckbox, "BOTTOMLEFT", 0, -15)

    local targetsHeader = UI.CreateSubHeader(scrollChild, L["Apply Fading To"])
    targetsHeader:SetPoint("TOPLEFT", page.controls.fadingOpacity, "BOTTOMLEFT", 0, -15)

    local targetDefs = {
        { key = "fadingEssential",  label = L["Essential"] },
        { key = "fadingUtility",    label = L["Utility"] },
        { key = "fadingBuffs",      label = L["Buffs"] },
        { key = "fadingBuffBars",   label = L["Buff Bars"] },
        { key = "fadingRacials",    label = L["Racials"] },
        { key = "fadingDefensives", label = L["Defensives"] },
        { key = "fadingTrinkets",   label = L["Trinkets"] },
        { key = "fadingResources",  label = L["Resources"] },
    }

    local prevControl = targetsHeader
    for _, def in ipairs(targetDefs) do
        local cb = UI.CreateModernCheckbox(
            scrollChild,
            def.label,
            CDM.db[def.key] ~= false,
            function(checked)
                CDM.db[def.key] = checked
                API:Refresh()
            end
        )
        cb:SetPoint("TOPLEFT", prevControl, "BOTTOMLEFT", 0, prevControl == targetsHeader and -10 or -5)
        page.controls[def.key] = cb
        prevControl = cb
    end

    setControlsEnabled = UI.SetupModuleToggle(scrollChild, page.controls.fadingEnabled)
    setControlsEnabled(CDM.db.fadingEnabled or false)
end

API:RegisterConfigTab("fading", L["Fading"], CreateFadingTab, 7)
