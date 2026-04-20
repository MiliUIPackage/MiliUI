local _, BR = ...

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel
local CreateBuffIcon = BR.CreateBuffIcon

local COMPONENT_GAP = BR.Options.Constants.COMPONENT_GAP

local chatRequestModal = nil

-- Ordered list of buff keys that support chat requests, with display labels and icon spellIDs.
local chatRequestBuffKeys = {
    { key = "intellect", label = L["Buff.ArcaneIntellect"], spellID = 1459 },
    { key = "attackPower", label = L["Buff.BattleShout"], spellID = 6673 },
    { key = "stamina", label = L["Buff.PowerWordFortitude"], spellID = 21562 },
    { key = "versatility", label = L["Buff.MarkOfTheWild"], spellID = 1126 },
    { key = "skyfury", label = L["Buff.Skyfury"], spellID = 462854 },
    { key = "bronze", label = L["Buff.BlessingOfTheBronze"], spellID = 364342 },
    { key = "devotionAura", label = L["Buff.DevotionAura"], spellID = 465 },
    { key = "atrophicNumbingPoison", label = L["Buff.AtrophicNumbingPoison"], spellID = 381637 },
    { key = "soulstone", label = L["Buff.Soulstone"], spellID = 20707 },
}

local function Show()
    if chatRequestModal then
        Components.RefreshAll()
        chatRequestModal:Show()
        return
    end

    local MODAL_WIDTH = 500
    local MARGIN = 16
    local ICON_SIZE = 20
    local ICON_GAP = 6

    local modal = CreatePanel("BuffRemindersChatRequestModal", MODAL_WIDTH, 1, {
        level = 200,
        modal = true,
    })

    local title = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -12)
    title:SetText(L["Options.ChatRequestModal.Title"])

    local closeBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local desc = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOPLEFT", MARGIN, -36)
    desc:SetWidth(MODAL_WIDTH - MARGIN * 2)
    desc:SetJustifyH("LEFT")
    desc:SetText(L["Options.ChatRequestModal.Desc"])
    desc:SetTextColor(0.7, 0.7, 0.7)

    local layout = Components.VerticalLayout(modal, { x = MARGIN + ICON_SIZE + ICON_GAP, y = -62 })

    local LABEL_WIDTH = 150
    local INPUT_WIDTH = MODAL_WIDTH - MARGIN * 2 - LABEL_WIDTH - ICON_SIZE - ICON_GAP
    local ROW_GAP = 8

    local inputHolders = {}

    for _, entry in ipairs(chatRequestBuffKeys) do
        local buffKey = entry.key
        local holder = Components.TextInput(modal, {
            label = entry.label,
            labelWidth = LABEL_WIDTH,
            width = INPUT_WIDTH,
            get = function()
                local custom = (BR.profile.chatRequestMessages or {})[buffKey]
                return (custom and custom ~= "") and custom or ""
            end,
            onChange = function(text)
                text = strtrim(text)
                if not BR.profile.chatRequestMessages then
                    BR.profile.chatRequestMessages = {}
                end
                if text == "" then
                    BR.profile.chatRequestMessages[buffKey] = nil
                else
                    BR.profile.chatRequestMessages[buffKey] = text
                end
                -- Refresh overlays so the new message takes effect
                BR.Display.UpdateActionButtons("raid")
                BR.Display.UpdateActionButtons("presence")
            end,
        })
        holder.editBox:SetMaxLetters(120)
        inputHolders[buffKey] = holder
        layout:Add(holder, nil, ROW_GAP)

        local icon = CreateBuffIcon(modal, ICON_SIZE, C_Spell.GetSpellTexture(entry.spellID))
        icon:SetPoint("RIGHT", holder, "LEFT", -ICON_GAP, 0)
    end

    layout:Space(4)

    local resetBtn = CreateButton(modal, L["Options.ChatRequestModal.ResetAll"], function()
        BR.profile.chatRequestMessages = {}
        for _, entry in ipairs(chatRequestBuffKeys) do
            if inputHolders[entry.key] then
                inputHolders[entry.key]:SetValue("")
            end
        end
        BR.Display.UpdateActionButtons("raid")
        BR.Display.UpdateActionButtons("presence")
    end)
    layout:SetX(MARGIN)
    layout:Add(resetBtn, nil, COMPONENT_GAP)

    modal:SetHeight(math.max(-layout:GetY() + MARGIN, 80))
    chatRequestModal = modal
    modal:Show()
end

BR.Options.Modals.ChatRequest = { Show = Show }
