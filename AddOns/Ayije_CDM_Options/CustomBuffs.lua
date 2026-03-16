local Runtime = _G["Ayije_CDM"]
if not Runtime then return end
local API = Runtime.API
local ns = Runtime._OptionsNS
local CDM = Runtime
local CDM_C = CDM and CDM.CONST or {}
local UI = ns.ConfigUI
local L = Runtime.L

local function UpdateLimitDisplay(page)
    if not page.countText or not page.addBtn then return end
    local count = API:GetCustomBuffCount()
    page.countText:SetText(count .. " / 9")
    if count >= 9 then
        page.addBtn:Disable()
        UI.SetTextError(page.countText)
    else
        page.addBtn:Enable()
        UI.SetTextMuted(page.countText)
    end
end

local function RefreshSpellList(listContainer)
    UI.ClearChildren(listContainer)
    local page = listContainer:GetParent()
    UpdateLimitDisplay(page)

    local registry = CDM.db.customBuffRegistry or {}
    local yOffset = 0

    local entries = {}
    for spellID, config in pairs(registry) do
        entries[#entries + 1] = { spellID = spellID, config = config }
    end

    table.sort(entries, function(a, b)
        local nameA = (a.config and a.config.name) or ""
        local nameB = (b.config and b.config.name) or ""
        if nameA ~= nameB then
            return nameA:lower() < nameB:lower()
        end
        return a.spellID < b.spellID
    end)

    for _, entry in ipairs(entries) do
        local spellID = entry.spellID
        local config = entry.config
        local row = CreateFrame("Frame", nil, listContainer)
        row:SetSize(340, 36)
        row:SetPoint("TOPLEFT", 0, yOffset)

        local icon = row:CreateTexture(nil, "ARTWORK")
        icon:SetSize(28, 28)
        icon:SetPoint("LEFT", 0, 0)
        icon:SetTexture(config.icon)
        CDM_C.ApplyIconTexCoord(icon, CDM_C.GetEffectiveZoomAmount())

        local nameText = row:CreateFontString(nil, "OVERLAY", "AyijeCDM_Font14")
        nameText:SetPoint("LEFT", icon, "RIGHT", 8, 6)
        nameText:SetText(config.name or (L["Spell"] .. " " .. spellID))
        UI.SetTextWhite(nameText)

        local infoText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        infoText:SetPoint("LEFT", icon, "RIGHT", 8, -8)
        infoText:SetText(string.format(L["ID: %s  |  Duration: %ss"], spellID, config.duration))
        UI.SetTextMuted(infoText)

        local removeBtn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
        removeBtn:SetSize(60, 22)
        removeBtn:SetPoint("RIGHT", -5, 0)
        removeBtn:SetText(L["Remove"])
        removeBtn:SetScript("OnClick", function()
            API:RemoveCustomBuffSpell(spellID)
            RefreshSpellList(listContainer)
        end)

        yOffset = yOffset - 40
    end

    listContainer:SetHeight(math.max(100, math.abs(yOffset)))
end

local function CreateCustomBuffsTab(page, tabId)
    local yOffset = -40

    local header = UI.CreateHeader(page, L["Custom Timers"])
    header:SetPoint("TOPLEFT", 35, yOffset)
    yOffset = yOffset - 25

    local desc = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    desc:SetPoint("TOPLEFT", 35, yOffset)
    desc:SetWidth(400)
    desc:SetJustifyH("LEFT")
    desc:SetText(L["Track spell casts and display custom buff icons alongside native buffs. Icons appear in the main buff container."])
    UI.SetTextSubtle(desc)
    yOffset = yOffset - 50

    local addHeader = UI.CreateSubHeader(page, L["Add Tracked Spell"])
    addHeader:SetPoint("TOPLEFT", 35, yOffset)
    yOffset = yOffset - 25

    local spellIDLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    spellIDLabel:SetPoint("TOPLEFT", 35, yOffset)
    spellIDLabel:SetText(L["Spell ID:"])

    local spellIDInput = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    spellIDInput:SetSize(100, 20)
    spellIDInput:SetPoint("LEFT", spellIDLabel, "RIGHT", 10, 0)
    spellIDInput:SetAutoFocus(false)
    spellIDInput:SetNumeric(true)
    spellIDInput:SetMaxLetters(10)
    page.spellIDInput = spellIDInput

    local durationLabel = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    durationLabel:SetPoint("LEFT", spellIDInput, "RIGHT", 20, 0)
    durationLabel:SetText(L["Duration (sec):"])

    local durationInput = CreateFrame("EditBox", nil, page, "InputBoxTemplate")
    durationInput:SetSize(60, 20)
    durationInput:SetPoint("LEFT", durationLabel, "RIGHT", 10, 0)
    durationInput:SetAutoFocus(false)
    durationInput:SetNumeric(true)
    durationInput:SetMaxLetters(5)
    durationInput:SetText("10")
    page.durationInput = durationInput

    yOffset = yOffset - 35

    local addBtn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
    addBtn:SetSize(100, 24)
    addBtn:SetPoint("TOPLEFT", 35, yOffset)
    addBtn:SetText(L["Add Spell"])

    local previewText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    previewText:SetPoint("LEFT", addBtn, "RIGHT", 15, 0)
    previewText:SetText("")
    UI.SetTextSuccess(previewText)
    page.previewText = previewText

    spellIDInput:SetScript("OnTextChanged", function(self)
        local text = self:GetText()
        local spellID = tonumber(text)
        if spellID and spellID > 0 then
            local spellInfo = C_Spell.GetSpellInfo(spellID)
            if spellInfo then
                previewText:SetText(spellInfo.name)
                UI.SetTextSuccess(previewText)
            else
                previewText:SetText(L["Invalid spell ID"])
                UI.SetTextError(previewText)
            end
        else
            previewText:SetText("")
        end
    end)

    yOffset = yOffset - 40

    local listHeader = UI.CreateSubHeader(page, L["Tracked Spells"])
    listHeader:SetPoint("TOPLEFT", 35, yOffset)

    local countText = page:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    countText:SetPoint("LEFT", listHeader, "RIGHT", 10, 0)
    page.countText = countText
    page.addBtn = addBtn

    yOffset = yOffset - 25

    local listContainer = CreateFrame("Frame", nil, page)
    listContainer:SetPoint("TOPLEFT", 35, yOffset)
    listContainer:SetSize(400, 300)
    page.listContainer = listContainer

    addBtn:SetScript("OnClick", function()
        local spellIDText = spellIDInput:GetText()
        local durationText = durationInput:GetText()

        local spellID = tonumber(spellIDText)
        local duration = tonumber(durationText)

        if not spellID or spellID <= 0 then
            previewText:SetText(L["Enter a valid spell ID"])
            UI.SetTextError(previewText)
            return
        end

        if not duration or duration <= 0 then
            previewText:SetText(L["Enter a valid duration"])
            UI.SetTextError(previewText)
            return
        end

        if API:GetCustomBuffCount() >= 9 then
            previewText:SetText(L["Limit reached (9 max)"])
            UI.SetTextError(previewText)
            return
        end

        local success = API:AddCustomBuffSpell(spellID, duration)
        if success then
            previewText:SetText(L["Added!"])
            UI.SetTextSuccess(previewText)
            spellIDInput:SetText("")
            RefreshSpellList(listContainer)
        else
            previewText:SetText(L["Failed - invalid spell ID"])
            UI.SetTextError(previewText)
        end
    end)

    RefreshSpellList(listContainer)

    page.RefreshList = function()
        RefreshSpellList(listContainer)
    end
end

API:RegisterConfigTab("custombuffs", L["Custom Timers"], CreateCustomBuffsTab, 11)
