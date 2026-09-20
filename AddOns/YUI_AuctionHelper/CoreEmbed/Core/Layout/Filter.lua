do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
-------------------------------------------------------------------------------
-- YUI | Layout edit mode - mover visibility filter
-------------------------------------------------------------------------------
local _, YUI = ...
if not YUI or not YUI.Layout or not YUI.Layout._private then return end

local Layout = YUI.Layout
local P = Layout._private
local GUI2 = P.GUI2
local UIParent = P.UIParent
local L = P.L
local ResolveSpecValue = P.ResolveSpecValue
local ResolveEntryFrame = P.ResolveEntryFrame
local SafeCall = P.SafeCall
local ipairs = P.ipairs
local pairs = P.pairs
local type = P.type
local tostring = P.tostring
local math_max = math.max

local FILTER_PANEL_WIDTH = 720
local FILTER_COLUMN_WIDTH = 220
local FILTER_COLUMN_GAP = 12
local FILTER_LEFT = 18
local FILTER_TOP = 50
local FILTER_HEADER_HEIGHT = 22
local FILTER_ROW_HEIGHT = 24
local FILTER_GROUP_GAP = 10

local CATEGORY_ORDER = {
    "actionbar",
    "monitor",
    "combat",
    "communication",
    "map",
    "information",
    "other",
}

local CATEGORY_COLUMN = {
    actionbar = 1,
    monitor = 2,
    combat = 2,
    communication = 3,
    map = 3,
    information = 3,
    other = 3,
}

local CATEGORY_LABEL_KEYS = {
    actionbar = "layout.filter.category.actionbar",
    monitor = "layout.filter.category.monitor",
    combat = "layout.filter.category.combat",
    communication = "layout.filter.category.communication",
    map = "layout.filter.category.map",
    information = "layout.filter.category.information",
    other = "layout.filter.category.other",
}

local FILTER_GROUP_ORDER = {
    "actionbar",
    "monitor.cooldown",
    "monitor.skyriding",
    "combat",
    "communication",
    "map",
    "information",
    "other",
}

local FILTER_GROUP_CATEGORY = {
    actionbar = "actionbar",
    ["monitor.cooldown"] = "monitor",
    ["monitor.skyriding"] = "monitor",
    combat = "combat",
    communication = "communication",
    map = "map",
    information = "information",
    other = "other",
}

local FILTER_GROUP_LABEL_KEYS = {
    actionbar = "layout.filter.group.actionbar",
    ["monitor.cooldown"] = "layout.filter.group.cooldown",
    ["monitor.skyriding"] = "layout.filter.group.skyriding",
    combat = "layout.filter.group.combat",
    communication = "layout.filter.group.communication",
    map = "layout.filter.group.map",
    information = "layout.filter.group.information",
    other = "layout.filter.group.other",
}

