local _, BR = ...

-- ============================================================================
-- OPTIONS PANEL
-- ============================================================================
-- Simplified 3-tab layout: Buffs, Display/Behavior, Settings

-- Lua stdlib locals
local floor, max, min, abs = math.floor, math.max, math.min, math.abs
local tinsert, tsort, tremove = table.insert, table.sort, table.remove

-- Aliases from BR namespace
local Components = BR.Components
local CreateButton = BR.CreateButton
local CreatePanel = BR.CreatePanel
local CreateSectionHeader = BR.CreateSectionHeader
local CreateBuffIcon = BR.CreateBuffIcon
local StyleEditBox = BR.StyleEditBox

-- Shared constants
local TEXCOORD_INSET = BR.TEXCOORD_INSET
local DEFAULT_BORDER_SIZE = BR.DEFAULT_BORDER_SIZE
local OPTIONS_BASE_SCALE = BR.OPTIONS_BASE_SCALE

-- Buff tables
local BUFF_TABLES = BR.BUFF_TABLES
local BuffGroups = BR.BuffGroups

-- Local aliases for buff arrays
local RaidBuffs = BUFF_TABLES.raid
local PresenceBuffs = BUFF_TABLES.presence
local TargetedBuffs = BUFF_TABLES.targeted
local SelfBuffs = BUFF_TABLES.self
local PetBuffs = BUFF_TABLES.pet
local Consumables = BUFF_TABLES.consumable

-- Glow module
local Glow = BR.Glow
local GlowTypes = Glow.Types

-- Export references from BuffReminders.lua
local defaults = BR.defaults
local LSM = BR.LSM

-- Helper function aliases
local GetCategorySettings = BR.Helpers.GetCategorySettings
local IsCategorySplit = BR.Helpers.IsCategorySplit
local GetBuffTexture = BR.Helpers.GetBuffTexture
local ValidateSpellID = BR.Helpers.ValidateSpellID
local ValidateItemID = BR.Helpers.ValidateItemID
local GenerateCustomBuffKey = BR.Helpers.GenerateCustomBuffKey

-- Display function aliases
local UpdateDisplay = BR.Display.Update
local ToggleTestMode = BR.Display.ToggleTestMode
local UpdateVisuals = BR.Display.UpdateVisuals
local ResetCategoryFramePosition = BR.Display.ResetCategoryFramePosition
local ReparentBuffFrames = BR.CallbackRegistry.TriggerEvent
        and function()
            BR.CallbackRegistry:TriggerEvent("FramesReparent")
        end
    or function() end

-- Masque state
local IsMasqueActive = BR.Masque and BR.Masque.IsActive or function()
    return false
end

-- Custom buff management
local CreateCustomBuffFrameRuntime = BR.CustomBuffs.CreateRuntime
local RemoveCustomBuffFrame = BR.CustomBuffs.Remove
local UpdateCustomBuffFrame = BR.CustomBuffs.UpdateFrame

-- Module-level variables
local optionsPanel = nil
local customBuffModal = nil

-- Forward declarations
local ShowGlowAdvanced, ShowCustomBuffModal

-- ============================================================================
-- CONSTANTS
-- ============================================================================

local PANEL_WIDTH = 540
local COL_PADDING = 20
local SECTION_SPACING = 12
local ITEM_HEIGHT = 22
local SCROLLBAR_WIDTH = 24

-- Vertical layout spacing constants
local COMPONENT_GAP = 4 -- Standard gap between components
local SECTION_GAP = 8 -- Gap before/after section boundaries
local DROPDOWN_EXTRA = 8 -- Extra clearance after dropdowns (menu overlay space)

local CATEGORY_ORDER = { "raid", "presence", "targeted", "self", "pet", "consumable", "custom" }
local CATEGORY_LABELS = {
    raid = "團隊增益",
    presence = "在場增益",
    targeted = "目標增益",
    self = "自身增益",
    pet = "寵物提醒",
    consumable = "消耗品",
    custom = "自訂增益",
}

-- Layout-aware section header (uses VerticalLayout instead of manual Y tracking)
local function LayoutSectionHeader(layout, parent, text)
    local header = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetText("|cffffcc00" .. text .. "|r")
    layout:AddText(header, 14, COMPONENT_GAP)
    return header
end

-- ============================================================================
-- OPTIONS PANEL
-- ============================================================================

