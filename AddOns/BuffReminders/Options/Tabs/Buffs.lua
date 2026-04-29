local _, BR = ...

-- ============================================================================
-- BUFFS TAB
-- ============================================================================
-- Two-column grid of per-buff enable/disable checkboxes, plus the custom buff
-- list on the right column.

local L = BR.L
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreateSectionHeader = BR.CreateSectionHeader

local BUFF_TABLES = BR.BUFF_TABLES
local BuffGroups = BR.BuffGroups

local RaidBuffs = BUFF_TABLES.raid
local PresenceBuffs = BUFF_TABLES.presence
local TargetedBuffs = BUFF_TABLES.targeted
local SelfBuffs = BUFF_TABLES.self
local PetBuffs = BUFF_TABLES.pet
local Consumables = BUFF_TABLES.consumable

local IsIconDetached = BR.Helpers.IsIconDetached
local DetachIcon = BR.Helpers.DetachIcon
local ReattachIcon = BR.Helpers.ReattachIcon
local GetBuffTexture = BR.Helpers.GetBuffTexture

local UpdateDisplay = BR.Display.Update

local ResolveBuffIcons = BR.Options.Helpers.ResolveBuffIcons

local ITEM_HEIGHT = BR.Options.Constants.ITEM_HEIGHT

-- Bound by Build(ctx) to panel.buffCheckboxes so CreateBuffCheckbox can register
-- each row without threading the panel frame through every call.
local buffCheckboxesRef

local abs = math.abs
local max = math.max
local tinsert = table.insert
local tsort = table.sort

-- Buff-specific settings: key → { tooltip, note, onClick }
-- Gear icon shown in a fixed column (right of detach pin) for consistent alignment.
local buffSettingsActions = {
    healthstone = {
        tooltip = L["Options.HealthstoneSettings"],
        note = L["Options.HealthstoneSettings.Note"],
        onClick = function()
            BR.Options.Modals.Healthstone.Show()
        end,
    },
    soulstone = {
        tooltip = L["Options.SoulstoneSettings"],
        note = L["Options.SoulstoneSettings.Note"],
        onClick = function()
            BR.Options.Modals.Soulstone.Show()
        end,
    },
    dkRunes = {
        tooltip = L["Options.RuneforgePreferences"],
        note = L["Options.RuneforgeNote"],
        onClick = function()
            BR.Options.Modals.Runeforge.Show()
        end,
    },
    roguePoisons = {
        tooltip = L["Options.RoguePoisonPreferences"],
        note = L["Options.RoguePoisonNote"],
        onClick = function()
            BR.Options.Modals.RoguePoison.Show()
        end,
    },
    petPassive = {
        tooltip = L["Options.PetPassiveSettings"],
        note = L["Options.PetPassiveSettings.Note"],
        onClick = function()
            BR.Options.Modals.PetPassive.Show()
        end,
    },
    pets = {
        tooltip = L["Options.PetSummonSettings"],
        note = L["Options.PetSummonSettings.Note"],
        onClick = function()
            BR.Options.Modals.PetSummon.Show()
        end,
    },
    delveFood = {
        tooltip = L["Options.DelveFoodSettings"],
        note = L["Options.DelveFoodSettings.Note"],
        onClick = function()
            BR.Options.Modals.DelveFood.Show()
        end,
    },
    bronze = {
        tooltip = L["Options.BronzeSettings"],
        note = L["Options.BronzeSettings.Note"],
        onClick = function()
            BR.Options.Modals.Bronze.Show()
        end,
    },
}