local function StartsWith(value, prefix)
    return type(value) == "string" and value:sub(1, #prefix) == prefix
end

function Layout:ResolveEditMoverCategory(entry)
    if type(entry) == "string" then entry = self.frames[entry] end
    if not entry then return "other" end
    local explicit = ResolveSpecValue(entry, "editModeCategory", nil)
    if CATEGORY_COLUMN[explicit] then return explicit end

    local id = tostring(entry.id or "")
    if StartsWith(id, "yactionbar.") then return "actionbar" end
    if StartsWith(id, "yhud.") then return "monitor" end
    if StartsWith(id, "yui.component.class_extra_monitor.")
        or StartsWith(id, "yui.component.focusHelper.")
        or StartsWith(id, "yui.component.mythicPlusTools.")
        or StartsWith(id, "yui.component.combat_enhancement.") then
        return "combat"
    end
    if StartsWith(id, "ychat.")
        or StartsWith(id, "yui.component.chatbar") then
        return "communication"
    end
    if StartsWith(id, "yui.product.ymap.") then return "map" end
    if StartsWith(id, "ybar.") then return "information" end
    return "other"
end

function Layout:GetEditMoverTitle(entry)
    if type(entry) == "string" then entry = self.frames[entry] end
    if not entry then return "" end
    local title = ResolveSpecValue(entry, "title", nil)
    return type(title) == "string" and title ~= "" and title
        or tostring(entry.id)
end

function Layout:ResolveEditMoverFilterGroup(entry)
    if type(entry) == "string" then entry = self.frames[entry] end
    if not entry then return "other" end
    local explicit = ResolveSpecValue(entry, "editModeFilterGroup", nil)
    if FILTER_GROUP_CATEGORY[explicit] then return explicit end
    local category = self:ResolveEditMoverCategory(entry)
    if category == "monitor" then
        return tostring(entry.id) == "yhud.skyriding"
            and "monitor.skyriding" or "monitor.cooldown"
    end
    return FILTER_GROUP_CATEGORY[category] and category or "other"
end

function Layout:GetEditMoverFilterGroupTitle(groupKey)
    return L(FILTER_GROUP_LABEL_KEYS[groupKey]
        or FILTER_GROUP_LABEL_KEYS.other)
end

function Layout:GetEditMoverDefaultVisible(entry)
    if type(entry) == "string" then entry = self.frames[entry] end
    if not entry then return false end
    return ResolveSpecValue(entry, "editModeDefaultVisible", true) ~= false
end

function Layout:ResetEditMoverFilter()
    local values = {}
    for _, id in ipairs(self.order or {}) do
        local entry = self.frames[id]
        if entry then values[id] = self:GetEditMoverDefaultVisible(entry) end
    end
    self.editMoverVisibility = values
    return values
end

function Layout:IsEditMoverVisible(entry)
    if type(entry) == "string" then entry = self.frames[entry] end
    if not entry then return false end
    local values = self.editMoverVisibility
    if type(values) == "table" and values[entry.id] ~= nil then
        return values[entry.id] == true
    end
    return self:GetEditMoverDefaultVisible(entry)
end

local function ApplyEntryVisibility(entry, visible)
    if not entry then return false end
    local id = entry.id
    visible = visible == true
    Layout.editMoverVisibility = Layout.editMoverVisibility or {}
    if Layout:IsEditMoverVisible(entry) == visible then return false end
    Layout.editMoverVisibility[id] = visible

    if not visible and Layout.selectedId == id then
        Layout.selectedId = nil
        Layout:HideMoverPanel(id)
    end
    if type(entry.spec.onEditModeFilterChanged) == "function" then
        SafeCall(
            "Layout:onEditModeFilterChanged:" .. tostring(id),
            entry.spec.onEditModeFilterChanged,
            ResolveEntryFrame(entry),
            visible,
            entry,
            Layout
        )
    end
    Layout:UpdateOverlay(entry)
    return true
end

local function RefreshFilterProjection()
    Layout:RefreshOverlayVisuals()
    Layout:RefreshControlPanel()
    Layout:RefreshSettingsPanel()
    Layout:RefreshAnchorLine()
end

function Layout:SetEditMoverVisible(id, visible)
    local entry = id and self.frames[id]
    if not (self.editing and entry) then return false end
    if not ApplyEntryVisibility(entry, visible) then return false end
    RefreshFilterProjection()
    return true
end

function Layout:IsEditMoverGroupVisible(groupKey)
    local found = false
    for _, entry in ipairs(self.editSessionEntries or {}) do
        if self.editSessionEntrySet
            and self.editSessionEntrySet[entry.id] == entry
            and self:ResolveEditMoverFilterGroup(entry) == groupKey then
            found = true
            if not self:IsEditMoverVisible(entry) then return false end
        end
    end
    return found
end

function Layout:SetEditMoverGroupVisible(groupKey, visible)
    if not self.editing or not FILTER_GROUP_CATEGORY[groupKey] then
        return false
    end
    local changed = false
    for _, entry in ipairs(self.editSessionEntries or {}) do
        if self.editSessionEntrySet
            and self.editSessionEntrySet[entry.id] == entry
            and self:ResolveEditMoverFilterGroup(entry) == groupKey then
            changed = ApplyEntryVisibility(entry, visible) or changed
        end
    end
    if not changed then return false end
    RefreshFilterProjection()
    return true
end

function Layout:CollectEditMoverGroups()
    local byCategory = {}
    for index = 1, #CATEGORY_ORDER do
        byCategory[CATEGORY_ORDER[index]] = {}
    end
    local descriptors = {}
    for index = 1, #FILTER_GROUP_ORDER do
        local groupKey = FILTER_GROUP_ORDER[index]
        local category = FILTER_GROUP_CATEGORY[groupKey]
        local descriptor = {
            key = groupKey,
            category = category,
            entries = {},
        }
        descriptors[groupKey] = descriptor
        byCategory[category][#byCategory[category] + 1] = descriptor
    end
    for _, entry in ipairs(self.editSessionEntries or {}) do
        if self.editSessionEntrySet
            and self.editSessionEntrySet[entry.id] == entry then
            local groupKey = self:ResolveEditMoverFilterGroup(entry)
            local descriptor = descriptors[groupKey] or descriptors.other
            descriptor.entries[#descriptor.entries + 1] = entry
        end
    end
    for category, groups in pairs(byCategory) do
        for index = #groups, 1, -1 do
            if #groups[index].entries == 0 then
                table.remove(groups, index)
            end
        end
    end
    return byCategory
end

local function EnsureFilterPanel()
    if Layout.moverFilterPanel then return Layout.moverFilterPanel end
    local panel = GUI2:CreatePanel(UIParent, {
        name = "YUI_LayoutMoverFilterPanel",
        width = FILTER_PANEL_WIDTH,
        height = 380,
        surface = "color.surface.popup",
        border = "color.popup.border",
        shadow = true,
    })
    panel:SetFrameStrata(P.MOVER_PANEL_STRATA or "HIGH")
    panel:SetFrameLevel((P.MOVER_PANEL_FRAME_LEVEL or 80) + 8)
    panel:SetToplevel(true)
    panel:EnableMouse(true)
    panel:Hide()

    panel.title = GUI2:CreateText(
        panel,
        L("layout.filter.title"),
        "font.size.lg",
        "color.text.heading",
        "LEFT"
    )
    panel.title:SetPoint("TOPLEFT", panel, "TOPLEFT", FILTER_LEFT, -16)
    panel.categoryHeaders = {}
    panel.checkboxes = {}
    Layout.moverFilterPanel = panel
    return panel
end

local function EnsureCategoryHeader(panel, category)
    local header = panel.categoryHeaders[category]
    if not header then
        header = GUI2:CreateText(
            panel,
            "",
            "font.size.md",
            "color.text.accent",
            "LEFT"
        )
        header:SetWidth(FILTER_COLUMN_WIDTH)
        header:SetHeight(FILTER_HEADER_HEIGHT)
        panel.categoryHeaders[category] = header
    end
    header:SetText(L(CATEGORY_LABEL_KEYS[category]))
    return header
end

local function EnsureGroupCheckbox(panel, descriptor)
    local groupKey = descriptor.key
    local checkbox = panel.checkboxes[groupKey]
    if not checkbox then
        checkbox = GUI2.Form:CreateCheckbox(panel, {
            label = Layout:GetEditMoverFilterGroupTitle(groupKey),
            width = FILTER_COLUMN_WIDTH,
            height = FILTER_ROW_HEIGHT,
            get = function()
                return Layout:IsEditMoverGroupVisible(groupKey)
            end,
            set = function(value)
                Layout:SetEditMoverGroupVisible(groupKey, value == true)
            end,
        })
        panel.checkboxes[groupKey] = checkbox
    elseif checkbox.label then
        checkbox.label:SetText(Layout:GetEditMoverFilterGroupTitle(groupKey))
    end
    if checkbox.SetValue then
        checkbox:SetValue(Layout:IsEditMoverGroupVisible(groupKey), true)
    end
    return checkbox
end

function Layout:RefreshMoverFilterPanel()
    local panel = EnsureFilterPanel()
    local groups = self:CollectEditMoverGroups()
    local usedHeaders = {}
    local usedCheckboxes = {}
    local columnY = { 0, 0, 0 }

    for index = 1, #CATEGORY_ORDER do
        local category = CATEGORY_ORDER[index]
        local descriptors = groups[category]
        if #descriptors > 0 then
            local column = CATEGORY_COLUMN[category] or 3
            local x = FILTER_LEFT
                + (column - 1) * (FILTER_COLUMN_WIDTH + FILTER_COLUMN_GAP)
            local y = columnY[column]
            local header = EnsureCategoryHeader(panel, category)
            header:ClearAllPoints()
            header:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -FILTER_TOP - y)
            header:Show()
            usedHeaders[category] = true
            y = y + FILTER_HEADER_HEIGHT
            for groupIndex = 1, #descriptors do
                local descriptor = descriptors[groupIndex]
                local checkbox = EnsureGroupCheckbox(panel, descriptor)
                checkbox:ClearAllPoints()
                checkbox:SetPoint(
                    "TOPLEFT",
                    panel,
                    "TOPLEFT",
                    x,
                    -FILTER_TOP - y
                )
                checkbox:Show()
                usedCheckboxes[descriptor.key] = true
                y = y + FILTER_ROW_HEIGHT
            end
            columnY[column] = y + FILTER_GROUP_GAP
        end
    end

    for category, header in pairs(panel.categoryHeaders) do
        if not usedHeaders[category] then header:Hide() end
    end
    for id, checkbox in pairs(panel.checkboxes) do
        if not usedCheckboxes[id] then checkbox:Hide() end
    end

    local contentHeight = math.max(columnY[1], columnY[2], columnY[3])
    panel:SetHeight(math_max(120, FILTER_TOP + contentHeight + 10))
    panel:ClearAllPoints()
    if self.controlPanel and self.controlPanel:IsShown() then
        panel:SetPoint("TOP", self.controlPanel, "BOTTOM", 0, -8)
    else
        panel:SetPoint("TOP", UIParent, "TOP", 0, -250)
    end
    return true
end

function Layout:ShowMoverFilterPanel()
    if not self.editing then return false end
    local panel = EnsureFilterPanel()
    self:RefreshMoverFilterPanel()
    panel:Show()
    return true
end

function Layout:HideMoverFilterPanel()
    if self.moverFilterPanel then self.moverFilterPanel:Hide() end
    return true
end

function Layout:ToggleMoverFilterPanel()
    local panel = EnsureFilterPanel()
    if panel:IsShown() then
        return self:HideMoverFilterPanel()
    end
    return self:ShowMoverFilterPanel()
end
