local _, BR = ...

-- ============================================================================
-- BUFF ROW FACTORY (shared)
-- ============================================================================
-- One row per tracked buff: checkbox with icon + optional ready-check toggle +
-- optional gear icon (opens per-buff dialog). Used by the All Buffs page
-- (single 2-column control panel) - extracted out of the per-buff section
-- module so both surfaces render identical rows.
--
-- Per-buff detach is managed from the Detached Icons sidebar page, not from
-- this row, since detaching is inherently a cross-category decision rather
-- than a per-buff toggle.
--
-- Group dedup: buffs sharing a `groupId` collapse into a single row whose
-- spell list / icon set is the union of the group members. Non-grouped buffs
-- get one row keyed by `buff.key`.

local L = BR.L
local Components = BR.Components

local BuffGroups = BR.BuffGroups

local GetBuffIcons = BR.Helpers.GetBuffIcons

local UpdateDisplay = BR.Display.Update

local ITEM_HEIGHT = BR.Options.Constants.ITEM_HEIGHT

local tinsert = table.insert

BR.Options.BuffRow = BR.Options.BuffRow or {}

-- Buff-specific gear icon -> dialog map. Built lazily so BR.L is populated.
local function GetSettingsActions()
    return {
        healthstone = {
            tooltip = L["Options.HealthstoneSettings"],
            note = L["Options.HealthstoneSettings.Note"],
            onClick = function()
                BR.Options.Dialogs.Healthstone.Show()
            end,
        },
        soulstone = {
            tooltip = L["Options.SoulstoneSettings"],
            note = L["Options.SoulstoneSettings.Note"],
            onClick = function()
                BR.Options.Dialogs.Soulstone.Show()
            end,
        },
        dkRunes = {
            tooltip = L["Options.RuneforgePreferences"],
            note = L["Options.RuneforgeNote"],
            onClick = function()
                BR.Options.Dialogs.Runeforge.Show()
            end,
        },
        roguePoisons = {
            tooltip = L["Options.RoguePoisonPreferences"],
            note = L["Options.RoguePoisonNote"],
            onClick = function()
                BR.Options.Dialogs.RoguePoison.Show()
            end,
        },
        petPassive = {
            tooltip = L["Options.PetPassiveSettings"],
            note = L["Options.PetPassiveSettings.Note"],
            onClick = function()
                BR.Options.Dialogs.PetPassive.Show()
            end,
        },
        pets = {
            tooltip = L["Options.PetSummonSettings"],
            note = L["Options.PetSummonSettings.Note"],
            onClick = function()
                BR.Options.Dialogs.PetSummon.Show()
            end,
        },
        delveFood = {
            tooltip = L["Options.DelveFoodSettings"],
            note = L["Options.DelveFoodSettings.Note"],
            onClick = function()
                BR.Options.Dialogs.DelveFood.Show()
            end,
        },
        bronze = {
            tooltip = L["Options.BronzeSettings"],
            note = L["Options.BronzeSettings.Note"],
            onClick = function()
                BR.Options.Dialogs.Bronze.Show()
            end,
        },
    }
end

local function CreateBuffRow(parent, x, y, icons, key, displayName, infoTooltip, readyCheckOnly, freeConsumable)
    local settingsActions = GetSettingsActions()
    local holder = Components.Checkbox(parent, {
        label = displayName,
        icons = icons,
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

    local settings = settingsActions[key]
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

    return y - ITEM_HEIGHT
end

-- Merge per-buff icon lists from every member of a group, deduped, in declared order.
local function MergeGroupIcons(group)
    local merged = {}
    local seen = {}
    for _, buff in ipairs(group) do
        for _, icon in ipairs(GetBuffIcons(buff)) do
            if not seen[icon] then
                seen[icon] = true
                tinsert(merged, icon)
            end
        end
    end
    return merged
end

local function RenderBuffArray(parent, x, y, buffArray)
    -- Bucket grouped buffs so the row factory sees one logical entry per groupId.
    local groupMembers = {}
    for _, buff in ipairs(buffArray) do
        if buff.groupId then
            groupMembers[buff.groupId] = groupMembers[buff.groupId] or {}
            tinsert(groupMembers[buff.groupId], buff)
        end
    end

    local seenGroups = {}
    for _, buff in ipairs(buffArray) do
        if buff.groupId then
            if not seenGroups[buff.groupId] then
                seenGroups[buff.groupId] = true
                local members = groupMembers[buff.groupId]
                local groupInfo = BuffGroups[buff.groupId]
                local readyCheckOnly = false
                local freeConsumable = false
                for _, m in ipairs(members) do
                    if m.readyCheckOnly then
                        readyCheckOnly = true
                    end
                    if m.freeConsumable then
                        freeConsumable = true
                    end
                end
                y = CreateBuffRow(
                    parent,
                    x,
                    y,
                    MergeGroupIcons(members),
                    buff.groupId,
                    groupInfo and groupInfo.displayName or buff.name,
                    buff.infoTooltip,
                    readyCheckOnly,
                    freeConsumable
                )
            end
        else
            y = CreateBuffRow(
                parent,
                x,
                y,
                GetBuffIcons(buff),
                buff.key,
                buff.name,
                buff.infoTooltip,
                buff.readyCheckOnly,
                buff.freeConsumable
            )
        end
    end

    return y
end

BR.Options.BuffRow.Render = RenderBuffArray
BR.Options.BuffRow.CreateRow = CreateBuffRow