local function CreateOptionsPanel()
    local panel = CreatePanel("BuffRemindersOptions", PANEL_WIDTH, 640, { escClose = true })
    panel:Hide()

    -- Forward declarations for banner system
    local UpdateBannerLayout
    local masqueBanner

    -- Track all EditBoxes so we can clear focus when panel hides
    local panelEditBoxes = {}
    Components.SetEditBoxesRef(panelEditBoxes)
    panel:SetScript("OnHide", function()
        for _, editBox in ipairs(panelEditBoxes) do
            editBox:ClearFocus()
        end
    end)

    -- Refresh all component values from DB when panel opens (OnShow pattern)
    panel:SetScript("OnShow", function()
        Components.RefreshAll()
        UpdateBannerLayout()
    end)

    -- Title (inline with tab row)
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", COL_PADDING, -10)
    title:SetText("|cffffffff增益|r|cffffcc00提醒|r")

    -- Version (next to title, smaller font)
    local version = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 6, 0)
    local addonVersion = C_AddOns.GetAddOnMetadata("BuffReminders", "版本") or ""
    version:SetText(addonVersion)

    -- Discord link (next to version)
    local discordSep = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    discordSep:SetPoint("LEFT", version, "RIGHT", 6, 0)
    discordSep:SetText("|cff555555·|r")

    local discordLink = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    discordLink:SetPoint("LEFT", discordSep, "RIGHT", 6, 0)
    discordLink:SetText("|cff7289da加入Discord|r")

    local discordHit = CreateFrame("Button", nil, panel)
    discordHit:SetAllPoints(discordLink)
    discordHit:SetScript("OnClick", function()
        StaticPopup_Show("BUFFREMINDERS_DISCORD_URL")
    end)
    discordHit:SetScript("OnEnter", function()
        discordLink:SetText("|cff99aaff加入Discord|r")
        BR.ShowTooltip(
            discordHit,
            "點擊取得邀請連結",
            "取得反饋、功能建議或者錯誤回報？\n加入到Discord!",
            "ANCHOR_BOTTOM"
        )
    end)
    discordHit:SetScript("OnLeave", function()
        discordLink:SetText("|cff7289da加入Discord|r")
        BR.HideTooltip()
    end)

    -- Scale controls (top right area) - text link style: < 100% >
    local BASE_SCALE = OPTIONS_BASE_SCALE
    local MIN_PCT, MAX_PCT = 80, 150

    local currentScale = BR.profile.optionsPanelScale or BASE_SCALE
    local currentPct = floor(currentScale / BASE_SCALE * 100 + 0.5)

    -- Close button
    local closeBtn = CreateButton(panel, "x", function()
        panel:Hide()
    end)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", -5, -5)

    local scaleHolder = CreateFrame("Frame", nil, panel)
    scaleHolder:SetPoint("RIGHT", closeBtn, "LEFT", -8, 0)
    scaleHolder:SetSize(60, 16)

    local scaleDown = scaleHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleDown:SetPoint("LEFT", 0, 0)
    scaleDown:SetText("<")

    local scaleValue = scaleHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleValue:SetPoint("LEFT", scaleDown, "RIGHT", 4, 0)
    scaleValue:SetText(currentPct .. "%")

    local scaleUp = scaleHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    scaleUp:SetPoint("LEFT", scaleValue, "RIGHT", 4, 0)
    scaleUp:SetText(">")

    local function UpdateScaleText()
        local pct = floor((BR.profile.optionsPanelScale or BASE_SCALE) / BASE_SCALE * 100 + 0.5)
        scaleValue:SetText(pct .. "%")
        scaleDown:SetTextColor(pct > MIN_PCT and 1 or 0.4, pct > MIN_PCT and 1 or 0.4, pct > MIN_PCT and 1 or 0.4)
        scaleUp:SetTextColor(pct < MAX_PCT and 1 or 0.4, pct < MAX_PCT and 1 or 0.4, pct < MAX_PCT and 1 or 0.4)
    end

    local function UpdateScale(delta)
        local oldPct = floor((BR.profile.optionsPanelScale or BASE_SCALE) / BASE_SCALE * 100 + 0.5)
        local newPct = max(MIN_PCT, min(MAX_PCT, oldPct + delta))
        local newScale = newPct / 100 * BASE_SCALE
        BR.profile.optionsPanelScale = newScale
        panel:SetScale(newScale)
        UpdateScaleText()
    end

    -- Clickable regions for < and >
    local downBtn = CreateFrame("Button", nil, scaleHolder)
    downBtn:SetAllPoints(scaleDown)
    downBtn:SetScript("OnClick", function()
        UpdateScale(-10)
    end)
    downBtn:SetScript("OnEnter", function()
        if currentPct > MIN_PCT then
            scaleDown:SetTextColor(1, 0.82, 0)
        end
    end)
    downBtn:SetScript("OnLeave", function()
        UpdateScaleText()
    end)

    local upBtn = CreateFrame("Button", nil, scaleHolder)
    upBtn:SetAllPoints(scaleUp)
    upBtn:SetScript("OnClick", function()
        UpdateScale(10)
    end)
    upBtn:SetScript("OnEnter", function()
        local pct = floor((BR.profile.optionsPanelScale or BASE_SCALE) / BASE_SCALE * 100 + 0.5)
        if pct < MAX_PCT then
            scaleUp:SetTextColor(1, 0.82, 0)
        end
    end)
    upBtn:SetScript("OnLeave", function()
        UpdateScaleText()
    end)

    UpdateScaleText()

    if BR.profile.optionsPanelScale then
        panel:SetScale(BR.profile.optionsPanelScale)
    end

    -- ========== TABS ==========
    local tabButtons = {}
    local contentContainers = {}
    local TAB_HEIGHT = 22
    local activeTabName = "buffs"

    local function SetActiveTab(tabName)
        activeTabName = tabName
        for name, tab in pairs(tabButtons) do
            tab:SetActive(name == tabName)
        end
        for name, container in pairs(contentContainers) do
            if name == tabName then
                container:Show()
            else
                container:Hide()
            end
        end
        if masqueBanner then
            masqueBanner:Refresh()
            UpdateBannerLayout()
        end
    end

    -- Create 4 tabs: Buffs, Display & Behavior, Settings, Import/Export
    tabButtons.buffs = Components.Tab(panel, { name = "buffs", label = "增益", width = 50 })
    tabButtons.displayBehavior =
        Components.Tab(panel, { name = "displayBehavior", label = "顯示/行為", width = 110 })
    tabButtons.settings = Components.Tab(panel, { name = "settings", label = "設定", width = 65 })
    tabButtons.profiles = Components.Tab(panel, { name = "profiles", label = "設定檔", width = 65 })

    -- Position tabs below title
    tabButtons.buffs:SetPoint("TOPLEFT", panel, "TOPLEFT", COL_PADDING, -30)
    tabButtons.displayBehavior:SetPoint("LEFT", tabButtons.buffs, "RIGHT", 2, 0)
    tabButtons.settings:SetPoint("LEFT", tabButtons.displayBehavior, "RIGHT", 2, 0)
    tabButtons.profiles:SetPoint("LEFT", tabButtons.settings, "RIGHT", 2, 0)

    for name, tab in pairs(tabButtons) do
        tab:SetScript("OnClick", function()
            SetActiveTab(name)
        end)
    end

    -- Separator line below tabs
    local tabSeparator = panel:CreateTexture(nil, "ARTWORK")
    tabSeparator:SetHeight(1)
    tabSeparator:SetPoint("TOPLEFT", COL_PADDING, -30 - TAB_HEIGHT)
    tabSeparator:SetPoint("TOPRIGHT", -COL_PADDING, -30 - TAB_HEIGHT)
    tabSeparator:SetColorTexture(0.3, 0.3, 0.3, 1)

    -- ========== CONTENT CONTAINERS ==========
    local CONTENT_TOP = -30 - TAB_HEIGHT - 10

    -- Helper to create a scrollable content container using Components
    local function CreateScrollableContent(name)
        local scrollFrame, content = Components.ScrollableContainer(panel, {
            contentHeight = 600,
            scrollbarWidth = SCROLLBAR_WIDTH,
        })
        scrollFrame:SetPoint("TOPLEFT", 0, CONTENT_TOP)
        scrollFrame:SetPoint("BOTTOMRIGHT", 0, 46)
        scrollFrame:Hide()

        contentContainers[name] = scrollFrame
        return content, scrollFrame
    end

    -- ========== BANNERS ==========
    local BANNER_HEIGHT = 28
    local BANNER_TOP_GAP = 6
    local BANNER_BOTTOM_GAP = 0

    masqueBanner = Components.Banner(panel, {
        text = "縮放以及邊框設定是由Masque所管理",
        icon = "QuestNormal",
        color = "orange",
        visible = function()
            return IsMasqueActive() and activeTabName == "displayBehavior"
        end,
    })

    UpdateBannerLayout = function()
        local bannerY = -30 - TAB_HEIGHT - BANNER_TOP_GAP
        local bannerOffset = 0

        if masqueBanner:IsShown() then
            masqueBanner:ClearAllPoints()
            masqueBanner:SetPoint("TOPLEFT", panel, "TOPLEFT", COL_PADDING, bannerY)
            masqueBanner:SetPoint("RIGHT", panel, "RIGHT", -COL_PADDING, 0)
            bannerOffset = bannerOffset + BANNER_HEIGHT + BANNER_BOTTOM_GAP
        end

        local newTop = CONTENT_TOP - bannerOffset
        for _, container in pairs(contentContainers) do
            container:ClearAllPoints()
            container:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, newTop)
            if container.GetContentFrame then
                container:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 46)
            end
        end
    end

    -- Store buff checkboxes for refresh
    panel.buffCheckboxes = {}

    -- ========== HELPER FUNCTIONS ==========

    -- Resolve icon textures from displayIcon texture IDs or spell IDs
    local function ResolveBuffIcons(displayIcon, spellIDs)
        if displayIcon then
            -- Use override textures directly
            if type(displayIcon) == "table" then
                return displayIcon
            else
                return { displayIcon }
            end
        elseif spellIDs then
            -- Look up textures from spell IDs (deduplicated)
            local icons = {}
            local seenTextures = {}
            local spellList = type(spellIDs) == "table" and spellIDs or { spellIDs }
            for _, spellID in ipairs(spellList) do
                local texture = GetBuffTexture(spellID)
                if texture and not seenTextures[texture] then
                    seenTextures[texture] = true
                    tinsert(icons, texture)
                end
            end
            return #icons > 0 and icons or nil
        end
        return nil
    end

    -- Create buff checkbox using Components.Checkbox
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
        panel.buffCheckboxes[key] = holder

        -- Inline toggle: "Ready check only" / "Always show" (replaces info tooltip icon)
        -- Skip for free consumables — controlled by the "Free consumables" dropdown instead
        if readyCheckOnly and not freeConsumable then
            local function GetReadyCheckOnlyState()
                local overrides = BR.profile.readyCheckOnlyOverrides
                return not overrides or overrides[key] ~= false
            end

            local function ToggleLabel(checked)
                return checked and "準備確認" or "永遠顯示"
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
                        -- Ready check only (default): remove override
                        BR.Config.Set("readyCheckOnlyOverrides." .. key, nil)
                    else
                        -- Always show: store explicit false
                        BR.Config.Set("readyCheckOnlyOverrides." .. key, false)
                    end
                    toggle.label:SetText(ToggleLabel(checked))
                end,
            })
            -- Also update label text on Refresh (wrap original Refresh)
            local origRefresh = toggle.Refresh
            function toggle:Refresh()
                origRefresh(self)
                self.label:SetText(ToggleLabel(GetReadyCheckOnlyState()))
            end
            toggle:SetPoint("LEFT", holder.label, "RIGHT", 6, 0)
        end

        return y - ITEM_HEIGHT
    end

    -- ========== BUFFS TAB (Two-Column Layout) ==========
    local buffsContent, _ = CreateScrollableContent("buffs")

    -- Render checkboxes for a buff array (single column within each side)
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
                    local displayList = type(buff.displaySpells) == "table" and buff.displaySpells
                        or { buff.displaySpells }
                    for _, id in ipairs(displayList) do
                        tinsert(groupDisplaySpells[buff.groupId], id)
                    end
                end
                -- Resolve display icon(s) per entry: displayIcon > displaySpells > primary spellID
                -- Deduplicate icons within the same group (e.g., MH + OH weapon buffs share icons)
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
                    local displayList = type(buff.displaySpells) == "table" and buff.displaySpells
                        or { buff.displaySpells }
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

    -- Column layout constants
    local COL_WIDTH = (PANEL_WIDTH - COL_PADDING * 3) / 2
    local buffsLeftX = COL_PADDING
    local buffsRightX = COL_PADDING + COL_WIDTH + COL_PADDING
    local buffsLeftY = -6
    local buffsRightY = -6

    -- LEFT COLUMN: Group-wide buffs
    -- Raid Buffs
    _, buffsLeftY = CreateSectionHeader(buffsContent, "團隊增益", buffsLeftX, buffsLeftY)
    local raidNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    raidNote:SetPoint("TOPLEFT", buffsLeftX, buffsLeftY)
    raidNote:SetText("(為整個團隊)")
    buffsLeftY = buffsLeftY - 14
    buffsLeftY = RenderBuffCheckboxes(buffsContent, buffsLeftX, buffsLeftY, RaidBuffs)
    buffsLeftY = buffsLeftY - SECTION_SPACING

    -- Targeted Buffs
    _, buffsLeftY = CreateSectionHeader(buffsContent, "目標增益", buffsLeftX, buffsLeftY)
    local targetedNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    targetedNote:SetPoint("TOPLEFT", buffsLeftX, buffsLeftY)
    targetedNote:SetText("(針對他人的增益)")
    buffsLeftY = buffsLeftY - 14
    buffsLeftY = RenderBuffCheckboxes(buffsContent, buffsLeftX, buffsLeftY, TargetedBuffs)
    buffsLeftY = buffsLeftY - SECTION_SPACING

    -- Consumables
    _, buffsLeftY = CreateSectionHeader(buffsContent, "消耗品", buffsLeftX, buffsLeftY)
    local consumablesNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    consumablesNote:SetPoint("TOPLEFT", buffsLeftX, buffsLeftY)
    consumablesNote:SetText("(精鍊、食物、符文、油)")
    buffsLeftY = buffsLeftY - 14
    buffsLeftY = RenderBuffCheckboxes(buffsContent, buffsLeftX, buffsLeftY, Consumables)

    -- RIGHT COLUMN: Individual buffs
    -- Presence Buffs
    _, buffsRightY = CreateSectionHeader(buffsContent, "職業增益", buffsRightX, buffsRightY)
    local presenceNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    presenceNote:SetPoint("TOPLEFT", buffsRightX, buffsRightY)
    presenceNote:SetText("(至少1人需要)")
    buffsRightY = buffsRightY - 14
    buffsRightY = RenderBuffCheckboxes(buffsContent, buffsRightX, buffsRightY, PresenceBuffs)
    buffsRightY = buffsRightY - SECTION_SPACING

    -- Self Buffs
    _, buffsRightY = CreateSectionHeader(buffsContent, "自身增益", buffsRightX, buffsRightY)
    local selfNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    selfNote:SetPoint("TOPLEFT", buffsRightX, buffsRightY)
    selfNote:SetText("(完全為你自己的增益)")
    buffsRightY = buffsRightY - 14
    buffsRightY = RenderBuffCheckboxes(buffsContent, buffsRightX, buffsRightY, SelfBuffs)
    buffsRightY = buffsRightY - SECTION_SPACING

    -- Pet Reminders
    _, buffsRightY = CreateSectionHeader(buffsContent, "寵物提醒", buffsRightX, buffsRightY)
    local petNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    petNote:SetPoint("TOPLEFT", buffsRightX, buffsRightY)
    petNote:SetText("(寵物召喚提醒)")
    buffsRightY = buffsRightY - 14
    buffsRightY = RenderBuffCheckboxes(buffsContent, buffsRightX, buffsRightY, PetBuffs)
    buffsRightY = buffsRightY - SECTION_SPACING

    -- Custom Buffs (right column)
    _, buffsRightY = CreateSectionHeader(buffsContent, "自訂增益", buffsRightX, buffsRightY)
    panel.customBuffRows = {}

    local customNote = buffsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    customNote:SetPoint("TOPLEFT", buffsRightX, buffsRightY)
    customNote:SetText("(透過法術ID追蹤任何增益/發光)")
    buffsRightY = buffsRightY - 14

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

            -- Use Components.Checkbox for consistent styling
            local holder = Components.Checkbox(customBuffsContainer, {
                label = customBuff.name or ("Spell " .. tostring(customBuff.spellID)),
                icons = ResolveBuffIcons(nil, customBuff.spellID),
                get = function()
                    return BR.profile.enabledBuffs[key] ~= false
                end,
                onChange = function(checked)
                    BR.profile.enabledBuffs[key] = checked
                    UpdateDisplay()
                end,
                onRightClick = function()
                    ShowCustomBuffModal(key, RenderCustomBuffRows)
                end,
                tooltip = { title = "自訂增益", desc = "右鍵點擊來編輯或刪除" },
            })
            holder:SetPoint("TOPLEFT", 0, rowY)
            panel.buffCheckboxes[key] = holder

            tinsert(panel.customBuffRows, holder)
            rowY = rowY - ITEM_HEIGHT
        end

        local addBtn = CreateButton(customBuffsContainer, "+ 新增自訂增益", function()
            ShowCustomBuffModal(nil, RenderCustomBuffRows)
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

    -- ========== DISPLAY/BEHAVIOR TAB ==========
    local displayBehaviorContent, _ = CreateScrollableContent("displayBehavior")
    local displayBehaviorX = COL_PADDING
    local displayBehaviorLayout = Components.VerticalLayout(displayBehaviorContent, { x = displayBehaviorX, y = -10 })

    -- Global Defaults section
    LayoutSectionHeader(displayBehaviorLayout, displayBehaviorContent, "整體預設")

    local defNote = displayBehaviorContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    displayBehaviorLayout:AddText(defNote, 12, COMPONENT_GAP)
    defNote:SetText("(所有類別都會繼承這些設定，除非被覆蓋。)")

    local function isDefDimensionsLinked()
        local db = BR.profile.defaults
        return not db or db.iconWidth == nil
    end

    local defGrid = Components.AppearanceGrid(displayBehaviorContent, {
        get = function(key, default)
            local d = BR.profile.defaults
            return d and d[key] or default
        end,
        set = function(key, value)
            BR.Config.Set("defaults." .. key, value)
        end,
        setMulti = function(changes)
            local prefixed = {}
            for k, v in pairs(changes) do
                prefixed["defaults." .. k] = v
            end
            BR.Config.SetMulti(prefixed)
        end,
        isLinked = isDefDimensionsLinked,
        onLink = function()
            BR.Config.Set("defaults.iconWidth", nil)
            Components.RefreshAll()
        end,
        onUnlink = function()
            local db = BR.profile.defaults
            BR.Config.Set("defaults.iconWidth", db and db.iconSize or 64)
            Components.RefreshAll()
        end,
        masqueCheck = IsMasqueActive,
    })
    displayBehaviorLayout:Add(defGrid.frame, defGrid.height, COMPONENT_GAP)

    -- Font dropdown (global setting, uses LibSharedMedia)
    local function BuildFontOptions()
        local fontList = LSM:List("font")
        local opts = { { label = "預設", value = nil } }
        for _, name in ipairs(fontList) do
            tinsert(opts, { label = name, value = name })
        end
        return opts
    end

    local defFontHolder = Components.Dropdown(displayBehaviorContent, {
        label = "字體",
        labelWidth = 50,
        options = BuildFontOptions(),
        width = 200,
        maxItems = 15,
        itemInit = function(_, itemLabel, opt)
            if opt.value then
                local path = LSM:Fetch("font", opt.value)
                if path then
                    itemLabel:SetFont(path, 12, "")
                end
            end
        end,
        get = function()
            return BR.profile.defaults and BR.profile.defaults.fontFace or nil
        end,
        onChange = function(val)
            BR.Config.Set("defaults.fontFace", val)
        end,
    })
    displayBehaviorLayout:Add(defFontHolder, nil, COMPONENT_GAP)

    local defDirHolder = Components.DirectionButtons(displayBehaviorContent, {
        labelWidth = 50,
        get = function()
            return BR.profile.defaults and BR.profile.defaults.growDirection or "CENTER"
        end,
        onChange = function(dir)
            BR.Config.Set("defaults.growDirection", dir)
        end,
    })
    displayBehaviorLayout:Add(defDirHolder, nil, COMPONENT_GAP + DROPDOWN_EXTRA)

    local defGlowHolder = Components.Checkbox(displayBehaviorContent, {
        label = "提醒圖示發光",
        tooltip = {
            title = "提醒圖示發光",
            desc = "為所有可見的提醒圖示新增發光效果，包括缺少和過期的增益效果。",
        },
        get = function()
            return BR.profile.defaults and BR.profile.defaults.showExpirationGlow ~= false
        end,
        onChange = function(checked)
            BR.Config.Set("defaults.showExpirationGlow", checked)
            Components.RefreshAll()
        end,
    })

    local glowSettingsBtn = CreateButton(displayBehaviorContent, "Customize", function()
        ShowGlowAdvanced()
    end)
    glowSettingsBtn:SetPoint("LEFT", defGlowHolder.label, "RIGHT", 8, 0)
    glowSettingsBtn:SetFrameLevel(defGlowHolder:GetFrameLevel() + 5)

    displayBehaviorLayout:Add(defGlowHolder, nil, COMPONENT_GAP)

    -- Expiration Reminder section
    displayBehaviorLayout:Space(8)
    LayoutSectionHeader(displayBehaviorLayout, displayBehaviorContent, "過期提醒")
    displayBehaviorLayout:Space(COMPONENT_GAP)

    local defThresholdHolder = Components.Slider(displayBehaviorContent, {
        label = "閥值",
        min = 0,
        max = 45,
        step = 5,
        get = function()
            return BR.profile.defaults and BR.profile.defaults.expirationThreshold or 15
        end,
        formatValue = function(val)
            return val == 0 and "Off" or (val .. " 分")
        end,
        onChange = function(val)
            BR.Config.Set("defaults.expirationThreshold", val)
        end,
    })
    displayBehaviorLayout:Add(defThresholdHolder, nil, COMPONENT_GAP)

    -- Per-Category Customization section
    displayBehaviorLayout:Space(8)
    LayoutSectionHeader(displayBehaviorLayout, displayBehaviorContent, "按類別自訂")
    displayBehaviorLayout:Space(COMPONENT_GAP)

    -- Create collapsible sections that chain-anchor to each other
    local categorySections = {}
    local previousSection = nil

    local function UpdateAppearanceContentHeight()
        -- Calculate total height: fixed header area + all collapsible sections
        local totalHeight = abs(displayBehaviorLayout:GetY())
        for _, sec in ipairs(categorySections) do
            totalHeight = totalHeight + sec:GetHeight() + 4
        end
        displayBehaviorContent:SetHeight(totalHeight)
    end

    local SECTION_SCROLLBAR_OFFSET = COL_PADDING
    for _, category in ipairs(CATEGORY_ORDER) do
        local section = Components.CollapsibleSection(displayBehaviorContent, {
            title = CATEGORY_LABELS[category],
            defaultCollapsed = true,
            scrollbarOffset = SECTION_SCROLLBAR_OFFSET,
            onToggle = function()
                -- Defer layout update to next frame
                C_Timer.After(0, UpdateAppearanceContentHeight)
            end,
        })

        if previousSection then
            section:SetPoint("TOPLEFT", previousSection, "BOTTOMLEFT", 0, -4)
        else
            section:SetPoint("TOPLEFT", displayBehaviorX, displayBehaviorLayout:GetY())
        end

        local catContent = section:GetContentFrame()
        local catLayout = Components.VerticalLayout(catContent, { x = 0, y = 0 })

        local db = BR.profile

        -- W/S/D/R content visibility + ready check (not for custom — custom uses per-buff loadConditions)
        if category ~= "custom" then
            local function OnCategoryVisibilityChange()
                UpdateDisplay()
            end

            local visToggles = Components.VisibilityToggles(catContent, {
                category = category,
                onChange = function()
                    OnCategoryVisibilityChange()
                    Components.RefreshAll()
                end,
            })
            catLayout:Add(visToggles, nil, SECTION_GAP)

            local hideInPvPMatchHolder = Components.Checkbox(catContent, {
                label = "PvP比賽開始時隱藏",
                get = function()
                    local vis = db.categoryVisibility and db.categoryVisibility[category]
                    return vis and vis.hideInPvPMatch or false
                end,
                enabled = function()
                    local vis = db.categoryVisibility and db.categoryVisibility[category]
                    return not vis or vis.pvp ~= false
                end,
                tooltip = {
                    title = "PvP比賽開始時隱藏",
                    desc = "Hide this category once a PvP match begins (after prep phase ends).",
                },
                onChange = function(checked)
                    if not db.categoryVisibility then
                        db.categoryVisibility = {}
                    end
                    if not db.categoryVisibility[category] then
                        db.categoryVisibility[category] = {
                            openWorld = true,
                            scenario = true,
                            dungeon = true,
                            raid = true,
                            housing = false,
                            pvp = true,
                            hideInPvPMatch = true,
                        }
                    end
                    db.categoryVisibility[category].hideInPvPMatch = checked
                    OnCategoryVisibilityChange()
                end,
            })
            catLayout:Add(hideInPvPMatchHolder, nil, COMPONENT_GAP)

            local readyCheckHolder = Components.Checkbox(catContent, {
            label = "只在準備確認時顯示",
                get = function()
                    local cs = db.categorySettings and db.categorySettings[category]
                    return cs and cs.showOnlyOnReadyCheck == true
                end,
                tooltip = {
                title = "只在準備確認時顯示",
                desc = "準備檢查開始後僅顯示該類別的增益效果15秒",
                },
                onChange = function(checked)
                    BR.Config.Set("categorySettings." .. category .. ".showOnlyOnReadyCheck", checked)
                end,
            })
            catLayout:Add(readyCheckHolder, nil, COMPONENT_GAP)

            -- Free consumables sub-section (consumable category only)
            if category == "consumable" then
                local function EnsureFreeVisibility()
                    if not db.defaults then
                        db.defaults = {}
                    end
                    if not db.defaults.freeConsumableVisibility then
                        db.defaults.freeConsumableVisibility = {
                            openWorld = false,
                            scenario = true,
                            dungeon = true,
                            raid = true,
                            housing = false,
                            pvp = true,
                        }
                    end
                    return db.defaults.freeConsumableVisibility
                end
                catLayout:Space(SECTION_GAP)
                local hsHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                hsHeader:SetText("|cffffcc00Healthstone|r")
                catLayout:AddText(hsHeader, 12, COMPONENT_GAP)

                local hsReadyCheckHolder = Components.Dropdown(catContent, {
                    label = "可視性",
                    width = 180,
                    get = function()
                        return BR.Config.Get("defaults.healthstoneVisibility", "readyCheck")
                    end,
                    options = {
                        {
                            value = "readyCheck",
                            label = "只限準備確認",
                            desc = "準備確認開始後顯示15秒",
                        },
                        {
                            value = "casterOnly",
                            label = "準備確認 + 術士永遠顯示",
                            desc = "術士總是看到提醒；其他職業只在準備確認時",
                        },
                        {
                            value = "always",
                            label = "永遠顯示",
                            desc = "每當內容類型相符時顯示",
                        },
                    },
                    tooltip = {
                        title = "治療石可視性",
                        desc = "控制治療石提醒何時出現。\n\n|cffffcc00只限準備確認:|r 只有在準備確認期間 (15秒視窗)。\n|cffffcc00準備確認 + 術士永遠顯示:|r 術士總是看到提醒；其他職業只在準備確認時。\n|cffffcc00永遠顯示:|r 當你與內容相符時顯示。",
                    },
                    onChange = function(val)
                        BR.Config.Set("defaults.healthstoneVisibility", val)
                    end,
                })
                catLayout:Add(hsReadyCheckHolder, nil, COMPONENT_GAP)

                catLayout:Space(SECTION_GAP)
                local freeHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                freeHeader:SetText("|cffffcc00免費消耗品|r")
                catLayout:AddText(freeHeader, 12, COMPONENT_GAP)
                local freeNote = catContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                freeNote:SetText("(治療石，永久增強符文)")
                catLayout:AddText(freeNote, 10, COMPONENT_GAP)

                local function IsFreeOverride()
                    return BR.Config.Get("defaults.freeConsumableMode", "override") == "override"
                end

                local freeOverrideHolder = Components.Checkbox(catContent, {
                    label = "覆蓋內容過濾器",
                    get = function()
                        return IsFreeOverride()
                    end,
                    tooltip = {
                        title = "覆蓋內容過濾器",
                        desc = "勾選後，免費消耗品將使用下面自己的內容類型可見性設定。\n\n未選取時，它們遵循與其他消耗品相同的內容過濾器。",
                    },
                    onChange = function(checked)
                        BR.Config.Set("defaults.freeConsumableMode", checked and "override" or "follow")
                        Components.RefreshAll()
                    end,
                })
                catLayout:Add(freeOverrideHolder, nil, COMPONENT_GAP)

                -- Override controls (indented under checkbox)
                local INDENT = 12
                catLayout:SetX(catLayout:GetX() + INDENT)

                local freeVisToggles = Components.VisibilityToggles(catContent, {
                    store = {
                        getContent = function(key)
                            local vis = db.defaults and db.defaults.freeConsumableVisibility
                            return not vis or vis[key] ~= false
                        end,
                        setContent = function(key)
                            local vis = EnsureFreeVisibility()
                            vis[key] = not vis[key]
                        end,
                        getDiffTable = function(dbKey)
                            local vis = db.defaults and db.defaults.freeConsumableVisibility
                            return vis and vis[dbKey]
                        end,
                        ensureDiffTable = function(dbKey)
                            local vis = EnsureFreeVisibility()
                            if not vis[dbKey] then
                                vis[dbKey] = {} ---@diagnostic disable-line: assign-type-mismatch
                            end
                            return vis[dbKey]
                        end,
                    },
                    noAutoRefresh = true,
                    onChange = function()
                        UpdateDisplay()
                    end,
                })
                local origVisRefresh = freeVisToggles.Refresh
                function freeVisToggles:Refresh()
                    origVisRefresh(self)
                    local enabled = IsFreeOverride()
                    self:SetAlpha(enabled and 1 or 0.4)
                    for _, btn in ipairs(self.allToggleButtons) do
                        btn:EnableMouse(enabled)
                    end
                end
                tinsert(BR.RefreshableComponents, freeVisToggles)
                catLayout:Add(freeVisToggles, nil, COMPONENT_GAP)

                catLayout:SetX(catLayout:GetX() - INDENT)
                catLayout:Space(SECTION_GAP)
            end
        else
            local banner = Components.Banner(catContent, {
                text = "可見性與準備確認設定移動到每個增益的編輯選單中。",
                color = "orange",
                icon = "services-icon-warning",
            })
            catLayout:Add(banner, nil, SECTION_GAP)
            banner:SetPoint("RIGHT", catContent, "RIGHT", 0, 0)
        end

        -- Icons sub-header (all categories except custom)
        if category ~= "custom" then
            local iconsHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            iconsHeader:SetText("|cffffcc00圖示|r")
            catLayout:AddText(iconsHeader, 12, COMPONENT_GAP)
        end

        -- Show text on icons (not for custom — custom buffs have per-buff missing text)
        if category ~= "custom" then
            local showTextHolder = Components.Checkbox(catContent, {
                label = "顯示文字在圖示上",
                get = function()
                    local cs = db.categorySettings and db.categorySettings[category]
                    return not cs or cs.showText ~= false
                end,
                tooltip = {
                    title = "顯示文字在圖示上",
                    desc = "在該類別的增益圖示上覆蓋顯示計數或缺少的文字",
                },
                onChange = function(checked)
                    BR.Config.Set("categorySettings." .. category .. ".showText", checked)
                end,
            })
            catLayout:Add(showTextHolder, nil, COMPONENT_GAP)
        end

        -- Missing count only (raid only)
        if category == "raid" then
            local missingCountHolder = Components.Checkbox(catContent, {
                label = "只顯示缺少計數",
                get = function()
                    return db.showMissingCountOnly == true
                end,
                tooltip = {
                    title = "只顯示缺少計數",
                    desc = '僅顯示缺少的增益數字（例如 "1"）而不是完整計數 (例如 "19/20")',
                },
                enabled = function()
                    local cs = db.categorySettings and db.categorySettings[category]
                    return not cs or cs.showText ~= false
                end,
                onChange = function(checked)
                    BR.Config.Set("showMissingCountOnly", checked)
                    Components.RefreshAll()
                end,
            })
            catLayout:Add(missingCountHolder, nil, COMPONENT_GAP)
        end

        -- "BUFF!" text (raid only, grouped under Icons)
        if category == "raid" then
            local reminderHolder = Components.Checkbox(catContent, {
                label = '顯示"BUFF!"提醒文字',
                get = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    return not cs or cs.showBuffReminder ~= false
                end,
                onChange = function(checked)
                    BR.Config.Set("categorySettings.raid.showBuffReminder", checked)
                    Components.RefreshAll()
                end,
            })
            catLayout:Add(reminderHolder, nil, COMPONENT_GAP)

            local buffTextSizeHolder = Components.NumericStepper(reminderHolder, {
                label = "大小",
                labelWidth = 28,
                min = 6,
                max = 40,
                get = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    if cs and cs.buffTextSize then
                        return cs.buffTextSize
                    end
                    -- Default: 80% of text size (matching current behavior)
                    local textSize = cs and cs.textSize
                    if not textSize then
                        local iconSize = (cs and cs.iconSize) or 64
                        textSize = floor(iconSize * 0.32)
                    end
                    return max(6, floor(textSize * 0.8))
                end,
                enabled = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    return not cs or cs.showBuffReminder ~= false
                end,
                onChange = function(val)
                    BR.Config.Set("categorySettings.raid.buffTextSize", val)
                end,
            })
            buffTextSizeHolder:SetPoint("LEFT", reminderHolder, "LEFT", 210, 0)

            local buffTextOffsetXHolder = Components.Slider(catContent, {
                label = '"BUFF!" X',
                labelWidth = 60,
                min = -40,
                max = 40,
                get = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    return (cs and cs.buffTextOffsetX) or 0
                end,
                enabled = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    return not cs or cs.showBuffReminder ~= false
                end,
                onChange = function(val)
                    BR.Config.Set("categorySettings.raid.buffTextOffsetX", val)
                end,
            })

            local buffTextOffsetYHolder = Components.Slider(catContent, {
                label = '"BUFF!" Y',
                labelWidth = 60,
                min = -40,
                max = 40,
                get = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    return (cs and cs.buffTextOffsetY) or 0
                end,
                enabled = function()
                    local cs = db.categorySettings and db.categorySettings.raid
                    return not cs or cs.showBuffReminder ~= false
                end,
                onChange = function(val)
                    BR.Config.Set("categorySettings.raid.buffTextOffsetY", val)
                end,
            })

            buffTextOffsetYHolder:SetPoint("LEFT", buffTextOffsetXHolder, "LEFT", 210, 0)
            catLayout:Add(buffTextOffsetXHolder, nil, COMPONENT_GAP)
        end

        -- Click to cast checkbox
        if category ~= "custom" then
            local clickableHolder = Components.Checkbox(catContent, {
                label = "點擊來施放",
                get = function()
                    local cs = db.categorySettings and db.categorySettings[category]
                    return cs and cs.clickable == true
                end,
                tooltip = {
                    title = "點擊來施放",
                    desc = "使增益圖示可點擊以施放對應的法術（僅限非戰鬥中）。 "
                        .. "只適用於你的角色可以施放的法術。",
                },
                onChange = function(checked)
                    if not db.categorySettings then
                        db.categorySettings = {}
                    end
                    if not db.categorySettings[category] then
                        db.categorySettings[category] = {}
                    end
                    db.categorySettings[category].clickable = checked
                    BR.Display.UpdateActionButtons(category)
                    Components.RefreshAll()
                end,
            })
            catLayout:Add(clickableHolder, nil, 2)

            catLayout:SetX(20)
            local highlightHolder = Components.Checkbox(catContent, {
                label = "滑鼠懸停高亮",
                get = function()
                    local hcs = db.categorySettings and db.categorySettings[category]
                    return hcs and hcs.clickableHighlight ~= false
                end,
                enabled = function()
                    local hcs = db.categorySettings and db.categorySettings[category]
                    return hcs and hcs.clickable == true
                end,
                tooltip = {
                    title = "滑鼠懸停高亮",
                    desc = "將滑鼠懸停在可點擊的增益圖示上時顯示細微的高亮。",
                },
                onChange = function(checked)
                    if not db.categorySettings then
                        db.categorySettings = {}
                    end
                    if not db.categorySettings[category] then
                        db.categorySettings[category] = {}
                    end
                    db.categorySettings[category].clickableHighlight = checked
                    BR.Display.UpdateActionButtons(category)
                end,
            })
            catLayout:Add(highlightHolder, nil, COMPONENT_GAP)

            if category == "pet" then
                local specIconHolder = Components.Checkbox(catContent, {
                    label = "滑鼠懸停時顯示獵人寵物專精圖示",
                    get = function()
                        return BR.Config.Get("defaults.petSpecIconOnHover", true)
                    end,
                    enabled = function()
                        local hcs = db.categorySettings and db.categorySettings[category]
                        return hcs and hcs.clickable == true
                    end,
                    tooltip = {
                        title = "滑鼠懸停顯示寵物專精圖示",
                        desc = "Swap the pet icon to its specialization ability (Cunning, Ferocity, Tenacity) when hovering.",
                    },
                    onChange = function(checked)
                        BR.Config.Set("defaults.petSpecIconOnHover", checked)
                    end,
                })
                catLayout:Add(specIconHolder, nil, COMPONENT_GAP)
            end

            if category == "consumable" then
                local showTooltipsHolder = Components.Checkbox(catContent, {
                    label = "顯示物品提示",
                    get = function()
                        return BR.Config.Get("defaults.showConsumableTooltips", false) ~= false
                    end,
                    enabled = function()
                        local hcs = db.categorySettings and db.categorySettings[category]
                        return hcs and hcs.clickable == true
                    end,
                    tooltip = {
                        title = "顯示物品提示",
                        desc = "當滑鼠懸停在消耗品圖示時，顯示物品的提示。",
                    },
                    onChange = function(checked)
                        BR.Config.Set("defaults.showConsumableTooltips", checked)
                    end,
                })
                catLayout:Add(showTooltipsHolder, nil, COMPONENT_GAP)
            end

            catLayout:SetX(0)
        end

        -- Behavior sub-header (pet only)
        if category == "pet" then
            catLayout:Space(SECTION_GAP)
            local behaviorHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            behaviorHeader:SetText("|cffffcc00行為|r")
            catLayout:AddText(behaviorHeader, 12, COMPONENT_GAP)

            local hideMountHolder = Components.Checkbox(catContent, {
                label = "當上坐騎時隱藏",
                get = function()
                    return BR.profile.hidePetWhileMounted ~= false
                end,
                onChange = function(checked)
                    BR.profile.hidePetWhileMounted = checked
                    UpdateDisplay()
                end,
            })
            catLayout:Add(hideMountHolder, nil, COMPONENT_GAP)

            local passiveCombatHolder = Components.Checkbox(catContent, {
                label = "寵物被動僅在戰鬥中",
                get = function()
                    return BR.profile.petPassiveOnlyInCombat == true
                end,
                tooltip = {
                    title = "寵物被動僅在戰鬥中",
                    desc = "僅在戰鬥時顯示被動寵物提醒。停用時，始終顯示提醒。",
                },
                onChange = function(checked)
                    BR.profile.petPassiveOnlyInCombat = checked
                    UpdateDisplay()
                end,
            })
            catLayout:Add(passiveCombatHolder, nil, COMPONENT_GAP)

            local felDomHolder = Components.Checkbox(catContent, {
                label = "在召喚前使用惡魔支配",
                get = function()
                    return BR.Config.Get("defaults.useFelDomination", false)
                end,
                tooltip = {
                    title = "惡魔支配",
                    desc = "點擊施放召喚惡魔之前自動施放惡魔支配。如果惡魔支配處於冷卻狀態，召喚會正常進行。需要惡魔支配天賦。",
                },
                enabled = function()
                    local _, class = UnitClass("player")
                    return class == "WARLOCK"
                end,
                onChange = function(checked)
                    BR.Config.Set("defaults.useFelDomination", checked)
                end,
            })
            catLayout:Add(felDomHolder, nil, COMPONENT_GAP)

            local updatePetDisplayModePreview -- forward declaration for preview update
            local petDisplayModeHolder = Components.Dropdown(catContent, {
                label = "寵物顯示",
                width = 120,
                get = function()
                    return BR.Config.Get("defaults.petDisplayMode", "generic")
                end,
                options = {
                    { value = "generic", label = "通用圖示", desc = "單一通用的 '沒有寵物' 圖示。" },
                    { value = "expanded", label = "召喚法術", desc = "每個寵物召喚法術都有自己的圖示" },
                },
                tooltip = {
                    title = "寵物顯示模式",
                    desc = "如何顯示缺失寵物提醒。",
                },
                onChange = function(val)
                    BR.Config.Set("defaults.petDisplayMode", val)
                    if updatePetDisplayModePreview then
                        updatePetDisplayModePreview(val)
                    end
                end,
            })
            catLayout:Add(petDisplayModeHolder, nil, COMPONENT_GAP)

            -- Pet display mode preview (anchored to the right of the dropdown)
            local PP_ICON = 24
            local PP_BORDER = 2
            local PP_GAP = 3
            local PP_STEP = PP_ICON + PP_GAP + PP_BORDER * 2

            local TEX_PET_GENERIC = 136082 -- Summon Demon flyout icon
            local TEX_PETS = { 136218, 136221, 136217 } -- Imp, Voidwalker, Felhunter

            local petPreviewHeight = PP_ICON + PP_BORDER * 2
            local PET_MODE_ICON_COUNT = { generic = 1, expanded = 3 }

            local petPreviewHolder = CreateFrame("Frame", nil, catContent)
            petPreviewHolder:SetSize(PP_STEP, petPreviewHeight)
            petPreviewHolder:SetPoint("TOPLEFT", petDisplayModeHolder, "TOPRIGHT", 12, 0)

            local petPreviewContainer = CreateFrame("Frame", nil, petPreviewHolder)
            petPreviewContainer:SetPoint("TOPLEFT", 0, 0)
            petPreviewContainer:SetSize(3 * PP_STEP, petPreviewHeight)
            petPreviewContainer:SetAlpha(0.7)

            local function CreatePetPreviewIcon(parent, texture, size)
                local f = CreateFrame("Frame", nil, parent)
                f:SetSize(size, size)
                f.icon = f:CreateTexture(nil, "ARTWORK")
                f.icon:SetAllPoints()
                f.icon:SetTexture(texture)
                local z = TEXCOORD_INSET
                f.icon:SetTexCoord(z, 1 - z, z, 1 - z)
                f.border = f:CreateTexture(nil, "BACKGROUND")
                f.border:SetColorTexture(0, 0, 0, 1)
                f.border:SetPoint("TOPLEFT", -PP_BORDER, PP_BORDER)
                f.border:SetPoint("BOTTOMRIGHT", PP_BORDER, -PP_BORDER)
                return f
            end

            local allPetPreviewFrames = {}

            -- Generic: single icon
            local genericFrame = CreatePetPreviewIcon(petPreviewContainer, TEX_PET_GENERIC, PP_ICON)
            genericFrame:SetPoint("TOPLEFT", petPreviewContainer, "TOPLEFT", 0, 0)
            genericFrame:Hide()
            allPetPreviewFrames[#allPetPreviewFrames + 1] = genericFrame

            -- Expanded: individual summon spell icons
            local expandedPetFrames = {}
            for i = 1, 3 do
                local f = CreatePetPreviewIcon(petPreviewContainer, TEX_PETS[i], PP_ICON)
                f:SetPoint("TOPLEFT", petPreviewContainer, "TOPLEFT", (i - 1) * PP_STEP, 0)
                f:Hide()
                expandedPetFrames[i] = f
                allPetPreviewFrames[#allPetPreviewFrames + 1] = f
            end

            local PET_MODE_FRAMES = {
                generic = { genericFrame },
                expanded = expandedPetFrames,
            }
            updatePetDisplayModePreview = function(mode)
                for _, f in ipairs(allPetPreviewFrames) do
                    f:Hide()
                end
                local shown = PET_MODE_FRAMES[mode]
                if shown then
                    for _, f in ipairs(shown) do
                        f:Show()
                    end
                end
                petPreviewHolder:SetWidth((PET_MODE_ICON_COUNT[mode] or 1) * PP_STEP)
            end

            -- Initial state
            updatePetDisplayModePreview(BR.Config.Get("defaults.petDisplayMode", "generic"))

            -- Register for refresh so reopening the panel re-reads the value
            function petPreviewHolder:Refresh()
                updatePetDisplayModePreview(BR.Config.Get("defaults.petDisplayMode", "generic"))
            end
            tinsert(BR.RefreshableComponents, petPreviewHolder)

            local petLabelsHolder = Components.Checkbox(catContent, {
                label = "寵物標籤",
                get = function()
                    return BR.Config.Get("defaults.petLabels", true)
                end,
                tooltip = {
                    title = "寵物標籤",
                    desc = "在每個圖示下方顯示寵物名稱和專精。",
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.petLabels", checked)
                    Components.RefreshAll()
                end,
            })
            catLayout:Add(petLabelsHolder, nil, COMPONENT_GAP)

            local petLabelScaleHolder = Components.NumericStepper(petLabelsHolder, {
                label = "大小 %",
                labelWidth = 36,
                min = 50,
                max = 200,
                step = 10,
                get = function()
                    return BR.Config.Get("defaults.petLabelScale", 100)
                end,
                enabled = function()
                    return BR.Config.Get("defaults.petLabels", true)
                end,
                onChange = function(val)
                    BR.Config.Set("defaults.petLabelScale", val)
                end,
            })
            petLabelScaleHolder:SetPoint("LEFT", petLabelsHolder, "LEFT", 90, 0)

            -- Pet class label toggles (H/W/D/M) — anchored to the right of the scale stepper
            local function classColor(cls)
                local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[cls]
                if c then
                    return { c.r, c.g, c.b }
                end
                return { 0.5, 0.5, 0.5 }
            end

            local petClassBar, petClassButtons = Components.CreateSegmentedBar(petLabelsHolder, {
                toggleDefs = {
                     { key = "HUNTER", label = "獵", tooltip = { title = "獵人" }, color = classColor("HUNTER") },
                    { key = "WARLOCK", label = "術", tooltip = { title = "術士" }, color = classColor("WARLOCK") },
                    {
                        key = "DEATHKNIGHT",
                        label = "死",
                        tooltip = { title = "死亡騎士" },
                        color = classColor("DEATHKNIGHT"),
                    },
                    { key = "MAGE", label = "法", tooltip = { title = "法師", color = classColor("MAGE") },
                }},
                getState = function(key)
                    local vis = BR.profile.defaults.petLabelClasses
                    return not vis or vis[key] ~= false
                end,
                setState = function(key)
                    if not BR.profile.defaults.petLabelClasses then
                        BR.profile.defaults.petLabelClasses = {
                            HUNTER = true,
                            WARLOCK = true,
                            DEATHKNIGHT = true,
                            MAGE = true,
                        }
                    end
                    BR.profile.defaults.petLabelClasses[key] = not BR.profile.defaults.petLabelClasses[key]
                end,
                onChange = function()
                    UpdateDisplay()
                end,
            })
            petClassBar:SetPoint("LEFT", petLabelScaleHolder, "RIGHT", 8, 0)

            local function isPetLabelsEnabled()
                return BR.Config.Get("defaults.petLabels", true)
            end
            petClassBar:SetBarDisabled(not isPetLabelsEnabled())

            local petClassBarRefreshHolder = CreateFrame("Frame", nil, petLabelsHolder)
            petClassBarRefreshHolder:SetSize(1, 1)
            function petClassBarRefreshHolder:Refresh()
                petClassBar:SetBarDisabled(not isPetLabelsEnabled())
                for _, btn in ipairs(petClassButtons) do
                    btn.UpdateVisual()
                end
            end
            tinsert(BR.RefreshableComponents, petClassBarRefreshHolder)
        end

        -- Item display mode (consumable only, grouped with icon options)
        if category == "consumable" then
            -- Consumable text scale (count + quality labels as % of icon size)
            local consumableTextScaleHolder = Components.Slider(catContent, {
                label = "文字縮放",
                min = 5,
                max = 80,
                step = 1,
                suffix = "%",
                get = function()
                    return BR.Config.Get("defaults.consumableTextScale", 25)
                end,
                tooltip = {
                    title = "消耗品文字縮放",
                    desc = "物品數量和品質 (R1/R2/R3) 標籤的字體大小佔圖示大小的百分比。",
                },
                onChange = function(val)
                    BR.Config.Set("defaults.consumableTextScale", val)
                end,
            })
            catLayout:Add(consumableTextScaleHolder, nil, COMPONENT_GAP)

            local updateDisplayModePreview -- forward declaration for preview update
            local updateSubIconSideVisibility -- forward declaration for sub-icon side visibility
            local displayModeHolder = Components.Dropdown(catContent, {
                label = "物品顯示",
                get = function()
                    return BR.Config.Get("defaults.consumableDisplayMode", "sub_icons")
                end,
                options = {
                    { value = "icon_only", label = "只有圖示", desc = "顯示次數最高的物品" },
                    {
                        value = "sub_icons",
                        label = "子圖示",
                        desc = "每個圖示下方可點擊的各種小物品",
                    },
                    { value = "expanded", label = "開展", desc = "每種物品都為全尺寸圖示" },
                },
                tooltip = {
                    title = "消耗物品顯示",
                    desc = "如何顯示具有多種類型的消耗品 (例如：不同類型的精鍊)。",
                },
                onChange = function(val)
                    BR.Config.Set("defaults.consumableDisplayMode", val)
                    if updateDisplayModePreview then
                        updateDisplayModePreview(val)
                    end
                    if updateSubIconSideVisibility then
                        updateSubIconSideVisibility(val)
                    end
                end,
            })
            catLayout:Add(displayModeHolder, nil, COMPONENT_GAP)

            -- Display mode preview (anchored to the right of the dropdown)
            local P_ICON = 24
            local P_SUB = 12
            local P_BORDER = 2
            local P_GAP = 3
            local P_STEP = P_ICON + P_GAP + P_BORDER * 2
            local P_SUB_STEP = P_SUB + P_BORDER * 2 -- sub-icons touch borders
            -- Distinct textures for flask/food/oil and their variants (Midnight icons)
            local TEX_FLASK = { 7548898, 7548899, 7548900 } -- Haranir flasks: blue, green, orange
            local TEX_FOOD = { 4672193, 1045939 } -- Royal Roast, Twilight Angler's Medley
            local TEX_OIL = 7548987 -- Thalassian Phoenix Oil

            local previewHeight = P_ICON + P_SUB + P_GAP + P_BORDER * 2
            local MODE_ICON_COUNT = { icon_only = 3, sub_icons = 3, expanded = 6 }

            local previewHolder = CreateFrame("Frame", nil, catContent)
            previewHolder:SetSize(3 * P_STEP, previewHeight)
            previewHolder:SetPoint("TOPLEFT", displayModeHolder, "TOPRIGHT", 12, 0)

            local previewContainer = CreateFrame("Frame", nil, previewHolder)
            previewContainer:SetPoint("TOPLEFT", 0, 0)
            previewContainer:SetSize(6 * P_STEP, previewHeight)
            previewContainer:SetAlpha(0.7)

            local function CreatePreviewIcon(parent, texture, size)
                local f = CreateFrame("Frame", nil, parent)
                f:SetSize(size, size)
                f.icon = f:CreateTexture(nil, "ARTWORK")
                f.icon:SetAllPoints()
                f.icon:SetTexture(texture)
                local z = TEXCOORD_INSET
                f.icon:SetTexCoord(z, 1 - z, z, 1 - z)
                f.border = f:CreateTexture(nil, "BACKGROUND")
                f.border:SetColorTexture(0, 0, 0, 1)
                f.border:SetPoint("TOPLEFT", -P_BORDER, P_BORDER)
                f.border:SetPoint("BOTTOMRIGHT", P_BORDER, -P_BORDER)
                return f
            end

            local allPreviewFrames = {}

            -- Icon-only: [Flask] [Food] [Oil]
            local iconOnlyFrames = {}
            local iconOnlyTextures = { TEX_FLASK[1], TEX_FOOD[1], TEX_OIL }
            for i = 1, 3 do
                local f = CreatePreviewIcon(previewContainer, iconOnlyTextures[i], P_ICON)
                f:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", (i - 1) * P_STEP, 0)
                f:Hide()
                iconOnlyFrames[i] = f
                allPreviewFrames[#allPreviewFrames + 1] = f
            end

            -- Sub-icons: [Flask] [Food] [Oil] with variant sub-icons below
            local subIconsFrames = { mains = {}, subs = {} }
            local subVariants = { TEX_FLASK, TEX_FOOD, {} } -- oil has no variants
            for i, variants in ipairs(subVariants) do
                local mainTex = (#variants > 0) and variants[1] or TEX_OIL
                local main = CreatePreviewIcon(previewContainer, mainTex, P_ICON)
                main:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", (i - 1) * P_STEP, 0)
                main:Hide()
                subIconsFrames.mains[i] = main
                allPreviewFrames[#allPreviewFrames + 1] = main
                if #variants > 1 then
                    local subCount = #variants - 1
                    local subRowWidth = (subCount - 1) * P_SUB_STEP + P_SUB
                    local subOffsetX = (P_ICON - subRowWidth) / 2
                    for j = 2, #variants do
                        local sub = CreatePreviewIcon(previewContainer, variants[j], P_SUB)
                        sub:SetPoint("TOPLEFT", main, "BOTTOMLEFT", subOffsetX + (j - 2) * P_SUB_STEP, -P_GAP)
                        sub:Hide()
                        subIconsFrames.subs[#subIconsFrames.subs + 1] = sub
                        allPreviewFrames[#allPreviewFrames + 1] = sub
                    end
                end
            end

            -- Expanded: [F1][F2][F3][Fd1][Fd2][Oil] — each variant at full size
            local expandedFrames = {}
            local expandedTextures = {
                TEX_FLASK[1],
                TEX_FLASK[2],
                TEX_FLASK[3],
                TEX_FOOD[1],
                TEX_FOOD[2],
                TEX_OIL,
            }
            for i = 1, 6 do
                local f = CreatePreviewIcon(previewContainer, expandedTextures[i], P_ICON)
                f:SetPoint("TOPLEFT", previewContainer, "TOPLEFT", (i - 1) * P_STEP, 0)
                f:Hide()
                expandedFrames[i] = f
                allPreviewFrames[#allPreviewFrames + 1] = f
            end

            -- Combine sub-icons mains + subs into one flat list
            local subIconsAll = {}
            for _, f in ipairs(subIconsFrames.mains) do
                subIconsAll[#subIconsAll + 1] = f
            end
            for _, f in ipairs(subIconsFrames.subs) do
                subIconsAll[#subIconsAll + 1] = f
            end

            local MODE_FRAMES = {
                icon_only = iconOnlyFrames,
                sub_icons = subIconsAll,
                expanded = expandedFrames,
            }
            updateDisplayModePreview = function(mode)
                for _, f in ipairs(allPreviewFrames) do
                    f:Hide()
                end
                local shown = MODE_FRAMES[mode]
                if shown then
                    for _, f in ipairs(shown) do
                        f:Show()
                    end
                end
                previewHolder:SetWidth((MODE_ICON_COUNT[mode] or 3) * P_STEP)
            end

            -- Initial state
            updateDisplayModePreview(BR.Config.Get("defaults.consumableDisplayMode", "sub_icons"))

            -- Register for refresh so reopening the panel re-reads the value
            function previewHolder:Refresh()
                updateDisplayModePreview(BR.Config.Get("defaults.consumableDisplayMode", "sub_icons"))
            end
            tinsert(BR.RefreshableComponents, previewHolder)

            -- Sub-icon placement side (anchored below preview, visible only in sub_icons mode)
            local subIconSideHolder = Components.Dropdown(catContent, {
                label = "位置",
                labelWidth = 30,
                width = 85,
                get = function()
                    local catSettings = db.categorySettings and db.categorySettings[category]
                    return catSettings and catSettings.subIconSide or "BOTTOM"
                end,
                options = {
                    { value = "BOTTOM", label = "底部" },
                    { value = "TOP", label = "頂部" },
                    { value = "LEFT", label = "左側" },
                    { value = "RIGHT", label = "右側" },
                },
                onChange = function(val)
                    BR.Config.Set("categorySettings." .. category .. ".subIconSide", val)
                end,
            })
            subIconSideHolder:SetPoint("TOPLEFT", previewHolder, "TOPRIGHT", 12, 0)

            updateSubIconSideVisibility = function(mode)
                subIconSideHolder:SetShown(mode == "sub_icons")
            end
            updateSubIconSideVisibility(BR.Config.Get("defaults.consumableDisplayMode", "sub_icons"))

            -- Sub-header for behavior options
            catLayout:Space(SECTION_GAP)
            local behaviorHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            behaviorHeader:SetText("|cffffcc00行為|r")
            catLayout:AddText(behaviorHeader, 12, COMPONENT_GAP)

            local showWithoutItemsHolder = Components.Checkbox(catContent, {
                label = "顯示不在背包的消耗品",
                get = function()
                    return BR.Config.Get("defaults.showConsumablesWithoutItems", false) == true
                end,
                tooltip = {
                    title = "顯示沒有物品的消耗品",
                    desc = "啟用後，即使您的包包中沒有該物品，也會顯示消耗品提醒。停用時，僅顯示您實際攜帶的消耗品。",
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.showConsumablesWithoutItems", checked)
                end,
            })
            catLayout:Add(showWithoutItemsHolder, nil, COMPONENT_GAP)

            local delveFoodOnlyHolder = Components.Checkbox(catContent, {
                label = "在探究只有探究食物",
                get = function()
                    return BR.Config.Get("defaults.delveFoodOnly", false) == true
                end,
                tooltip = {
                    title = "在探究只有探究食物",
                    desc = "當進入探究時，隱藏除探究食物外的所有消耗品提醒。",
                },
                onChange = function(checked)
                    BR.Config.Set("defaults.delveFoodOnly", checked)
                end,
            })
            catLayout:Add(delveFoodOnlyHolder, nil, COMPONENT_GAP)
        end

        -- Layout sub-header
        catLayout:Space(SECTION_GAP)
        local layoutHeader = catContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        layoutHeader:SetText("|cffffcc00佈局|r")
        catLayout:AddText(layoutHeader, 12, COMPONENT_GAP)

        -- Priority slider (only relevant when not split)
        local priorityHolder = Components.Slider(catContent, {
            label = "優先級",
            min = 1,
            max = 7,
            step = 1,
            get = function()
                local cs = db.categorySettings and db.categorySettings[category]
                return cs and cs.priority or defaults.categorySettings[category].priority
            end,
            enabled = function()
                return not IsCategorySplit(category)
            end,
            tooltip = {
                title = "顯示優先級",
                desc = "控制該類別在組合框架中的順序。首先顯示較低的值。",
            },
            onChange = function(val)
                BR.Config.Set("categorySettings." .. category .. ".priority", val)
            end,
        })
        catLayout:Add(priorityHolder, nil, COMPONENT_GAP)

        -- Split frame checkbox
        local splitHolder = Components.Checkbox(catContent, {
            label = "分割成單獨的框架",
            get = function()
                return IsCategorySplit(category)
            end,
            tooltip = {
                title = "分割成單獨的框架",
                desc = "在單獨的以及可獨立移動的框架中顯示此類別的增益",
            },
            onChange = function(checked)
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings[category] then
                    db.categorySettings[category] = {}
                end
                db.categorySettings[category].split = checked
                ReparentBuffFrames()
                UpdateVisuals()
            end,
        })
        catLayout:Add(splitHolder, nil, COMPONENT_GAP)

        -- Reset position button (only relevant when split)
        local resetBtn = CreateButton(catContent, "重設位置", function()
            local catDefaults = defaults.categorySettings[category]
            if catDefaults and catDefaults.position then
                ResetCategoryFramePosition(category, catDefaults.position.x, catDefaults.position.y)
            end
        end)
        resetBtn:SetPoint("LEFT", splitHolder, "RIGHT", 10, 0)
        resetBtn:SetEnabled(IsCategorySplit(category))

        local origSplitClick = splitHolder.checkbox:GetScript("OnClick")
        splitHolder.checkbox:SetScript("OnClick", function(self)
            if origSplitClick then
                origSplitClick(self)
            end
            resetBtn:SetEnabled(IsCategorySplit(category))
            Components.RefreshAll()
        end)

        -- Shared enabled predicates for this category
        local function isCustomAppearanceEnabled()
            return db.categorySettings
                and db.categorySettings[category]
                and db.categorySettings[category].useCustomAppearance == true
        end

        local function isCustomGlowEnabled()
            return isCustomAppearanceEnabled() and db.categorySettings[category].useCustomGlow == true
        end

        -- Snapshot current effective glow values from defaults into a category
        local function SnapshotGlowDefaults()
            local cs = db.categorySettings[category]
            local glowDefaults = db.defaults or {}
            local glowSnapshotKeys = {
                "glowType",
                "glowSize",
                "glowPixelLines",
                "glowPixelFrequency",
                "glowPixelLength",
                "glowAutocastParticles",
                "glowAutocastFrequency",
                "glowAutocastScale",
                "glowBorderFrequency",
                "glowProcDuration",
                "glowProcStartAnim",
                "glowProcUseCustomColor",
                "glowXOffset",
                "glowYOffset",
            }
            for _, key in ipairs(glowSnapshotKeys) do
                if cs[key] == nil and glowDefaults[key] ~= nil then
                    cs[key] = glowDefaults[key]
                end
            end
            -- glowColor: deep copy (table value)
            if cs.glowColor == nil and glowDefaults.glowColor then
                local gc = glowDefaults.glowColor
                cs.glowColor = { gc[1], gc[2], gc[3], gc[4] }
            end
        end

        -- Use custom appearance checkbox
        catLayout:SetX(0)
        local useCustomAppHolder = Components.Checkbox(catContent, {
            label = "使用自訂外觀",
            get = function()
                return db.categorySettings
                    and db.categorySettings[category]
                    and db.categorySettings[category].useCustomAppearance == true
            end,
            tooltip = {
                title = "使用自訂外觀",
                desc = "停用時，此類別繼承全域預設值的外觀設置。延展方向需要分離成一個單獨的框架。",
            },
            onChange = function(checked)
                if not db.categorySettings then
                    db.categorySettings = {}
                end
                if not db.categorySettings[category] then
                    db.categorySettings[category] = {}
                end
                -- When enabling custom appearance, snapshot current effective values
                -- so the category starts independent from future Global Defaults changes
                if checked then
                    local effective = GetCategorySettings(category)
                    local cs = db.categorySettings[category]
                    local appearanceKeys = {
                        "iconSize",
                        "iconWidth",
                        "spacing",
                        "iconZoom",
                        "borderSize",
                        "iconAlpha",
                        "textAlpha",
                        "growDirection",
                    }
                    for _, key in ipairs(appearanceKeys) do
                        if cs[key] == nil and effective[key] ~= nil then
                            cs[key] = effective[key]
                        end
                    end
                    -- textSize: only snapshot if explicitly set (nil = auto-derive from iconSize)
                    if cs.textSize == nil and effective.textSize ~= nil then
                        cs.textSize = effective.textSize
                    end
                    -- textColor: deep copy (table value)
                    if cs.textColor == nil and effective.textColor then
                        local tc = effective.textColor
                        cs.textColor = { tc[1], tc[2], tc[3] }
                    end
                end
                BR.Config.Set("categorySettings." .. category .. ".useCustomAppearance", checked)
                Components.RefreshAll()
            end,
        })
        catLayout:Add(useCustomAppHolder, nil, COMPONENT_GAP)

        local baseContentY = catLayout:GetY()

        -- Direction buttons (part of custom appearance)
        catLayout:SetX(10)
        local dirHolder = Components.DirectionButtons(catContent, {
            get = function()
                local catSettings = db.categorySettings and db.categorySettings[category]
                local val = catSettings and catSettings.growDirection
                if val ~= nil then
                    return val
                end
                return db.defaults and db.defaults.growDirection or "CENTER"
            end,
            enabled = function()
                return isCustomAppearanceEnabled() and IsCategorySplit(category)
            end,
            onChange = function(dir)
                BR.Config.Set("categorySettings." .. category .. ".growDirection", dir)
            end,
        })
        catLayout:Add(dirHolder, nil, COMPONENT_GAP + DROPDOWN_EXTRA)

        -- Read the category's own saved value, falling back to defaults only if no value was saved.
        -- This avoids showing inherited defaults when useCustomAppearance is off, so toggling
        -- custom appearance off/on preserves the user's previously configured values.
        local function getCatOwnValue(key, default)
            local catSettings = db.categorySettings and db.categorySettings[category]
            local val = catSettings and catSettings[key]
            if val ~= nil then
                return val
            end
            return db.defaults and db.defaults[key] or default
        end

        local function isCatDimensionsLinked()
            local cs = db.categorySettings and db.categorySettings[category]
            return not cs or cs.iconWidth == nil
        end

        -- Appearance controls (2-col declarative grid)
        catLayout:SetX(10)
        local appFrame = CreateFrame("Frame", nil, catContent)
        appFrame:SetSize(480, 50)
        catLayout:Add(appFrame, 0)

        local catGrid = Components.AppearanceGrid(appFrame, {
            get = getCatOwnValue,
            set = function(key, value)
                BR.Config.Set("categorySettings." .. category .. "." .. key, value)
            end,
            setMulti = function(changes)
                local prefixed = {}
                for k, v in pairs(changes) do
                    prefixed["categorySettings." .. category .. "." .. k] = v
                end
                BR.Config.SetMulti(prefixed)
            end,
            isLinked = isCatDimensionsLinked,
            onLink = function()
                BR.Config.Set("categorySettings." .. category .. ".iconWidth", nil)
                Components.RefreshAll()
            end,
            onUnlink = function()
                local size = getCatOwnValue("iconSize", 64)
                BR.Config.Set("categorySettings." .. category .. ".iconWidth", size)
                Components.RefreshAll()
            end,
            enabled = isCustomAppearanceEnabled,
            masqueCheck = IsMasqueActive,
        })

        -- Glow settings (positioned after appearance grid)
        local glowRowY = -catGrid.height
        local gridHeight
        if category == "pet" then
            -- Pets don't expire — single glow on/off checkbox
            local catPetGlowHolder = Components.Checkbox(appFrame, {
                label = "缺少寵物發光",
                get = function()
                    return getCatOwnValue("showExpirationGlow", true) ~= false
                end,
                enabled = isCustomAppearanceEnabled,
                onChange = function(checked)
                    BR.Config.Set("categorySettings." .. category .. ".showExpirationGlow", checked)
                    Components.RefreshAll()
                end,
            })
            catPetGlowHolder:SetPoint("TOPLEFT", 0, glowRowY)

            -- Per-category custom glow style (pet)
            local catPetCustomGlowHolder = Components.Checkbox(appFrame, {
                label = "自訂發光樣式",
                get = function()
                    return isCustomGlowEnabled()
                end,
                enabled = isCustomAppearanceEnabled,
                onChange = function(checked)
                    if checked then
                        SnapshotGlowDefaults()
                    end
                    BR.Config.Set("categorySettings." .. category .. ".useCustomGlow", checked)
                    Components.RefreshAll()
                end,
            })
            catPetCustomGlowHolder:SetPoint("TOPLEFT", 0, glowRowY - 24)

            local catPetGlowSettingsBtn = CreateButton(appFrame, "Customize", function()
                ShowGlowAdvanced(category)
            end)
            catPetGlowSettingsBtn:SetPoint("LEFT", catPetCustomGlowHolder.label, "RIGHT", 8, 0)
            catPetGlowSettingsBtn:SetFrameLevel(catPetCustomGlowHolder:GetFrameLevel() + 5)

            local function updatePetGlowBtnEnabled()
                local enabled = isCustomGlowEnabled()
                if enabled then
                    catPetGlowSettingsBtn:Enable()
                    catPetGlowSettingsBtn:SetAlpha(1)
                else
                    catPetGlowSettingsBtn:Disable()
                    catPetGlowSettingsBtn:SetAlpha(0.4)
                end
            end
            updatePetGlowBtnEnabled()
            tinsert(BR.RefreshableComponents, { Refresh = updatePetGlowBtnEnabled })

            gridHeight = catGrid.height + 48
        else
            local catThresholdHolder = Components.Slider(appFrame, {
                label = "期限",
                labelWidth = 56,
                min = 0,
                max = 45,
                step = 5,
                formatValue = function(val)
                    return val == 0 and "Off" or (val .. " 分")
                end,
                get = function()
                    return getCatOwnValue("expirationThreshold", 15)
                end,
                enabled = isCustomAppearanceEnabled,
                onChange = function(val)
                    BR.Config.Set("categorySettings." .. category .. ".expirationThreshold", val)
                end,
            })
            catThresholdHolder:SetPoint("TOPLEFT", 0, glowRowY)

            local catGlowCheckHolder = Components.Checkbox(appFrame, {
                label = "發光",
                get = function()
                    return getCatOwnValue("showExpirationGlow", true) ~= false
                end,
                enabled = isCustomAppearanceEnabled,
                onChange = function(checked)
                    BR.Config.Set("categorySettings." .. category .. ".showExpirationGlow", checked)
                    Components.RefreshAll()
                end,
            })
            catGlowCheckHolder:SetPoint("TOPLEFT", 0, glowRowY - 24)

            -- Per-category custom glow style
            local catCustomGlowHolder = Components.Checkbox(appFrame, {
                label = "自訂發光樣式",
                get = function()
                    return isCustomGlowEnabled()
                end,
                enabled = isCustomAppearanceEnabled,
                onChange = function(checked)
                    if checked then
                        SnapshotGlowDefaults()
                    end
                    BR.Config.Set("categorySettings." .. category .. ".useCustomGlow", checked)
                    Components.RefreshAll()
                end,
            })
            catCustomGlowHolder:SetPoint("TOPLEFT", 0, glowRowY - 48)

            local catGlowSettingsBtn = CreateButton(appFrame, "Customize", function()
                ShowGlowAdvanced(category)
            end)
            catGlowSettingsBtn:SetPoint("LEFT", catCustomGlowHolder.label, "RIGHT", 8, 0)
            catGlowSettingsBtn:SetFrameLevel(catCustomGlowHolder:GetFrameLevel() + 5)

            -- Register enabled state for the customize button
            local function updateGlowBtnEnabled()
                local enabled = isCustomGlowEnabled()
                if enabled then
                    catGlowSettingsBtn:Enable()
                    catGlowSettingsBtn:SetAlpha(1)
                else
                    catGlowSettingsBtn:Disable()
                    catGlowSettingsBtn:SetAlpha(0.4)
                end
            end
            updateGlowBtnEnabled()
            tinsert(BR.RefreshableComponents, { Refresh = updateGlowBtnEnabled })

            gridHeight = catGrid.height + 72
        end

        -- Advance past the appFrame grid and finalize section height
        catLayout:Space(gridHeight)
        catLayout:SetX(0)

        local fullContentHeight = abs(catLayout:GetY()) + 10
        local baseContentHeight = abs(baseContentY) + 10

        local UpdateCustomAppearanceVisibility = function()
            local show = isCustomAppearanceEnabled()
            if show then
                dirHolder:Show()
                appFrame:Show()
                section:SetContentHeight(fullContentHeight)
            else
                dirHolder:Hide()
                appFrame:Hide()
                section:SetContentHeight(baseContentHeight)
            end
            C_Timer.After(0, UpdateAppearanceContentHeight)
        end

        -- Register so panel OnShow syncs visibility state
        tinsert(BR.RefreshableComponents, { Refresh = UpdateCustomAppearanceVisibility })

        -- Set initial state (inline to avoid deferred timer during loop)
        if isCustomAppearanceEnabled() then
            section:SetContentHeight(fullContentHeight)
        else
            dirHolder:Hide()
            appFrame:Hide()
            section:SetContentHeight(baseContentHeight)
        end
        tinsert(categorySections, section)
        previousSection = section
    end

    UpdateAppearanceContentHeight()

    -- ========== SETTINGS TAB ==========
    -- Simple frame (not scrollable) - content fits without scrolling
    local settingsContent = CreateFrame("Frame", nil, panel)
    settingsContent:SetPoint("TOPLEFT", 0, CONTENT_TOP)
    settingsContent:SetSize(PANEL_WIDTH, 500)
    settingsContent:Hide()
    contentContainers.settings = settingsContent

    local setX = COL_PADDING
    local setLayout = Components.VerticalLayout(settingsContent, { x = setX, y = -10 })

    local loginMsgHolder = Components.Checkbox(settingsContent, {
        label = "顯示登入訊息",
        get = function()
            return BR.profile.showLoginMessages ~= false
        end,
        onChange = function(checked)
            BR.profile.showLoginMessages = checked
        end,
    })
    setLayout:Add(loginMsgHolder, nil, COMPONENT_GAP)

    local minimapHolder = Components.Checkbox(settingsContent, {
        label = "顯示小地圖按鈕",
        get = function()
            return not BR.aceDB.global.minimap.hide
        end,
        onChange = function(checked)
            BR.aceDB.global.minimap.hide = not checked
            if BR.MinimapButton then
                if checked then
                    BR.MinimapButton.Icon:Show("BuffReminders")
                else
                    BR.MinimapButton.Icon:Hide("BuffReminders")
                end
            end
        end,
    })
    setLayout:Add(minimapHolder, nil, COMPONENT_GAP)

    -- General Settings section
    LayoutSectionHeader(setLayout, settingsContent, "顯示")

    local groupHolder = Components.Checkbox(settingsContent, {
        label = "只有在隊伍/團隊中顯示",
        get = function()
            return BR.profile.showOnlyInGroup ~= false
        end,
        onChange = function(checked)
            BR.profile.showOnlyInGroup = checked
            UpdateDisplay()
        end,
    })
    setLayout:Add(groupHolder, nil, COMPONENT_GAP)

    -- "Hide when:" sub-label with indented checkboxes
    local hideWhenLabel = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hideWhenLabel:SetText("何時隱藏:")
    setLayout:AddText(hideWhenLabel, 12, COMPONENT_GAP)

    local HIDE_INDENT = 16
    setLayout:SetX(setX + HIDE_INDENT)

    local restingHolder = Components.Checkbox(settingsContent, {
        label = "休息狀態時",
        get = function()
            return BR.profile.hideWhileResting == true
        end,
        tooltip = { title = "休息狀態時隱藏", desc = "在旅館或主城時隱藏增益提醒" },
        onChange = function(checked)
            BR.profile.hideWhileResting = checked
            UpdateDisplay()
        end,
    })
    setLayout:Add(restingHolder, nil, COMPONENT_GAP)

    local combatHolder = Components.Checkbox(settingsContent, {
        label = "戰鬥中",
        get = function()
            return BR.profile.hideInCombat == true
        end,
        onChange = function(checked)
            BR.profile.hideInCombat = checked
            UpdateDisplay()
            Components.RefreshAll()
        end,
    })
    setLayout:Add(combatHolder, nil, COMPONENT_GAP)

    local combatExpiringHolder = Components.Checkbox(settingsContent, {
        label = "戰鬥中過期",
        tooltip = {
            title = "隱藏戰鬥中過期的增益",
            desc = "在戰鬥中，隱藏即將過期的增益效果，只顯示完全缺少的增益效果",
        },
        get = function()
            return BR.profile.hideExpiringInCombat ~= false
        end,
        enabled = function()
            return BR.profile.hideInCombat ~= true
        end,
        onChange = function(checked)
            BR.profile.hideExpiringInCombat = checked
            UpdateDisplay()
        end,
    })
    setLayout:Add(combatExpiringHolder, nil, COMPONENT_GAP)

    local vehicleHolder = Components.Checkbox(settingsContent, {
        label = "載具中",
        tooltip = {
            title = "載具中隱藏",
            desc = "在任務載具中隱藏所有增益提醒。禁用後，團隊和在場增益仍然顯示",
        },
        get = function()
            return BR.profile.hideAllInVehicle == true
        end,
        onChange = function(checked)
            BR.profile.hideAllInVehicle = checked
            UpdateDisplay()
        end,
    })
    setLayout:Add(vehicleHolder, nil, COMPONENT_GAP)

    local mountedHolder = Components.Checkbox(settingsContent, {
        label = "坐騎上",
        tooltip = {
            title = "坐騎上隱藏",
            desc = "上坐騎時隱藏所有增益提醒。覆蓋每個類別的寵物坐騎隱藏設定",
        },
        get = function()
            return BR.profile.hideWhileMounted == true
        end,
        onChange = function(checked)
            BR.profile.hideWhileMounted = checked
            UpdateDisplay()
        end,
    })
    setLayout:Add(mountedHolder, nil, COMPONENT_GAP)

    local legacyHolder = Components.Checkbox(settingsContent, {
        label = "在舊副本",
        tooltip = {
            title = "在舊副本中隱藏",
            desc = "隱藏舊副本中的所有增益提醒（啟用傳統拾取）",
        },
        get = function()
            return BR.profile.hideInLegacyInstances == true
        end,
        onChange = function(checked)
            BR.profile.hideInLegacyInstances = checked
            UpdateDisplay()
        end,
    })
    setLayout:Add(legacyHolder, nil, COMPONENT_GAP)

    setLayout:SetX(setX)

    local trackingModeHolder = Components.Dropdown(settingsContent, {
        label = "增益追蹤",
        width = 200,
        options = {
            {
                value = "all",
                label = "全部增益，全部玩家",
                desc = "顯示每個職業的所有團隊和在場增益，追蹤完整的團隊覆蓋範圍。",
            },
            {
                value = "my_buffs",
                label = "只有我的增益，全部玩家",
                desc = "只顯示你的職業可以提供的增益。仍然追踪完整的團隊範圍。",
            },
            {
                value = "personal",
                label = "只有我需要的增益",
                desc = "顯示所有增益類型，但僅檢查您個人是否擁有它們。沒有團體計數。",
            },
            {
                value = "smart",
                label = "智能",
                desc = "針對全隊範圍追蹤您的職業能提供的增益。其他職業增益只檢查你個人。",
            },
        },
        get = function()
            return BR.Config.Get("buffTrackingMode", "all")
        end,
        tooltip = {
            title = "增益追蹤模式",
            desc = "控制顯示哪些團隊和在場增益，以及它們是否追蹤整個團隊或僅追蹤您。",
        },
        onChange = function(val)
            BR.Config.Set("buffTrackingMode", val)
            UpdateDisplay()
        end,
    })
    setLayout:Add(trackingModeHolder, nil, COMPONENT_GAP)

    -- Custom Anchor Frames section
    LayoutSectionHeader(setLayout, settingsContent, "自訂定位框架")

    local customAnchorDesc = settingsContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    customAnchorDesc:SetWidth(PANEL_WIDTH - COL_PADDING * 2)
    customAnchorDesc:SetJustifyH("LEFT")
    customAnchorDesc:SetText(
        "將全局框架名稱新增至定位點下拉清單中 (e.g. MyAddon_PlayerFrame). \n遊戲中不存在的框架會被默默地跳過。"
    )
    setLayout:AddText(customAnchorDesc, 22, COMPONENT_GAP)

    -- Input row: text input + add button (at top)
    local addAnchorRow = CreateFrame("Frame", nil, settingsContent)
    addAnchorRow:SetSize(PANEL_WIDTH - COL_PADDING * 2, 22)

    local addAnchorInput = Components.TextInput(addAnchorRow, {
        label = "",
        value = "",
        width = 180,
        labelWidth = 0,
    })
    addAnchorInput:SetPoint("LEFT", 0, 0)
    local addAnchorBox = addAnchorInput.editBox

    local addAnchorBtn -- forward declare for editbox callback

    local customAnchorList = CreateFrame("Frame", nil, settingsContent)
    customAnchorList:SetSize(PANEL_WIDTH - COL_PADDING * 2, 1)

    local customAnchorEntries = {} -- holder frames for removal

    local function RebuildCustomAnchorList()
        for _, entry in ipairs(customAnchorEntries) do
            entry:Hide()
            entry:SetParent(nil)
        end
        wipe(customAnchorEntries)

        local db = BR.profile
        local list = db.customAnchorFrames or {}
        local entryY = 0

        for i, name in ipairs(list) do
            local row = CreateFrame("Frame", nil, customAnchorList)
            row:SetSize(PANEL_WIDTH - COL_PADDING * 2, 20)
            row:SetPoint("TOPLEFT", 0, -entryY)

            local bullet = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            bullet:SetPoint("LEFT", 4, 0)
            bullet:SetText("-")

            local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            text:SetPoint("LEFT", bullet, "RIGHT", 4, 0)
            text:SetText(name)

            local removeBtn = CreateFrame("Button", nil, row)
            removeBtn:SetSize(16, 16)
            removeBtn:SetPoint("LEFT", text, "RIGHT", 6, 0)
            removeBtn:SetNormalFontObject("GameFontRedSmall")
            removeBtn:SetText("x")
            removeBtn:SetScript("OnClick", function()
                tremove(list, i)
                if #list == 0 then
                    db.customAnchorFrames = nil
                end
                RebuildCustomAnchorList()
            end)

            tinsert(customAnchorEntries, row)
            entryY = entryY + 22
        end

        customAnchorList:SetHeight(math.max(1, entryY))
    end

    addAnchorBtn = CreateButton(addAnchorRow, "Add", function()
        local name = strtrim(addAnchorBox:GetText())
        if name == "" then
            return
        end
        local db = BR.profile
        if not db.customAnchorFrames then
            db.customAnchorFrames = {}
        end
        -- Avoid duplicates
        for _, existing in ipairs(db.customAnchorFrames) do
            if existing == name then
                addAnchorBox:SetText("")
                return
            end
        end
        tinsert(db.customAnchorFrames, name)
        addAnchorBox:SetText("")
        RebuildCustomAnchorList()
    end)
    addAnchorBtn:SetSize(50, 22)
    addAnchorBtn:SetPoint("LEFT", addAnchorInput, "RIGHT", 6, 0)

    addAnchorBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        addAnchorBtn:Click()
    end)

    setLayout:Add(addAnchorRow, nil, COMPONENT_GAP)

    RebuildCustomAnchorList()
    setLayout:Add(customAnchorList, nil, COMPONENT_GAP)

    -- ========== PROFILES TAB ==========
    -- Use simple frame (not scrollable) to avoid nested scroll frame issues with edit boxes
    local profilesContent = CreateFrame("Frame", nil, panel)
    profilesContent:SetPoint("TOPLEFT", 0, CONTENT_TOP)
    profilesContent:SetSize(PANEL_WIDTH, 600)
    profilesContent:Hide()
    contentContainers.profiles = profilesContent

    local profX = COL_PADDING
    local profLayout = Components.VerticalLayout(profilesContent, { x = profX, y = -10 })
    local RefreshProfileDropdown -- forward declaration for closures

    -- Profile management section
    LayoutSectionHeader(profLayout, profilesContent, "啟用設定檔")

    local profileDesc = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    profileDesc:SetText("在已儲存的配置之間切換。每個角色可以使用不同的設定檔。")
    profLayout:AddText(profileDesc, 12, COMPONENT_GAP)

    local function GetProfileOptions()
        local names = BR.Profiles.ListProfiles()
        local options = {}
        for _, name in ipairs(names) do
            options[#options + 1] = { value = name, label = name }
        end
        return options
    end

    local function GetOtherProfileOptions()
        local names = BR.Profiles.ListProfiles()
        local active = BR.Profiles.GetActiveProfileName()
        local options = { { value = "", label = "選擇設定檔" } }
        for _, name in ipairs(names) do
            if name ~= active then
                options[#options + 1] = { value = name, label = name }
            end
        end
        return options
    end

    local PROF_LABEL_WIDTH = 70
    local PROF_DROPDOWN_WIDTH = 150

    -- Active profile row: dropdown + New / Reset buttons
    local profileRow = CreateFrame("Frame", nil, profilesContent)
    profileRow:SetSize(PANEL_WIDTH - COL_PADDING * 2, 26)

    local profileDropdown = Components.Dropdown(profileRow, {
        label = "設定檔",
        labelWidth = PROF_LABEL_WIDTH,
        width = PROF_DROPDOWN_WIDTH,
        options = GetProfileOptions(),
        get = function()
            return BR.Profiles.GetActiveProfileName()
        end,
        onChange = function(value)
            BR.Profiles.SwitchProfile(value)
            RefreshProfileDropdown()
            Components.RefreshAll()
        end,
    })
    profileDropdown:SetPoint("LEFT", 0, 0)

    local btnX = PROF_LABEL_WIDTH + PROF_DROPDOWN_WIDTH + 10

    local newProfileBtn = CreateButton(profileRow, "新增", function()
        StaticPopup_Show("BUFFREMINDERS_NEW_PROFILE")
    end)
    newProfileBtn:SetSize(50, 22)
    newProfileBtn:SetPoint("LEFT", btnX, 0)

    local resetProfileBtn = CreateButton(profileRow, "重置", function()
        StaticPopup_Show("BUFFREMINDERS_RESET_DEFAULTS")
    end)
    resetProfileBtn:SetSize(50, 22)
    resetProfileBtn:SetPoint("LEFT", btnX + 54, 0)

    profLayout:Add(profileRow, 26, COMPONENT_GAP)

    -- Copy From dropdown
    local copyDropdown = Components.Dropdown(profilesContent, {
        label = "複製自",
        labelWidth = PROF_LABEL_WIDTH,
        width = PROF_DROPDOWN_WIDTH,
        options = GetOtherProfileOptions(),
        get = function()
            return ""
        end,
        onChange = function(value)
            if value == "" then
                return
            end
            BR.Profiles.CopyProfile(value)
            Components.RefreshAll()
        end,
    })
    profLayout:Add(copyDropdown, 26, COMPONENT_GAP)

    -- Delete dropdown
    local deleteDropdown = Components.Dropdown(profilesContent, {
        label = "刪除",
        labelWidth = PROF_LABEL_WIDTH,
        width = PROF_DROPDOWN_WIDTH,
        options = GetOtherProfileOptions(),
        get = function()
            return ""
        end,
        onChange = function(value)
            if value == "" then
                return
            end
            BR.Profiles.DeleteProfile(value)
            -- RefreshProfileDropdown called below (forward ref via closure)
            RefreshProfileDropdown()
        end,
    })
    profLayout:Add(deleteDropdown, 26, SECTION_GAP)

    -- Rebuild all profile dropdowns after CRUD (defined after all dropdowns exist)
    RefreshProfileDropdown = function()
        local opts = GetProfileOptions()
        local otherOpts = GetOtherProfileOptions()
        profileDropdown.dropdown:SetOptions(opts)
        profileDropdown:SetValue(BR.Profiles.GetActiveProfileName())
        copyDropdown.dropdown:SetOptions(otherOpts)
        copyDropdown:SetValue("")
        deleteDropdown.dropdown:SetOptions(otherOpts)
        deleteDropdown:SetValue("")
    end

    -- Per-spec profiles section (LibDualSpec)
    LayoutSectionHeader(profLayout, profilesContent, "專精專屬設定檔")

    local specDesc = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    specDesc:SetText("當您變更專精時自動切換設定檔。")
    profLayout:AddText(specDesc, 12, COMPONENT_GAP)

    local specEnabled = Components.Checkbox(profilesContent, {
        label = "啟用專精專屬設定檔",
        get = function()
            return BR.Profiles.IsPerSpecEnabled()
        end,
        onChange = function(checked)
            BR.Profiles.SetPerSpecEnabled(checked)
            Components.RefreshAll()
        end,
    })
    profLayout:Add(specEnabled, 20, COMPONENT_GAP)

    -- Per-spec dropdowns
    local numSpecs = GetNumSpecializations() or 0
    local specDropdowns = {}
    for i = 1, numSpecs do
        local _, specName = GetSpecializationInfo(i)
        if specName then
            local specDropdown = Components.Dropdown(profilesContent, {
                label = specName,
                labelWidth = 100,
                width = 150,
                options = GetProfileOptions(),
                get = function()
                    return BR.Profiles.GetSpecProfile(i)
                end,
                enabled = function()
                    return BR.Profiles.IsPerSpecEnabled()
                end,
                onChange = function(value)
                    BR.Profiles.SetSpecProfile(i, value)
                end,
            })
            profLayout:Add(specDropdown, 26, COMPONENT_GAP)
            specDropdowns[i] = specDropdown
        end
    end

    -- Extend RefreshProfileDropdown to also update spec dropdowns
    local baseRefreshProfileDropdown = RefreshProfileDropdown
    RefreshProfileDropdown = function()
        baseRefreshProfileDropdown()
        local opts = GetProfileOptions()
        for _, sd in pairs(specDropdowns) do
            sd.dropdown:SetOptions(opts)
        end
    end

    -- Export so popup dialogs can call it
    BR.Options.RefreshProfileDropdown = function()
        RefreshProfileDropdown()
    end

    -- Export section
    LayoutSectionHeader(profLayout, profilesContent, "匯出設定")

    local exportDesc = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    exportDesc:SetText("複製下面的字串以與其他人分享您的設定。")
    profLayout:AddText(exportDesc, 12, COMPONENT_GAP)

    local exportTextArea = Components.TextArea(profilesContent, {
        width = PANEL_WIDTH - COL_PADDING * 2,
        height = 50,
    })
    profLayout:Add(exportTextArea, 50, COMPONENT_GAP)

    local exportButton = CreateButton(profilesContent, "匯出", function()
        local exportString, err = BuffReminders:Export()
        if exportString then
            exportTextArea:SetText(exportString)
            exportTextArea:HighlightText()
            exportTextArea:SetFocus()
        else
            exportTextArea:SetText("錯誤: " .. (err or "匯出失敗"))
        end
    end)
    profLayout:Add(exportButton, 22, SECTION_GAP)

    -- Import section
    LayoutSectionHeader(profLayout, profilesContent, "匯入設定")

    local importDesc = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    importDesc:SetText("在下面貼上設定字串。這將覆蓋您當前啟用的設定檔。")
    profLayout:AddText(importDesc, 12, COMPONENT_GAP)

    local importTextArea = Components.TextArea(profilesContent, {
        width = PANEL_WIDTH - COL_PADDING * 2,
        height = 50,
    })
    profLayout:Add(importTextArea, 50, COMPONENT_GAP)

    local importStatus = profilesContent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    importStatus:SetWidth(PANEL_WIDTH - COL_PADDING * 2 - 120)
    importStatus:SetJustifyH("LEFT")
    importStatus:SetText("")

    local importButton = CreateButton(profilesContent, "匯入", function()
        local importString = importTextArea:GetText()
        local success, err = BuffReminders:Import(importString)
        if success then
            importStatus:SetText("|cff00ff00設定已成功匯入！|r")
            StaticPopup_Show("BUFFREMINDERS_RELOAD_UI")
        else
            importStatus:SetText("|cffff0000錯誤: " .. (err or "未知的錯誤") .. "|r")
        end
    end)
    profLayout:Add(importButton, 22)
    importStatus:SetPoint("LEFT", importButton, "RIGHT", 10, 0)

    profilesContent:SetHeight(abs(profLayout:GetY()) + 50)

    -- ========== BOTTOM BUTTONS ==========
    local bottomFrame = CreateFrame("Frame", nil, panel)
    bottomFrame:SetPoint("BOTTOMLEFT", 0, 0)
    bottomFrame:SetPoint("BOTTOMRIGHT", 0, 0)
    bottomFrame:SetHeight(45)
    bottomFrame:SetFrameLevel(panel:GetFrameLevel() + 10)

    local separator = bottomFrame:CreateTexture(nil, "ARTWORK")
    separator:SetSize(PANEL_WIDTH - 40, 1)
    separator:SetPoint("TOP", 0, -5)
    separator:SetColorTexture(0.3, 0.3, 0.3, 1)

    local btnHolder = CreateFrame("Frame", nil, bottomFrame)
    btnHolder:SetPoint("TOP", separator, "BOTTOM", 0, -8)
    btnHolder:SetSize(1, 22)

    local BTN_WIDTH = 80

    local lockBtn = CreateButton(btnHolder, "解鎖", function()
        BR.Display.ToggleLock()
        Components.RefreshAll()
    end, { title = "鎖定 / 解鎖", desc = "解鎖以顯示用於重新定位增益框架的定位點。" }, {
        border = { 0.7, 0.58, 0, 1 },
        borderHover = { 1, 0.82, 0, 1 },
        text = { 1, 0.82, 0, 1 },
    })
    lockBtn:SetSize(BTN_WIDTH, 22)
    lockBtn:SetPoint("RIGHT", btnHolder, "CENTER", -4, 0)

    function lockBtn:Refresh()
        self.text:SetText(BR.profile.locked and "解鎖" or "鎖定")
    end
    lockBtn:Refresh()
    tinsert(BR.RefreshableComponents, lockBtn)

    local unlockBanner = Components.Banner(panel, {
        text = "點擊定位點以更新其定位點或座標",
        color = "orange",
        icon = "services-icon-warning",
        bgAlpha = 0.95,
        visible = function()
            return not BR.profile.locked
        end,
    })
    unlockBanner:SetPoint("TOPLEFT", panel, "BOTTOMLEFT", 0, 0)
    unlockBanner:SetPoint("TOPRIGHT", panel, "BOTTOMRIGHT", 0, 0)

    local testBtn = CreateButton(btnHolder, "Stop Test", function(self)
        local isOn = ToggleTestMode()
        self.text:SetText(isOn and "停止測試" or "測試")
    end, {
        title = "測試圖示的外觀",
        desc = "顯示您選擇要模擬的增益，以便您可以預覽它們的外觀。",
    })
    testBtn:SetText("測試")
    testBtn:SetSize(BTN_WIDTH, 22)
    testBtn:SetPoint("LEFT", btnHolder, "CENTER", 4, 0)
    panel.testBtn = testBtn

    -- Set initial active tab
    SetActiveTab("buffs")

    return panel
end

local function ShowOptions()
    if not optionsPanel then
        optionsPanel = CreateOptionsPanel()
    end
    if not optionsPanel:IsShown() then
        if optionsPanel.RenderCustomBuffRows then
            optionsPanel.RenderCustomBuffRows()
        end
        if BR.Display.IsTestMode() then
            optionsPanel.testBtn.text:SetText("停止測試")
        else
            optionsPanel.testBtn.text:SetText("測試")
        end
        optionsPanel:Show()
    end
end

local function HideOptions()
    if optionsPanel and optionsPanel:IsShown() then
        optionsPanel:Hide()
    end
end

local function ToggleOptions()
    if optionsPanel and optionsPanel:IsShown() then
        HideOptions()
    else
        ShowOptions()
    end
end

-- Advanced glow settings panel
local glowAdvancedPanel = nil

---@param targetCategory? string nil = global defaults, string = per-category override
ShowGlowAdvanced = function(targetCategory)
    local GlowType = Glow.Type

    if glowAdvancedPanel then
        glowAdvancedPanel:Hide()
        glowAdvancedPanel = nil
    end

    local configPrefix = targetCategory and ("categorySettings." .. targetCategory .. ".") or "defaults."
    local function getSource()
        if targetCategory then
            return (BR.profile.categorySettings and BR.profile.categorySettings[targetCategory]) or {}
        else
            return BR.profile.defaults or {}
        end
    end

    local PANEL_W = 440
    local PANEL_H = 460
    local PREVIEW_SIZE = 64
    local MARGIN = 20

    local panel = CreatePanel("BuffRemindersGlowAdvanced", PANEL_W, PANEL_H, {
        strata = "FULLSCREEN",
        modal = true,
    })

    local titleText = targetCategory
            and ("Glow Settings — " .. targetCategory:sub(1, 1):upper() .. targetCategory:sub(2))
        or "發光設定"
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -10)
    title:SetText("|cffffcc00" .. titleText .. "|r")

    local closeBtn = CreateButton(panel, "x", function()
        panel:Hide()
    end)
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -6, -6)

    local previewKey = "BR_adv_preview"

    -- Content area
    local dynamicHolders = {}
    local staticLayout = Components.VerticalLayout(panel, { x = MARGIN, y = -36 })

    -- Type dropdown (always visible, top-left beside preview)
    local typeOptions = {}
    for i, gt in ipairs(GlowTypes) do
        typeOptions[i] = { label = gt.name, value = i }
    end

    local typeHolder = Components.Dropdown(panel, {
        label = "Type:",
        labelWidth = 40,
        options = typeOptions,
        get = function()
            return getSource().glowType or GlowType.Pixel
        end,
        width = 140,
        onChange = function(val)
            BR.Config.Set(configPrefix .. "glowType", val)
        end,
    }, "BuffRemindersGlowAdvTypeDropdown")
    staticLayout:Add(typeHolder, 30, 4)

    -- Separator
    local sep = panel:CreateTexture(nil, "ARTWORK")
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", MARGIN, staticLayout:GetY())
    sep:SetPoint("RIGHT", panel, "RIGHT", -MARGIN, 0)
    sep:SetColorTexture(0.3, 0.3, 0.3, 0.8)
    staticLayout:Space(10)

    local DYNAMIC_START_Y = staticLayout:GetY()

    -- Preview icon (below separator, top-right)
    local previewFrame = CreateFrame("Frame", nil, panel)
    previewFrame:SetSize(PREVIEW_SIZE, PREVIEW_SIZE)
    previewFrame:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -(MARGIN + 20), DYNAMIC_START_Y)

    local previewIcon = previewFrame:CreateTexture(nil, "ARTWORK")
    previewIcon:SetAllPoints()
    previewIcon:SetTexCoord(TEXCOORD_INSET, 1 - TEXCOORD_INSET, TEXCOORD_INSET, 1 - TEXCOORD_INSET)
    previewIcon:SetTexture(GetBuffTexture(1459))

    local previewBorder = previewFrame:CreateTexture(nil, "BACKGROUND")
    previewBorder:SetPoint("TOPLEFT", -DEFAULT_BORDER_SIZE, DEFAULT_BORDER_SIZE)
    previewBorder:SetPoint("BOTTOMRIGHT", DEFAULT_BORDER_SIZE, -DEFAULT_BORDER_SIZE)
    previewBorder:SetColorTexture(0, 0, 0, 1)

    local function RefreshPreview()
        Glow.StopAll(previewFrame, previewKey)
        local d = getSource()
        local typeIdx = d.glowType or GlowType.Pixel
        local color = d.glowColor
        if typeIdx == GlowType.Proc and not d.glowProcUseCustomColor then
            color = nil
        end
        local size = d.glowSize or 2
        local params = Glow.BuildAdvancedParams(d, typeIdx)
        local xOff = DEFAULT_BORDER_SIZE + (d.glowXOffset or 0)
        local yOff = DEFAULT_BORDER_SIZE + (d.glowYOffset or 0)
        Glow.Start(previewFrame, typeIdx, color, previewKey, size, xOff, yOff, params)
    end

    local SLIDER_SPACING = 24
    local dynamicLayout

    local function AddSlider(config)
        local holder = Components.Slider(panel, config)
        holder:SetPoint("RIGHT", panel, "RIGHT", -MARGIN, 0)
        dynamicLayout:Add(holder, SLIDER_SPACING)
        table.insert(dynamicHolders, holder)
        return holder
    end

    local function AddCheckbox(config)
        local holder = Components.Checkbox(panel, config)
        dynamicLayout:Add(holder, SLIDER_SPACING)
        table.insert(dynamicHolders, holder)
        return holder
    end

    -- Reset keys per glow type (type-specific only)
    local typeResetKeys = {
        [GlowType.Pixel] = { "glowPixelLines", "glowPixelFrequency", "glowPixelLength" },
        [GlowType.AutoCast] = { "glowAutocastScale", "glowAutocastParticles", "glowAutocastFrequency" },
        [GlowType.Border] = { "glowBorderFrequency" },
        [GlowType.Proc] = { "glowProcDuration", "glowProcStartAnim", "glowProcUseCustomColor" },
    }

    local function UnregisterDynamicHolders()
        for _, h in ipairs(dynamicHolders) do
            h:Hide()
            for ri = #BR.RefreshableComponents, 1, -1 do
                if BR.RefreshableComponents[ri] == h then
                    table.remove(BR.RefreshableComponents, ri)
                end
            end
        end
    end

    local function BuildTypeContent()
        -- Hide and unregister old dynamic components
        UnregisterDynamicHolders()
        wipe(dynamicHolders)
        dynamicLayout = Components.VerticalLayout(panel, { x = MARGIN, y = DYNAMIC_START_Y })

        local d = getSource()
        local typeIdx = d.glowType or GlowType.Pixel

        -- Size + Color row
        local sizeHolder
        if typeIdx == GlowType.Pixel or typeIdx == GlowType.Border then
            sizeHolder = Components.NumericStepper(panel, {
                label = "大小:",
                labelWidth = 34,
                min = 1,
                max = 10,
                step = 1,
                get = function()
                    return getSource().glowSize or 2
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. "glowSize", val)
                    RefreshPreview()
                end,
            })
            table.insert(dynamicHolders, sizeHolder)
        end

        local colorSwatchHolder
        local procColorCheckbox
        if typeIdx == GlowType.Proc then
            -- Proc: optional custom color (desaturated + vertex color, less vibrant than default)
            procColorCheckbox = Components.Checkbox(panel, {
                label = "使用自訂顏色",
                tooltip = {
                    title = "使用自訂顏色",
                    desc = "啟用後，觸發發光會降低飽和度並重新著色。\n這看起來沒有預設觸發發光那麼鮮豔。",
                },
                get = function()
                    return getSource().glowProcUseCustomColor or false
                end,
                onChange = function(checked)
                    BR.Config.Set(configPrefix .. "glowProcUseCustomColor", checked)
                    Components.RefreshAll()
                    RefreshPreview()
                end,
            })
            table.insert(dynamicHolders, procColorCheckbox)

            colorSwatchHolder = Components.ColorSwatch(panel, {
                hasOpacity = true,
                enabled = function()
                    return getSource().glowProcUseCustomColor or false
                end,
                get = function()
                    local c = getSource().glowColor or Glow.DEFAULT_COLOR
                    return c[1], c[2], c[3], c[4] or 1
                end,
                onChange = function(r, g, b, a)
                    BR.Config.Set(configPrefix .. "glowColor", { r, g, b, a or 1 })
                    RefreshPreview()
                end,
            })
            table.insert(dynamicHolders, colorSwatchHolder)
        else
            colorSwatchHolder = Components.ColorSwatch(panel, {
                hasOpacity = true,
                get = function()
                    local c = getSource().glowColor or Glow.DEFAULT_COLOR
                    return c[1], c[2], c[3], c[4] or 1
                end,
                onChange = function(r, g, b, a)
                    BR.Config.Set(configPrefix .. "glowColor", { r, g, b, a or 1 })
                    RefreshPreview()
                end,
            })
            table.insert(dynamicHolders, colorSwatchHolder)
        end

        if sizeHolder and colorSwatchHolder and not procColorCheckbox then
            dynamicLayout:Add(sizeHolder, 26)
            colorSwatchHolder:SetPoint("LEFT", sizeHolder, "RIGHT", 8, 0)
        elseif sizeHolder then
            dynamicLayout:Add(sizeHolder, 26)
        elseif colorSwatchHolder and not procColorCheckbox then
            dynamicLayout:Add(colorSwatchHolder, 26)
        end

        if procColorCheckbox then
            dynamicLayout:Add(procColorCheckbox, SLIDER_SPACING)
            colorSwatchHolder:SetPoint("LEFT", procColorCheckbox, "RIGHT", 8, 0)
        end

        -- Type-specific parameters
        if typeIdx == GlowType.Pixel then
            -- Pixel
            AddSlider({
                label = "線條",
                min = 1,
                max = 20,
                step = 1,
                get = function()
                    return getSource().glowPixelLines or 8
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. "glowPixelLines", val)
                    RefreshPreview()
                end,
            })
            AddSlider({
                label = "頻率",
                min = 0.01,
                max = 1,
                step = 0.01,
                get = function()
                    return getSource().glowPixelFrequency or 0.25
                end,
                formatValue = function(val)
                    return string.format("%.2f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. "glowPixelFrequency", val)
                    RefreshPreview()
                end,
            })
            AddSlider({
                label = "長度",
                min = 1,
                max = 20,
                step = 1,
                get = function()
                    return getSource().glowPixelLength or 10
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. "glowPixelLength", val)
                    RefreshPreview()
                end,
            })
        elseif typeIdx == GlowType.AutoCast then
            -- AutoCast
            AddSlider({
                label = "縮放",
                min = 1,
                max = 3,
                step = 0.1,
                get = function()
                    return getSource().glowAutocastScale or 1
                end,
                formatValue = function(val)
                    return string.format("%.1f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. "glowAutocastScale", val)
                    RefreshPreview()
                end,
            })
            AddSlider({
                label = "粒子",
                min = 1,
                max = 8,
                step = 1,
                get = function()
                    return getSource().glowAutocastParticles or 4
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. "glowAutocastParticles", val)
                    RefreshPreview()
                end,
            })
            AddSlider({
                label = "頻率",
                min = 0.01,
                max = 1,
                step = 0.01,
                get = function()
                    return getSource().glowAutocastFrequency or 0.125
                end,
                formatValue = function(val)
                    return string.format("%.2f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. "glowAutocastFrequency", val)
                    RefreshPreview()
                end,
            })
        elseif typeIdx == GlowType.Border then
            -- Border
            AddSlider({
                label = "速度",
                min = 0.1,
                max = 2,
                step = 0.1,
                get = function()
                    return getSource().glowBorderFrequency or 0.6
                end,
                formatValue = function(val)
                    return string.format("%.1f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. "glowBorderFrequency", val)
                    RefreshPreview()
                end,
            })
        elseif typeIdx == GlowType.Proc then
            -- Proc
            AddSlider({
                label = "持續時間",
                min = 0.1,
                max = 3,
                step = 0.1,
                get = function()
                    return getSource().glowProcDuration or 1
                end,
                formatValue = function(val)
                    return string.format("%.1f", val)
                end,
                onChange = function(val)
                    BR.Config.Set(configPrefix .. "glowProcDuration", val)
                    RefreshPreview()
                end,
            })
            AddCheckbox({
                label = "開始動畫",
                get = function()
                    return getSource().glowProcStartAnim or false
                end,
                onChange = function(checked)
                    BR.Config.Set(configPrefix .. "glowProcStartAnim", checked)
                    RefreshPreview()
                end,
            })
        end

        -- Offsets
        AddSlider({
            label = "水平偏移",
            min = -10,
            max = 10,
            step = 1,
            get = function()
                return getSource().glowXOffset or 0
            end,
            onChange = function(val)
                BR.Config.Set(configPrefix .. "glowXOffset", val)
                RefreshPreview()
            end,
        })
        AddSlider({
            label = "垂直偏移",
            min = -10,
            max = 10,
            step = 1,
            get = function()
                return getSource().glowYOffset or 0
            end,
            onChange = function(val)
                BR.Config.Set(configPrefix .. "glowYOffset", val)
                RefreshPreview()
            end,
        })

        -- Reset button (resets current type's params + shared keys)
        dynamicLayout:Space(8)
        local resetBtn = CreateButton(panel, "重置回預設", function()
            local keys = { "glowColor", "glowSize", "glowXOffset", "glowYOffset" }
            local typeKeys = typeResetKeys[typeIdx]
            if typeKeys then
                for _, k in ipairs(typeKeys) do
                    keys[#keys + 1] = k
                end
            end
            for _, key in ipairs(keys) do
                BR.Config.Set(configPrefix .. key, nil)
            end
            BuildTypeContent()
            RefreshPreview()
            Components.RefreshAll()
        end)
        resetBtn:SetSize(140, 24)
        dynamicLayout:Add(resetBtn, 24)
        table.insert(dynamicHolders, resetBtn)

        -- Adjust panel height
        panel:SetHeight(math.abs(dynamicLayout:GetY()) + 46)

        RefreshPreview()
    end

    BuildTypeContent()

    -- Subscribe to glow type changes to rebuild type-specific content
    local function OnSettingChanged(_, path)
        if path == configPrefix .. "glowType" then
            BuildTypeContent()
        end
    end
    BR.CallbackRegistry:RegisterCallback("SettingChanged", OnSettingChanged, panel)

    panel:SetScript("OnHide", function()
        Glow.StopAll(previewFrame, previewKey)
        BR.CallbackRegistry:UnregisterCallback("SettingChanged", panel)
        UnregisterDynamicHolders()
    end)

    glowAdvancedPanel = panel
end

-- Delete confirmation dialog for custom buffs
StaticPopupDialogs["BUFFREMINDERS_DELETE_CUSTOM"] = {
    text = '要刪除自訂增益 "%s" 嗎？',
    button1 = "刪除",
    button2 = CANCEL,
    OnAccept = function(_, data)
        if data and data.key then
            BR.profile.customBuffs[data.key] = nil
            BR.profile.enabledBuffs[data.key] = nil
            RemoveCustomBuffFrame(data.key)
            if data.refreshPanel then
                data.refreshPanel()
            end
            UpdateDisplay()
        end
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BUFFREMINDERS_RESET_DEFAULTS"] = {
    text = "是否要重置增益提醒成預設值?\n\n這會清除當前設定檔所有自訂設定\n並且重新載入介面。",
    button1 = RESET,
    button2 = CANCEL,
    OnAccept = function()
        BR.Profiles.ResetProfile()
        ReloadUI()
    end,
    showAlert = true,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BUFFREMINDERS_RELOAD_UI"] = {
    text = "設定已成功匯入！\n重載介面以套用變更？",
    button1 = "重載",
    button2 = CANCEL,
    OnAccept = function()
        ReloadUI()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function CreateNewProfile(name)
    if name == "" then
        return
    end
    local copyFrom = BR.Profiles.GetActiveProfileName()
    BR.Profiles.BatchOperation(function()
        BR.aceDB:SetProfile(name)
        BR.aceDB:CopyProfile(copyFrom)
    end)
    if BR.Options.RefreshProfileDropdown then
        BR.Options.RefreshProfileDropdown()
    end
end

StaticPopupDialogs["BUFFREMINDERS_NEW_PROFILE"] = {
    text = "輸入新設定檔的名稱:",
    button1 = "建立",
    button2 = CANCEL,
    hasEditBox = true,
    editBoxWidth = 200,
    OnAccept = function(self)
        CreateNewProfile(self.EditBox:GetText():trim())
    end,
    EditBoxOnEnterPressed = function(self)
        CreateNewProfile(self:GetText():trim())
        self:GetParent():Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

StaticPopupDialogs["BUFFREMINDERS_DISCORD_URL"] = {
    text = "加入 BuffReminders 的 Discord!\n複製以下網址 (Ctrl+C):",
    button1 = "關閉",
    hasEditBox = true,
    editBoxWidth = 250,
    OnShow = function(self)
        self.EditBox:SetText("https://discord.gg/qezQ2hXJJ7")
        self.EditBox:HighlightText()
        self.EditBox:SetFocus()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}

-- Custom buff add/edit modal dialog
ShowCustomBuffModal = function(existingKey, refreshPanelCallback)
    if customBuffModal then
        customBuffModal:Hide()
    end

    local MODAL_WIDTH = 460
    local BASE_HEIGHT = 636
    local ROW_HEIGHT = 26
    local CONTENT_LEFT = 20
    local ROWS_START_Y = -60
    local editingBuff = existingKey and BR.profile.customBuffs[existingKey] or nil
    local noop = function() end

    local existingSpellIDs = {}
    if editingBuff then
        if type(editingBuff.spellID) == "table" then
            for _, id in ipairs(editingBuff.spellID) do
                tinsert(existingSpellIDs, id)
            end
        else
            tinsert(existingSpellIDs, editingBuff.spellID)
        end
    end

    local modal = CreatePanel("BuffRemindersCustomBuffModal", MODAL_WIDTH, BASE_HEIGHT, {
        bgColor = { 0.1, 0.1, 0.1, 0.98 },
        borderColor = { 0.4, 0.4, 0.4, 1 },
        level = 200,
        modal = true,
    })

    local spellRows, nameBox, overlayBox
    local castSpellEditBox, castItemEditBox, macroEditBox, requireItemEditBox, requireItemModeDropdown

    modal:SetScript("OnHide", function()
        if spellRows then
            for _, rowData in ipairs(spellRows) do
                if rowData.editBox then
                    rowData.editBox:ClearFocus()
                end
            end
        end
        if nameBox then
            nameBox:ClearFocus()
        end
        if overlayBox then
            overlayBox:ClearFocus()
        end
        if castSpellEditBox then
            castSpellEditBox:ClearFocus()
        end
        if castItemEditBox then
            castItemEditBox:ClearFocus()
        end
        if macroEditBox then
            macroEditBox:ClearFocus()
        end
        if requireItemEditBox then
            requireItemEditBox:ClearFocus()
        end
    end)

    local modalTitle = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    modalTitle:SetPoint("TOP", 0, -12)
    modalTitle:SetText(editingBuff and "編輯自訂增益" or "新增自訂增益")

    local modalCloseBtn = CreateButton(modal, "x", function()
        modal:Hide()
    end)
    modalCloseBtn:SetSize(22, 22)
    modalCloseBtn:SetPoint("TOPRIGHT", -5, -5)

    local spellIdsLabel = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    spellIdsLabel:SetPoint("TOPLEFT", CONTENT_LEFT, -40)
    spellIdsLabel:SetText("法術ID:")

    spellRows = {}

    local addSpellBtn, sectionsFrame
    local showIconToggle
    local glowModeDropdown, requireSpellKnownToggle
    local classDropdownHolder
    local specDropdownHolder
    local actionTypeDropdown
    local actionInputHolder

    local function UpdateLayout()
        local rowCount = #spellRows

        for i, rowData in ipairs(spellRows) do
            rowData.frame:ClearAllPoints()
            rowData.frame:SetPoint("TOPLEFT", modal, "TOPLEFT", CONTENT_LEFT, ROWS_START_Y - ((i - 1) * ROW_HEIGHT))
            if rowCount > 1 then
                rowData.removeBtn:Show()
            else
                rowData.removeBtn:Hide()
            end
        end

        local addBtnY = ROWS_START_Y - (rowCount * ROW_HEIGHT) - 4
        addSpellBtn:ClearAllPoints()
        addSpellBtn:SetPoint("TOPLEFT", modal, "TOPLEFT", CONTENT_LEFT, addBtnY)

        sectionsFrame:ClearAllPoints()
        sectionsFrame:SetPoint("TOPLEFT", modal, "TOPLEFT", CONTENT_LEFT, addBtnY - 28)

        local extraRows = max(0, rowCount - 1)
        modal:SetHeight(BASE_HEIGHT + (extraRows * ROW_HEIGHT))
    end

    local function CreateSpellRow(initialSpellID)
        local rowFrame = CreateFrame("Frame", nil, modal)
        rowFrame:SetSize(MODAL_WIDTH - 40, ROW_HEIGHT - 2)

        local editBox = CreateFrame("EditBox", nil, rowFrame)
        editBox:SetFontObject("GameFontHighlightSmall")
        editBox:SetAutoFocus(false)
        local editContainer = StyleEditBox(editBox)
        editContainer:SetSize(70, 20)
        editContainer:SetPoint("LEFT", 0, 0)
        if initialSpellID then
            editBox:SetText(tostring(initialSpellID))
        end

        local doLookup -- forward declare for onClick
        local lookupBtn = CreateButton(rowFrame, "Lookup", function()
            doLookup()
        end)
        lookupBtn:SetSize(55, 20)
        lookupBtn:SetPoint("LEFT", editContainer, "RIGHT", 5, 0)

        local icon = CreateBuffIcon(rowFrame, 18)
        icon:SetPoint("LEFT", lookupBtn, "RIGHT", 8, 0)
        icon:Hide()

        local nameText = rowFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        nameText:SetPoint("LEFT", icon, "RIGHT", 5, 0)
        nameText:SetPoint("RIGHT", rowFrame, "RIGHT", -28, 0)
        nameText:SetJustifyH("LEFT")
        nameText:SetWordWrap(false)

        local removeBtn = CreateButton(rowFrame, "-", nil)
        removeBtn:SetSize(22, 20)
        removeBtn:SetPoint("RIGHT", 0, 0)
        removeBtn:Hide()

        local rowData = {
            frame = rowFrame,
            editBox = editBox,
            icon = icon,
            nameText = nameText,
            removeBtn = removeBtn,
            validated = false,
            spellID = nil,
            spellName = nil,
        }

        removeBtn:SetScript("OnClick", function()
            for i, rd in ipairs(spellRows) do
                if rd == rowData then
                    rowData.frame:Hide()
                    tremove(spellRows, i)
                    UpdateLayout()
                    break
                end
            end
        end)

        doLookup = function()
            local spellID = tonumber(editBox:GetText())
            if not spellID then
                icon:Hide()
                nameText:SetText("|cffff4d4d無效的ID|r")
                rowData.validated, rowData.spellID, rowData.spellName = false, nil, nil
                return
            end

            local valid, name, iconID = ValidateSpellID(spellID)
            if valid then
                icon:SetTexture(iconID)
                icon:Show()
                nameText:SetText(name or "")
                rowData.validated, rowData.spellID, rowData.spellName = true, spellID, name
            else
                icon:Hide()
                nameText:SetText("|cffff4d4d未找到|r")
                rowData.validated, rowData.spellID, rowData.spellName = false, nil, nil
            end
        end

        tinsert(spellRows, rowData)

        if initialSpellID then
            doLookup()
        end

        return rowData
    end

    addSpellBtn = CreateButton(modal, "+ 新增法術ID", function()
        CreateSpellRow(nil)
        UpdateLayout()
    end)

    -- Sections frame (always visible, below add-spell button)
    sectionsFrame = CreateFrame("Frame", nil, modal)
    sectionsFrame:SetSize(MODAL_WIDTH - 40, 456)

    local secLayout = Components.VerticalLayout(sectionsFrame, { x = 0, y = 0 })

    local function LayoutSeparator()
        local line = sectionsFrame:CreateTexture(nil, "ARTWORK")
        line:SetHeight(1)
        line:SetPoint("TOPLEFT", 0, secLayout:GetY())
        line:SetPoint("RIGHT", 0, 0)
        line:SetColorTexture(0.25, 0.25, 0.25, 0.8)
        secLayout:Space(1)
    end

    -- Appearance section
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, "APPEARANCE")

    local nameHolder = Components.TextInput(sectionsFrame, {
        label = "名稱:",
        value = editingBuff and editingBuff.name or "",
        width = 250,
        labelWidth = 50,
    })
    secLayout:Add(nameHolder, 20, COMPONENT_GAP)
    nameBox = nameHolder.editBox

    local overlayHolder = Components.TextInput(sectionsFrame, {
        label = "文字:",
        value = editingBuff and editingBuff.overlayText and editingBuff.overlayText:gsub("\n", "\\n") or "",
        width = 250,
        labelWidth = 50,
    })
    secLayout:Add(overlayHolder, 20, SECTION_GAP)
    overlayBox = overlayHolder.editBox

    local overlayHint = sectionsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    overlayHint:SetPoint("LEFT", overlayHolder, "RIGHT", 5, 0)
    overlayHint:SetText("(使用 \\n 來換行)")

    -- Conditions section (merges restrictions, visibility, advanced)
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, "CONDITIONS")

    local classOptions = {
        { value = nil, label = "任何" },
        { value = "DEATHKNIGHT", label = "死亡騎士" },
        { value = "DEMONHUNTER", label = "惡魔獵人" },
        { value = "DRUID", label = "德魯伊" },
        { value = "EVOKER", label = "喚能師" },
        { value = "HUNTER", label = "獵人" },
        { value = "MAGE", label = "法師" },
        { value = "MONK", label = "武僧" },
        { value = "PALADIN", label = "聖騎士" },
        { value = "PRIEST", label = "牧師" },
        { value = "ROGUE", label = "盜賊" },
        { value = "SHAMAN", label = "薩滿" },
        { value = "WARLOCK", label = "術士" },
        { value = "WARRIOR", label = "戰士" },
    }

    showIconToggle = Components.Toggle(sectionsFrame, {
        label = editingBuff and editingBuff.showWhenPresent and "When active" or "When missing",
        checked = editingBuff and editingBuff.showWhenPresent or false,
        onChange = function(isChecked)
            if isChecked then
                showIconToggle.label:SetText("當啟用時")
            else
                showIconToggle.label:SetText("當缺少時")
            end
        end,
    })

    requireSpellKnownToggle = Components.Toggle(sectionsFrame, {
        label = "只限已知法術",
        checked = editingBuff and editingBuff.requireSpellKnown or false,
        onChange = function() end,
    })
    secLayout:AddRow({ { showIconToggle, 0 }, { requireSpellKnownToggle, 210 } }, COMPONENT_GAP)

    local classRowY = secLayout:GetY()

    local function CreateSpecDropdown(classToken, selectedSpecId)
        if specDropdownHolder then
            specDropdownHolder:Hide()
            specDropdownHolder = nil
        end
        if not classToken then
            return
        end
        local specOptions = BR.CLASS_SPEC_OPTIONS[classToken]
        if not specOptions then
            return
        end
        specDropdownHolder = Components.Dropdown(sectionsFrame, {
            label = "專精:",
            options = specOptions,
            selected = selectedSpecId,
            width = 130,
            labelWidth = 70,
            onChange = function() end,
        })
        specDropdownHolder:SetPoint("TOPLEFT", sectionsFrame, "TOPLEFT", 210, classRowY)
    end

    classDropdownHolder = Components.Dropdown(sectionsFrame, {
        label = "職業:",
        options = classOptions,
        selected = editingBuff and editingBuff.class or nil,
        width = 130,
        labelWidth = 70,
        maxItems = 10,
        onChange = function(value)
            CreateSpecDropdown(value, nil)
        end,
    }, "BuffRemindersCustomClassDropdown")
    secLayout:Add(classDropdownHolder, nil, COMPONENT_GAP)

    -- Initialize spec dropdown for editing existing buff
    if editingBuff and editingBuff.class then
        CreateSpecDropdown(editingBuff.class, editingBuff.requireSpecId)
    end

    -- Require item (item gate)
    local requireItemLabel = sectionsFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    requireItemLabel:SetText("需要物品:")
    requireItemLabel:SetWidth(70)
    requireItemLabel:SetJustifyH("LEFT")
    secLayout:AddText(requireItemLabel, 14, COMPONENT_GAP)

    requireItemEditBox = CreateFrame("EditBox", nil, sectionsFrame)
    requireItemEditBox:SetFontObject("GameFontHighlightSmall")
    requireItemEditBox:SetAutoFocus(false)
    local requireItemContainer = StyleEditBox(requireItemEditBox)
    requireItemContainer:SetSize(70, 20)
    requireItemContainer:SetPoint("LEFT", requireItemLabel, "RIGHT", 5, 0)
    if editingBuff and editingBuff.requireItemID then
        requireItemEditBox:SetText(tostring(editingBuff.requireItemID))
    end

    local requireItemModeOptions = {
        { value = "owned", label = "已裝備/背包" },
        { value = "equipped", label = "已裝備" },
        { value = "bags", label = "在背包" },
    }
    local currentRequireItemMode = editingBuff and editingBuff.requireItemMode or "owned"
    requireItemModeDropdown = Components.Dropdown(sectionsFrame, {
        label = "",
        labelWidth = 0,
        options = requireItemModeOptions,
        selected = currentRequireItemMode,
        width = 120,
        onChange = noop,
    })
    requireItemModeDropdown:SetPoint("LEFT", requireItemContainer, "RIGHT", 5, 0)

    local requireItemHint = sectionsFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    requireItemHint:SetPoint("LEFT", requireItemModeDropdown, "RIGHT", 5, 0)
    requireItemHint:SetText("物品ID — 未找到則隱藏")

    local glowModeOptions = {
        { value = "whenGlowing", label = "發光時檢測" },
        { value = "whenNotGlowing", label = "不發光時檢測" },
        { value = "disabled", label = "停用" },
    }
    local currentGlowMode = editingBuff and editingBuff.glowMode or "disabled"
    glowModeDropdown = Components.Dropdown(sectionsFrame, {
        label = "條發光:",
        options = glowModeOptions,
        selected = currentGlowMode,
        width = 175,
        tooltip = {
            title = "動作列發光反饋",
            desc = "當增益的API受到限制時，M+/PvP/戰鬥期間，使用動作列法術發光的反饋偵測。如果您只想進行增益在場追踪請停用。",
        },
        onChange = noop,
    })
    secLayout:Add(glowModeDropdown, nil, COMPONENT_GAP)

    -- Load conditions section (per-buff content visibility)
    secLayout:Space(SECTION_GAP)
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, "顯示在")

    -- Local state for load conditions (read on save)
    local loadConditions = {}
    if editingBuff and editingBuff.loadConditions then
        for k, v in pairs(editingBuff.loadConditions) do
            if type(v) == "table" then
                loadConditions[k] = {}
                for dk, dv in pairs(v) do
                    loadConditions[k][dk] = dv
                end
            else
                loadConditions[k] = v
            end
        end
    elseif not editingBuff then
        -- New buff defaults: housing off (matches old category-level default)
        loadConditions.housing = false
    end

    -- Reuse VisibilityToggles with a table-backed store instead of DB-backed
    local visToggles = Components.VisibilityToggles(sectionsFrame, {
        store = {
            getContent = function(key)
                return loadConditions[key] ~= false
            end,
            setContent = function(key)
                if loadConditions[key] ~= false then
                    loadConditions[key] = false
                else
                    loadConditions[key] = nil
                end
            end,
            getDiffTable = function(dbKey)
                return loadConditions[dbKey]
            end,
            ensureDiffTable = function(dbKey)
                if not loadConditions[dbKey] then
                    loadConditions[dbKey] = {}
                end
                return loadConditions[dbKey]
            end,
        },
        noAutoRefresh = true,
        onChange = noop,
    })
    secLayout:Add(visToggles, nil, COMPONENT_GAP)

    -- Ready check toggle
    local lcReadyCheckToggle = Components.Toggle(sectionsFrame, {
        label = "只有在準備確認",
        checked = editingBuff and editingBuff.loadConditions and editingBuff.loadConditions.readyCheckOnly or false,
        onChange = function(isChecked)
            loadConditions.readyCheckOnly = isChecked or nil
        end,
    })
    secLayout:Add(lcReadyCheckToggle, nil, COMPONENT_GAP)

    -- Level filter dropdown
    local levelFilterHolder = Components.Dropdown(sectionsFrame, {
        label = "等級:",
        labelWidth = 70,
        width = 150,
        options = {
            { value = "any", label = "任何等級" },
            { value = "maxLevel", label = "只限最大等級" },
            { value = "belowMaxLevel", label = "低於最大等級" },
        },
        get = function()
            local lf = loadConditions.levelFilter
            return lf or "any"
        end,
        onChange = function(val)
            loadConditions.levelFilter = (val ~= "any") and val or nil
        end,
    })
    secLayout:Add(levelFilterHolder, nil, COMPONENT_GAP)

    -- Click action section
    secLayout:Space(SECTION_GAP)
    LayoutSeparator()
    secLayout:Space(8)
    LayoutSectionHeader(secLayout, sectionsFrame, "點擊動作")

    -- Determine existing action type
    local existingActionType = "none"
    if editingBuff then
        if editingBuff.castMacro and editingBuff.castMacro ~= "" then
            existingActionType = "macro"
        elseif editingBuff.castItemID then
            existingActionType = "item"
        elseif editingBuff.castSpellID then
            existingActionType = "spell"
        end
    end

    -- Container for the conditional input (spell/item Lookup or macro text)
    actionInputHolder = CreateFrame("Frame", nil, sectionsFrame)
    actionInputHolder:SetSize(MODAL_WIDTH - 40, 26)

    -- Spell ID input with Lookup
    castSpellEditBox = CreateFrame("EditBox", nil, actionInputHolder)
    castSpellEditBox:SetFontObject("GameFontHighlightSmall")
    castSpellEditBox:SetAutoFocus(false)
    local castSpellContainer = StyleEditBox(castSpellEditBox)
    castSpellContainer:SetSize(70, 20)
    castSpellContainer:SetPoint("LEFT", 0, 0)
    if editingBuff and editingBuff.castSpellID then
        castSpellEditBox:SetText(tostring(editingBuff.castSpellID))
    end

    local castSpellIcon = CreateBuffIcon(actionInputHolder, 18)
    castSpellIcon:SetPoint("LEFT", castSpellContainer, "RIGHT", 68, 0)
    castSpellIcon:Hide()

    local castSpellName = actionInputHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    castSpellName:SetPoint("LEFT", castSpellIcon, "RIGHT", 5, 0)
    castSpellName:SetPoint("RIGHT", actionInputHolder, "RIGHT", 0, 0)
    castSpellName:SetJustifyH("LEFT")
    castSpellName:SetWordWrap(false)

    local castSpellLookupBtn = CreateButton(actionInputHolder, "查詢", function()
        local id = tonumber(castSpellEditBox:GetText())
        if not id then
            castSpellIcon:Hide()
            castSpellName:SetText("|cffff4d4d無效的ID|r")
            return
        end
        local valid, name, iconID = ValidateSpellID(id)
        if valid then
            castSpellIcon:SetTexture(iconID)
            castSpellIcon:Show()
            castSpellName:SetText(name or "")
        else
            castSpellIcon:Hide()
            castSpellName:SetText("|cffff4d4d未找到|r")
        end
    end)
    castSpellLookupBtn:SetSize(55, 20)
    castSpellLookupBtn:SetPoint("LEFT", castSpellContainer, "RIGHT", 5, 0)

    -- Item ID input with Lookup
    castItemEditBox = CreateFrame("EditBox", nil, actionInputHolder)
    castItemEditBox:SetFontObject("GameFontHighlightSmall")
    castItemEditBox:SetAutoFocus(false)
    local castItemContainer = StyleEditBox(castItemEditBox)
    castItemContainer:SetSize(70, 20)
    castItemContainer:SetPoint("LEFT", 0, 0)
    if editingBuff and editingBuff.castItemID then
        castItemEditBox:SetText(tostring(editingBuff.castItemID))
    end

    local castItemIcon = CreateBuffIcon(actionInputHolder, 18)
    castItemIcon:SetPoint("LEFT", castItemContainer, "RIGHT", 68, 0)
    castItemIcon:Hide()

    local castItemName = actionInputHolder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    castItemName:SetPoint("LEFT", castItemIcon, "RIGHT", 5, 0)
    castItemName:SetPoint("RIGHT", actionInputHolder, "RIGHT", 0, 0)
    castItemName:SetJustifyH("LEFT")
    castItemName:SetWordWrap(false)

    local castItemLookupBtn = CreateButton(actionInputHolder, "Lookup", function()
        local id = tonumber(castItemEditBox:GetText())
        if not id then
            castItemIcon:Hide()
            castItemName:SetText("|cffff4d4d無效的ID|r")
            return
        end
        local valid, name, iconID = ValidateItemID(id)
        if valid then
            castItemIcon:SetTexture(iconID)
            castItemIcon:Show()
            castItemName:SetText(name or "")
        else
            castItemIcon:Hide()
            castItemName:SetText("|cffff4d4d未找到 (再次嘗試)|r")
            -- Request item data load for next lookup attempt
            pcall(C_Item.RequestLoadItemDataByID, id)
        end
    end)
    castItemLookupBtn:SetSize(55, 20)
    castItemLookupBtn:SetPoint("LEFT", castItemContainer, "RIGHT", 5, 0)

    -- Macro text input
    local macroHolder = Components.TextInput(actionInputHolder, {
        label = "",
        value = editingBuff and editingBuff.castMacro or "",
        width = MODAL_WIDTH - 80,
        labelWidth = 0,
    })
    macroHolder:SetPoint("LEFT", 0, 0)
    macroEditBox = macroHolder.editBox

    local macroHint = actionInputHolder:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    macroHint:SetPoint("TOPLEFT", 0, -24)
    macroHint:SetText("e.g. /use item:12345\\n/use 13")

    -- Show/hide inputs based on action type
    local function UpdateActionInputVisibility(actionType)
        -- Hide all first
        castSpellContainer:Hide()
        castSpellLookupBtn:Hide()
        castSpellIcon:Hide()
        castSpellName:SetText("")
        castItemContainer:Hide()
        castItemLookupBtn:Hide()
        castItemIcon:Hide()
        castItemName:SetText("")
        macroHolder:Hide()
        macroHint:Hide()

        if actionType == "spell" then
            castSpellContainer:Show()
            castSpellLookupBtn:Show()
            -- Trigger lookup if there's a value
            if castSpellEditBox:GetText() ~= "" then
                local id = tonumber(castSpellEditBox:GetText())
                if id then
                    local valid, name, iconID = ValidateSpellID(id)
                    if valid then
                        castSpellIcon:SetTexture(iconID)
                        castSpellIcon:Show()
                        castSpellName:SetText(name or "")
                    end
                end
            end
        elseif actionType == "item" then
            castItemContainer:Show()
            castItemLookupBtn:Show()
            -- Trigger lookup if there's a value
            if castItemEditBox:GetText() ~= "" then
                local id = tonumber(castItemEditBox:GetText())
                if id then
                    local valid, name, iconID = ValidateItemID(id)
                    if valid then
                        castItemIcon:SetTexture(iconID)
                        castItemIcon:Show()
                        castItemName:SetText(name or "")
                    end
                end
            end
        elseif actionType == "macro" then
            macroHolder:Show()
            macroHint:Show()
        end
    end

    local actionTypeOptions = {
        { value = "none", label = "無" },
        { value = "spell", label = "法術" },
        { value = "item", label = "物品" },
        { value = "macro", label = "巨集" },
    }
    actionTypeDropdown = Components.Dropdown(sectionsFrame, {
        label = "點擊時:",
        options = actionTypeOptions,
        selected = existingActionType,
        width = 120,
        tooltip = {
            title = "點擊動作",
            desc = "當你點擊這個增益圖示時會發生什麼事。法術施放法術，物品使用物品，巨集運行巨集指令。",
        },
        onChange = function(value)
            UpdateActionInputVisibility(value)
        end,
    })
    secLayout:Add(actionTypeDropdown, nil, COMPONENT_GAP)
    secLayout:Add(actionInputHolder, 26)

    -- Initialize visibility for the current action type
    UpdateActionInputVisibility(existingActionType)

    local saveError = modal:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    saveError:SetPoint("BOTTOMLEFT", 20, 42)
    saveError:SetWidth(MODAL_WIDTH - 120)
    saveError:SetJustifyH("LEFT")
    saveError:SetTextColor(1, 0.3, 0.3)

    local cancelBtn = CreateButton(modal, "取消", function()
        modal:Hide()
    end)
    cancelBtn:SetPoint("BOTTOMRIGHT", -20, 15)

    -- Delete button (only when editing existing buff)
    if existingKey and editingBuff then
        local buffName = editingBuff.name or existingKey
        local deleteBtn = CreateButton(modal, "Delete", function()
            modal:Hide()
            StaticPopup_Show("BUFFREMINDERS_DELETE_CUSTOM", buffName, nil, {
                key = existingKey,
                refreshPanel = refreshPanelCallback,
            })
        end)
        deleteBtn:SetPoint("BOTTOMLEFT", 20, 15)
    end

    local saveBtn = CreateButton(modal, "儲存", function()
        local validatedIDs = {}
        local firstName = nil
        for _, rowData in ipairs(spellRows) do
            if rowData.validated and rowData.spellID then
                tinsert(validatedIDs, rowData.spellID)
                if not firstName then
                    firstName = rowData.spellName
                end
            end
        end

        if #validatedIDs == 0 then
            saveError:SetText("請驗證至少一個法術ID")
            return
        end
        saveError:SetText("")

        local spellIDValue = #validatedIDs == 1 and validatedIDs[1] or validatedIDs
        local key = existingKey or GenerateCustomBuffKey(spellIDValue)
        local displayName = nameBox:GetText()
        if displayName == "" then
            displayName = firstName or ("法術 " .. validatedIDs[1])
        end

        local overlayTextValue = strtrim(overlayBox:GetText())
        if overlayTextValue ~= "" then
            overlayTextValue = overlayTextValue:gsub("\\n", "\n")
        else
            overlayTextValue = nil
        end

        -- Resolve click action fields based on selected action type
        local selectedAction = actionTypeDropdown:GetValue()
        local castSpellIDValue = nil
        local castItemIDValue = nil
        local castMacroValue = nil
        if selectedAction == "spell" then
            castSpellIDValue = tonumber(strtrim(castSpellEditBox:GetText())) or nil
        elseif selectedAction == "item" then
            castItemIDValue = tonumber(strtrim(castItemEditBox:GetText())) or nil
        elseif selectedAction == "macro" then
            local macroText = strtrim(macroEditBox:GetText())
            if macroText ~= "" then
                castMacroValue = macroText
            end
        end

        -- Only persist loadConditions if any value differs from default (all-enabled)
        -- Clean up difficulty sub-tables where all entries are enabled (true/nil)
        for _, diffKey in ipairs({ "dungeonDifficulty", "raidDifficulty" }) do
            local dt = loadConditions[diffKey]
            if dt then
                local anyOff = false
                for _, v in pairs(dt) do
                    if v == false then
                        anyOff = true
                        break
                    end
                end
                if not anyOff then
                    loadConditions[diffKey] = nil
                end
            end
        end

        local savedLoadConditions = nil
        local function hasNonDefault(t)
            for _, v in pairs(t) do
                if type(v) == "table" then
                    if hasNonDefault(v) then
                        return true
                    end
                else
                    return true
                end
            end
            return false
        end
        if hasNonDefault(loadConditions) then
            savedLoadConditions = loadConditions
        end

        local customBuff = {
            spellID = spellIDValue,
            key = key,
            name = displayName,
            overlayText = overlayTextValue,
            class = classDropdownHolder:GetValue(),
            requireSpecId = specDropdownHolder and specDropdownHolder:GetValue() or nil,
            showWhenPresent = showIconToggle:GetChecked() or nil,
            requireSpellKnown = requireSpellKnownToggle:GetChecked() or nil,
            glowMode = glowModeDropdown:GetValue() ~= "disabled" and glowModeDropdown:GetValue() or nil,
            castSpellID = castSpellIDValue,
            castItemID = castItemIDValue,
            castMacro = castMacroValue,
            requireItemID = tonumber(strtrim(requireItemEditBox:GetText())) or nil,
            requireItemMode = requireItemModeDropdown:GetValue() ~= "owned" and requireItemModeDropdown:GetValue()
                or nil,
            loadConditions = savedLoadConditions,
        }

        BR.profile.customBuffs[key] = customBuff

        if not existingKey then
            CreateCustomBuffFrameRuntime(customBuff)
        else
            UpdateCustomBuffFrame(key, spellIDValue, displayName)
        end

        modal:Hide()
        -- requireItemMode may have changed; clear cached item ownership so the new mode is evaluated
        BR.BuffState.InvalidateItemCache()
        if refreshPanelCallback then
            refreshPanelCallback()
        end
        UpdateDisplay()
    end)
    saveBtn:SetPoint("RIGHT", cancelBtn, "LEFT", -10, 0)

    if #existingSpellIDs > 0 then
        for _, spellID in ipairs(existingSpellIDs) do
            CreateSpellRow(spellID)
        end
    else
        CreateSpellRow(nil)
    end

    UpdateLayout()

    customBuffModal = modal
    modal:Show()
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

BR.Options = {
    Toggle = ToggleOptions,
    Show = ShowOptions,
    Hide = HideOptions,
}