-- Create a single buff checkbox with detach pin, optional gear icon, and ready-check toggle.
local function CreateBuffCheckbox(
    parent,
    x,
    y,
    spellIDs,
    key,
    displayName,
    infoTooltip,
    displayIcon,
    readyCheckOnly,
    freeConsumable
)
    local holder = Components.Checkbox(parent, {
        label = displayName,
        icons = ResolveBuffIcons(displayIcon, spellIDs),
        infoTooltip = not readyCheckOnly and infoTooltip or nil,
        get = function()
            return BR.profile.enabledBuffs[key] ~= false
        end,
        onChange = function(checked)
            BR.profile.enabledBuffs[key] = checked
            UpdateDisplay()
            if readyCheckOnly then
                Components.RefreshAll()
            end
        end,
    })
    holder:SetPoint("TOPLEFT", x, y)
    buffCheckboxesRef[key] = holder

    -- Inline toggle: "Ready check only" / "Always show" (replaces info tooltip icon)
    -- Skip for free consumables (controlled by dropdown) and soulstone (controlled by gear icon modal)
    if readyCheckOnly and not freeConsumable and key ~= "soulstone" then
        local function GetReadyCheckOnlyState()
            local overrides = BR.profile.readyCheckOnlyOverrides
            return not overrides or overrides[key] ~= false
        end

        local function ToggleLabel(checked)
            return checked and L["Options.ReadyCheck"] or L["Options.Always"]
        end

        local toggle
        toggle = Components.Toggle(holder, {
            label = ToggleLabel(GetReadyCheckOnlyState()),
            get = GetReadyCheckOnlyState,
            enabled = function()
                return BR.profile.enabledBuffs[key] ~= false
            end,
            onChange = function(checked)
                if checked then
                    BR.Config.Set("readyCheckOnlyOverrides." .. key, nil)
                else
                    BR.Config.Set("readyCheckOnlyOverrides." .. key, false)
                end
                toggle.label:SetText(ToggleLabel(checked))
            end,
        })
        local origRefresh = toggle.Refresh
        function toggle:Refresh()
            origRefresh(self)
            self.label:SetText(ToggleLabel(GetReadyCheckOnlyState()))
        end
        toggle:SetPoint("LEFT", holder.label, "RIGHT", 6, 0)
    end

    -- Settings gear icon (fixed column, first icon right of checkbox)
    local settings = buffSettingsActions[key]
    if settings then
        local gearBtn = CreateFrame("Button", nil, holder)
        gearBtn:SetSize(14, 14)
        gearBtn:SetPoint("LEFT", holder, "RIGHT", 4, 0)
        gearBtn:SetFrameLevel(holder:GetFrameLevel() + 5)
        local gearTex = gearBtn:CreateTexture(nil, "ARTWORK")
        gearTex:SetAllPoints()
        gearTex:SetTexture("Interface\\Buttons\\UI-OptionsButton")
        gearTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
        gearBtn:SetScript("OnEnter", function(self)
            gearTex:SetVertexColor(1, 1, 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(settings.tooltip, 1, 1, 1)
            GameTooltip:AddLine(settings.note, 0.7, 0.7, 0.7, true)
            GameTooltip:Show()
        end)
        gearBtn:SetScript("OnLeave", function()
            gearTex:SetVertexColor(0.7, 0.7, 0.7, 0.8)
            GameTooltip:Hide()
        end)
        gearBtn:SetScript("OnClick", settings.onClick)
    end

    -- Detach button: small pin icon to toggle detached positioning.
    -- Fixed offset from holder right edge (leaves gap for gear icon slot).
    local detachBtn = CreateFrame("Button", nil, holder)
    detachBtn:SetSize(14, 14)
    detachBtn:SetPoint("LEFT", holder, "RIGHT", 22, 0)

    local detachIcon = detachBtn:CreateTexture(nil, "ARTWORK")
    detachIcon:SetAllPoints()
    detachIcon:SetAtlas("Waypoint-MapPin-ChatIcon")

    local function UpdateDetachVisual()
        if IsIconDetached(key) then
            detachIcon:SetVertexColor(1, 0.85, 0.3, 1)
            detachIcon:SetDesaturated(false)
        else
            detachIcon:SetVertexColor(0.5, 0.5, 0.5, 0.6)
            detachIcon:SetDesaturated(true)
        end
    end
    UpdateDetachVisual()

    detachBtn:SetScript("OnClick", function()
        if IsIconDetached(key) then
            ReattachIcon(key)
        else
            DetachIcon(key)
        end
        UpdateDetachVisual()
        UpdateDisplay()
    end)
    detachBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Options.DetachIcon"], 1, 1, 1)
        GameTooltip:AddLine(L["Options.DetachIcon.Desc"], 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)
    detachBtn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return y - ITEM_HEIGHT
end

-- Render checkboxes for a buff array (single column within each side).
local function RenderBuffCheckboxes(parent, x, y, buffArray)
    local groupSpells = {}
    local groupDisplaySpells = {}
    local groupIconOverrides = {}
    local groupReadyCheckOnly = {}
    local groupFreeConsumable = {}

    for _, buff in ipairs(buffArray) do
        if buff.groupId then
            groupSpells[buff.groupId] = groupSpells[buff.groupId] or {}
            groupDisplaySpells[buff.groupId] = groupDisplaySpells[buff.groupId] or {}
            if buff.spellID then
                local spellList = type(buff.spellID) == "table" and buff.spellID or { buff.spellID }
                for _, id in ipairs(spellList) do
                    tinsert(groupSpells[buff.groupId], id)
                end
            end
            if buff.displaySpells then
                local displayList = type(buff.displaySpells) == "table" and buff.displaySpells or { buff.displaySpells }
                for _, id in ipairs(displayList) do
                    tinsert(groupDisplaySpells[buff.groupId], id)
                end
            end
            -- Resolve display icon(s) per entry: displayIcon > displaySpells > primary spellID.
            -- Deduplicate icons within the same group (e.g., MH + OH weapon buffs share icons).
            if not groupIconOverrides[buff.groupId] then
                groupIconOverrides[buff.groupId] = {}
                groupIconOverrides[buff.groupId]._seen = {}
            end
            local seen = groupIconOverrides[buff.groupId]._seen
            if buff.displayIcon then
                local overrides = type(buff.displayIcon) == "table" and buff.displayIcon or { buff.displayIcon }
                for _, icon in ipairs(overrides) do
                    if not seen[icon] then
                        seen[icon] = true
                        tinsert(groupIconOverrides[buff.groupId], icon)
                    end
                end
            elseif buff.displaySpells then
                local displayList = type(buff.displaySpells) == "table" and buff.displaySpells or { buff.displaySpells }
                for _, id in ipairs(displayList) do
                    local texture = GetBuffTexture(id)
                    if texture and not seen[texture] then
                        seen[texture] = true
                        tinsert(groupIconOverrides[buff.groupId], texture)
                    end
                end
            elseif buff.spellID then
                local primarySpell = type(buff.spellID) == "table" and buff.spellID[1] or buff.spellID
                if primarySpell and primarySpell > 0 then
                    local texture = GetBuffTexture(primarySpell)
                    if texture and not seen[texture] then
                        seen[texture] = true
                        tinsert(groupIconOverrides[buff.groupId], texture)
                    end
                end
            end
            if buff.readyCheckOnly then
                groupReadyCheckOnly[buff.groupId] = true
            end
            if buff.freeConsumable then
                groupFreeConsumable[buff.groupId] = true
            end
        end
    end

    local seenGroups = {}
    for _, buff in ipairs(buffArray) do
        if buff.groupId then
            if not seenGroups[buff.groupId] then
                seenGroups[buff.groupId] = true
                local groupInfo = BuffGroups[buff.groupId]
                local displayIcon = groupIconOverrides[buff.groupId]
                if displayIcon and #displayIcon == 0 then
                    displayIcon = nil
                end
                local displaySpells = groupDisplaySpells[buff.groupId]
                local spells = (#displaySpells > 0) and displaySpells or groupSpells[buff.groupId]
                if #spells == 0 then
                    spells = nil
                end
                y = CreateBuffCheckbox(
                    parent,
                    x,
                    y,
                    spells,
                    buff.groupId,
                    groupInfo and groupInfo.displayName or buff.name,
                    buff.infoTooltip,
                    displayIcon,
                    groupReadyCheckOnly[buff.groupId],
                    groupFreeConsumable[buff.groupId]
                )
            end
        else
            local displaySpells = buff.displaySpells or buff.spellID
            y = CreateBuffCheckbox(
                parent,
                x,
                y,
                displaySpells,
                buff.key,
                buff.name,
                buff.infoTooltip,
                buff.displayIcon,
                buff.readyCheckOnly,
                buff.freeConsumable
            )
        end
    end

    return y
end

-- Header + small description note rendered tightly underneath. Spacing is
-- redistributed vs. the older two-call pattern (less air between header and
-- note, more air between note and the checkboxes that follow). Net y-advance
-- to the start of the checkbox area is unchanged.
local NOTE_HEADER_NUDGE = 3
local function CreateSectionWithNote(parent, x, y, headerText, noteText)
    local _, postHeaderY = CreateSectionHeader(parent, headerText, x, y)
    local note = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("TOPLEFT", x, postHeaderY + NOTE_HEADER_NUDGE)
    note:SetText(noteText)
    return postHeaderY - 14
end

local function Build(ctx)
    local panel = ctx.panel
    local C = ctx.constants
    local PANEL_WIDTH = C.PANEL_WIDTH
    local COL_PADDING = C.COL_PADDING
    local SECTION_SPACING = C.SECTION_SPACING

    panel.buffCheckboxes = {}
    buffCheckboxesRef = panel.buffCheckboxes

    local buffsContent = ctx:CreateScrollableContent("buffs")

    local COL_WIDTH = (PANEL_WIDTH - COL_PADDING * 3) / 2
    local buffsLeftX = COL_PADDING
    local buffsRightX = COL_PADDING + COL_WIDTH + COL_PADDING
    local buffsLeftY = -6
    local buffsRightY = -6

    local function CreateDetachColumnHeader(parent, x, y)
        local label = parent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        label:SetPoint("TOPLEFT", x, y)
        label:SetText(L["Options.DetachIcon"])
    end

    CreateDetachColumnHeader(buffsContent, buffsLeftX + 211, -8)
    CreateDetachColumnHeader(buffsContent, buffsRightX + 211, -8)

    -- LEFT COLUMN: Group-wide buffs
    buffsLeftY =
        CreateSectionWithNote(buffsContent, buffsLeftX, buffsLeftY, L["Category.RaidBuffs"], L["Category.RaidNote"])
    buffsLeftY = RenderBuffCheckboxes(buffsContent, buffsLeftX, buffsLeftY, RaidBuffs)
    buffsLeftY = buffsLeftY - SECTION_SPACING

    buffsLeftY = CreateSectionWithNote(
        buffsContent,
        buffsLeftX,
        buffsLeftY,
        L["Category.TargetedBuffs"],
        L["Category.TargetedNote"]
    )
    buffsLeftY = RenderBuffCheckboxes(buffsContent, buffsLeftX, buffsLeftY, TargetedBuffs)
    buffsLeftY = buffsLeftY - SECTION_SPACING

    buffsLeftY = CreateSectionWithNote(
        buffsContent,
        buffsLeftX,
        buffsLeftY,
        L["Category.Consumables"],
        L["Category.ConsumableNote"]
    )
    buffsLeftY = RenderBuffCheckboxes(buffsContent, buffsLeftX, buffsLeftY, Consumables)

    -- RIGHT COLUMN: Individual buffs
    buffsRightY = CreateSectionWithNote(
        buffsContent,
        buffsRightX,
        buffsRightY,
        L["Category.PresenceBuffs"],
        L["Category.PresenceNote"]
    )
    buffsRightY = RenderBuffCheckboxes(buffsContent, buffsRightX, buffsRightY, PresenceBuffs)
    buffsRightY = buffsRightY - SECTION_SPACING

    buffsRightY =
        CreateSectionWithNote(buffsContent, buffsRightX, buffsRightY, L["Category.SelfBuffs"], L["Category.SelfNote"])
    buffsRightY = RenderBuffCheckboxes(buffsContent, buffsRightX, buffsRightY, SelfBuffs)
    buffsRightY = buffsRightY - SECTION_SPACING

    buffsRightY =
        CreateSectionWithNote(buffsContent, buffsRightX, buffsRightY, L["Category.PetReminders"], L["Category.PetNote"])
    buffsRightY = RenderBuffCheckboxes(buffsContent, buffsRightX, buffsRightY, PetBuffs)
    buffsRightY = buffsRightY - SECTION_SPACING

    -- Custom Buffs section
    buffsRightY = CreateSectionWithNote(
        buffsContent,
        buffsRightX,
        buffsRightY,
        L["Category.CustomBuffs"],
        L["Category.CustomNote"]
    )
    panel.customBuffRows = {}

    local customSectionStartY = buffsRightY
    local customBuffsContainer = CreateFrame("Frame", nil, buffsContent)
    customBuffsContainer:SetPoint("TOPLEFT", buffsRightX, buffsRightY)
    customBuffsContainer:SetSize(COL_WIDTH, 200)

    local ADD_BTN_GAP = 4
    local ADD_BTN_HEIGHT = 22
    local CUSTOM_CONTAINER_PAD = ADD_BTN_GAP + ADD_BTN_HEIGHT + 2

    local function RenderCustomBuffRows()
        for _, row in ipairs(panel.customBuffRows) do
            row:Hide()
            row:SetParent(nil)
        end
        panel.customBuffRows = {}

        local db = BR.profile
        local rowY = 0

        local sortedKeys = {}
        if db.customBuffs then
            for key in pairs(db.customBuffs) do
                tinsert(sortedKeys, key)
            end
        end
        tsort(sortedKeys)

        for _, key in ipairs(sortedKeys) do
            local customBuff = db.customBuffs[key]

            local holder = Components.Checkbox(customBuffsContainer, {
                label = customBuff.name or (L["CustomBuff.Action.Spell"] .. " " .. tostring(customBuff.spellID)),
                icons = ResolveBuffIcons(nil, customBuff.spellID),
                get = function()
                    return BR.profile.enabledBuffs[key] ~= false
                end,
                onChange = function(checked)
                    BR.profile.enabledBuffs[key] = checked
                    UpdateDisplay()
                end,
                onRightClick = function()
                    BR.Options.Modals.CustomBuff.Show(key, RenderCustomBuffRows)
                end,
                tooltip = { title = L["CustomBuff.Tooltip.Title"], desc = L["CustomBuff.Tooltip.Desc"] },
            })
            holder:SetPoint("TOPLEFT", 0, rowY)
            buffCheckboxesRef[key] = holder

            -- Detach button for custom buffs
            local detachBtn = CreateFrame("Button", nil, holder)
            detachBtn:SetSize(14, 14)
            detachBtn:SetPoint("LEFT", holder, "RIGHT", 4, 0)
            local detachTex = detachBtn:CreateTexture(nil, "ARTWORK")
            detachTex:SetAllPoints()
            detachTex:SetAtlas("Waypoint-MapPin-ChatIcon")
            local function UpdateDetachVis()
                if IsIconDetached(key) then
                    detachTex:SetVertexColor(1, 0.85, 0.3, 1)
                    detachTex:SetDesaturated(false)
                else
                    detachTex:SetVertexColor(0.5, 0.5, 0.5, 0.6)
                    detachTex:SetDesaturated(true)
                end
            end
            UpdateDetachVis()
            detachBtn:SetScript("OnClick", function()
                if IsIconDetached(key) then
                    ReattachIcon(key)
                else
                    DetachIcon(key)
                end
                UpdateDetachVis()
                UpdateDisplay()
            end)
            detachBtn:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(L["Options.DetachIcon"], 1, 1, 1)
                GameTooltip:AddLine(L["Options.DetachIcon.Desc"], 0.7, 0.7, 0.7, true)
                GameTooltip:Show()
            end)
            detachBtn:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            tinsert(panel.customBuffRows, holder)
            rowY = rowY - ITEM_HEIGHT
        end

        local addBtn = CreateButton(customBuffsContainer, L["CustomBuff.AddButton"], function()
            BR.Options.Modals.CustomBuff.Show(nil, RenderCustomBuffRows)
        end)
        addBtn:SetPoint("TOPLEFT", 0, rowY - ADD_BTN_GAP)
        tinsert(panel.customBuffRows, addBtn)

        customBuffsContainer:SetHeight(abs(rowY) + CUSTOM_CONTAINER_PAD)

        -- Recalculate content height when custom buffs change
        local effectiveRightY = customSectionStartY + rowY - CUSTOM_CONTAINER_PAD
        buffsContent:SetHeight(max(abs(buffsLeftY), abs(effectiveRightY)) + 4)

        return rowY
    end

    panel.RenderCustomBuffRows = RenderCustomBuffRows
    RenderCustomBuffRows()
end

BR.Options.Tabs.Buffs = { Build = Build }
