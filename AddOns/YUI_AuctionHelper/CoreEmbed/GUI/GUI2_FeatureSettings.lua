do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, addonTable = ...
local YUI = _G.YUI or addonTable
local GUI2 = YUI and YUI.GUI2
if not GUI2 then return end

-- Move explicitly identified switches without replacing their business callbacks.
function GUI2:SplitFeatureSettingsOptions(options)
    local toggles, details = {}, {}
    for _, item in ipairs(options or {}) do
        local fields = item.retainedFields
        if fields then
            for index = #fields, 1, -1 do
                local field = fields[index]
                if field.settingsToggle then
                    toggles[field.settingsToggle] = field
                    table.remove(fields, index)
                end
            end
        end
        if not fields or #fields > 0 or item.keepWhenEmpty then
            details[#details + 1] = item
        end
    end
    return details, toggles
end

local function FitOptions(options, width)
    for _, item in ipairs(options) do
        if item.width then item.width = math.min(item.width, width) end
        if item.rowWidth then item.rowWidth = math.min(item.rowWidth, width) end
        local controlWidth = math.max(1, width - (item.labelWidth or 120) - (item.gap or 10))
        if item.controlWidth then item.controlWidth = math.min(item.controlWidth, controlWidth) end
        if item.panelWidth then item.panelWidth = math.min(item.panelWidth, controlWidth) end
        if item.children then FitOptions(item.children, width) end
    end
end

function GUI2:CreateFeatureSettingsLayout(parent, opts)
    local settings = YUI.Settings
    local root = self:CreateFrame(parent, { width = opts.width, height = opts.height })
    root.rows, root.pages = {}, {}
    local navWidth, gap = 190, 24
    local separator = self:CreateTexture(root, { layer = "BACKGROUND" })
    separator:SetWidth(self.mult or 1)
    separator:SetPoint("TOPLEFT", navWidth + gap / 2, 0)
    separator:SetPoint("BOTTOMLEFT", navWidth + gap / 2, 0)
    self:SetTexturePaintKey(separator, "color.border.default")
    local scroll = self:CreateScrollFrame(root, { autoHide = true })
    scroll:SetPoint("TOPLEFT", navWidth + gap, 0)
    scroll:SetPoint("BOTTOMRIGHT", -16, 0)
    root.detailScroll = scroll

    local function FindSection(id)
        for _, section in ipairs(root.options.sections) do
            if section.id == id then return section end
        end
    end

    local function RefreshRowIcon(row)
        local section = row.section
        if not section then return end
        local icons = YUI.API and YUI.API.Icons
        local iconData = section.specID and icons and icons.GetScopedSpecIcon
            and icons.GetScopedSpecIcon(section.specID, section.icon, "settings")
        local applied = iconData and icons.ApplyIcon and icons.ApplyIcon(row.icon, iconData)
        if not applied then
            if section.atlas then row.icon:SetAtlas(section.atlas)
            elseif section.icon then
                row.icon:SetTexture(section.icon)
                row.icon:SetTexCoord(0, 1, 0, 1)
            end
        end
        row.icon:SetShown(applied == true or section.atlas ~= nil or section.icon ~= nil)
    end

    function root:RefreshSpecIcons()
        for _, row in pairs(self.rows) do RefreshRowIcon(row) end
    end

    function root:OnIconScopeChanged(_, scope)
        if not scope or scope == "settings" then self:RefreshSpecIcons() end
    end

    root:SetScript("OnShow", function()
        root:RefreshSpecIcons()
        if root.hasSpecIcons and YUI.Event then
            YUI.Event:On("YUI_APPEARANCE_ICON_SET_CHANGED", "RefreshSpecIcons", root)
            YUI.Event:On("YUI_APPEARANCE_ICON_SCOPE_CHANGED", "OnIconScopeChanged", root)
        end
    end)
    root:SetScript("OnHide", function()
        if YUI.Event then YUI.Event:OffOwner(root) end
    end)

    local function RefreshRows()
        for _, row in pairs(root.rows) do
            local section = row.section
            if section then
                local selected = section.id == root.selected
                row.selected = selected
                row.background:SetShown(selected)
                row.accent:SetShown(selected)
                GUI2:SetTextColorKey(row.label, selected and "color.text.accent" or "color.text.primary")
                if row.toggle and section.toggle then
                    row.toggle:SetValue(section.toggle.get(), true)
                    if settings.Search then settings.Search:Bind(section.toggle, row.toggle, row.label) end
                elseif row.status and section.getState then
                    GUI2:SetTexturePaintKey(row.status, section.getState() == true
                        and "color.accent.fill" or "color.control.bg")
                end
                if row.note then
                    local note = section.getNote and section.getNote()
                    row.note:SetText(note or "")
                    row.note:SetShown(note ~= nil and note ~= "")
                end
            end
        end
    end
    root.RefreshStates = RefreshRows

    local function RenderDetail(section, resetScroll)
        local pageKey = root.options.retainPages and section.pageKey or nil
        pageKey = pageKey or (root.options.retainPages and section.id) or "transient"
        for _, page in pairs(root.pages) do page:Hide() end
        local page = root.pages[pageKey]
        if not page then
            page = GUI2:CreateFrame(scroll, { height = 1 })
            if root.options.retainPages then page.yuiRetainedBindings = {} end
            root.pages[pageKey] = page
            page.yuiConfigTopInset = 0
            page.yuiConfigScrollFrame = scroll
            page.yuiConfigAfterRender = function(_, height)
                GUI2:FitScrollContent(scroll, height)
            end
        end
        page:SetWidth(math.max(1, root:GetWidth() - navWidth - gap - 16))
        scroll.child, scroll.scrollChild = page, page
        scroll:SetScrollChild(page)
        local config = {}
        if section.description and section.description ~= "" then
            config[#config + 1] = { type = "text", label = section.description,
                colorKey = "color.text.secondary", justify = "LEFT", wrap = true }
        end
        for _, item in ipairs(section.options or {}) do config[#config + 1] = item end
        FitOptions(config, math.max(1, page:GetWidth() - 40))
        if page.built and page.renderWidth == page:GetWidth() and root.options.retainPages then
            local ok, code = GUI2.Form:RefreshRetainedValues(page, config)
            if not ok then error("Feature settings: " .. tostring(code)) end
        else
            settings:ClearConfig(page)
            if root.options.retainPages then page.yuiRetainedBindings = {} end
            settings:RenderConfig(page, config)
            page.built = true
            page.renderWidth = page:GetWidth()
        end
        if resetScroll then scroll:SetVerticalScroll(0) end
        GUI2:FitScrollContent(scroll)
        page:Show()
        root.detailPage = page
        if root.options.onShowSection then root.options.onShowSection(section.id) end
    end

    function root:Select(id)
        local section = FindSection(id)
        if not section or id == self.selected then return end
        local currentOptions = self.options
        local function Select()
            if self.options ~= currentOptions then return end
            local previous = self.selected
            if self.options.onSelect then self.options.onSelect(id, previous) end
            self.selected = id
            self.previousSelected = id
            RefreshRows()
            RenderDetail(section, true)
        end
        local picker = GUI2.ColorPicker
        if picker and picker:DeferRefresh(self.detailPage, Select) then return end
        Select()
    end

    function root:Refresh(nextOptions)
        self.options = nextOptions
        self.hasSpecIcons = false
        self:SetSize(nextOptions.width, nextOptions.height)
        local selected = FindSection(nextOptions.selected) or nextOptions.sections[1]
        local search = settings.Search
        if search and search.pending then
            local function Matches(item)
                if item.searchId == search.pending.entry.id or item.searchKey == search.pending.entry.key then return true end
                local text = item.searchText or item.formLabel or item.label or item.text
                if not item.searchKey and text and search.Normalize(text) == search.pending.label then return true end
                for _, field in ipairs(item.retainedFields or item.children or {}) do
                    if Matches(field) then return true end
                end
                return false
            end
            for _, section in ipairs(nextOptions.sections) do
                local found = section.toggle and Matches(section.toggle)
                if not found then
                    for _, item in ipairs(section.options or {}) do
                        if Matches(item) then found = true; break end
                    end
                end
                if found then
                    if selected and selected.id ~= section.id and nextOptions.onSelect then
                        nextOptions.onSelect(section.id, self.selected)
                    end
                    selected = section
                    break
                end
            end
        end
        self.selected = selected and selected.id
        for _, row in pairs(self.rows) do row.section = nil; row:Hide() end
        local rowY, group = 0, nil
        for _, section in ipairs(nextOptions.sections) do
            local row = self.rows[section.id]
            if not row then
                row = GUI2:CreateButtonFrame(self, { width = navWidth - 34, height = 36 })
                row.background = GUI2:CreateTexture(row, { layer = "BACKGROUND" })
                row.background:SetPoint("TOPLEFT", -34, 0)
                row.background:SetPoint("BOTTOMRIGHT", 0, 0)
                GUI2:SetTexturePaintKey(row.background, "color.interaction.soft")
                row.accent = GUI2:CreateTexture(row, { layer = "ARTWORK" })
                row.accent:SetSize(2 * (GUI2.mult or 1), 24)
                row.accent:SetPoint("LEFT", -34, 0)
                GUI2:SetTexturePaintKey(row.accent, "color.accent.primary")
                row.icon = GUI2:CreateTexture(row, { layer = "ARTWORK" })
                row.icon:SetSize(20, 20)
                row.icon:SetPoint("LEFT", 2, 0)
                row.label = GUI2:CreateText(row, "", "font.size.md", "color.text.primary")
                row.label:SetPoint("LEFT", 30, 0)
                row.label:SetWidth(navWidth - 68)
                row.label:SetJustifyH("LEFT")
                row.label:SetWordWrap(false)
                row.group = GUI2:CreateText(row, "", "font.size.sm", "color.text.secondary")
                row.group:SetPoint("TOPLEFT", -26, 22)
                row.group:SetWidth(navWidth - 8)
                row.group:SetJustifyH("LEFT")
                row:SetScript("OnClick", function() self:Select(row.section.id) end)
                row:SetScript("OnEnter", function() row.background:Show() end)
                row:SetScript("OnLeave", function() row.background:SetShown(row.selected) end)
                self.rows[section.id] = row
            end
            row.section = section
            if section.specID then self.hasSpecIcons = true end
            local showGroup = section.group and section.group ~= group
            row.group:SetShown(showGroup == true)
            if showGroup then
                rowY = rowY - 28
                row.group:SetText(section.group)
            end
            group = section.group
            row:SetPoint("TOPLEFT", 34, rowY)
            row.label:SetText(section.label)
            RefreshRowIcon(row)
            row.label:ClearAllPoints()
            row.label:SetPoint("LEFT", (section.atlas or section.icon) and 30 or 2, 0)
            row.label:SetWidth(navWidth - ((section.atlas or section.icon) and 68 or 40))
            if section.getNote and not row.note then
                row.note = GUI2:CreateText(row, "", "font.size.sm", "color.text.secondary")
                row.note:SetPoint("TOPLEFT", -26, -32)
                row.note:SetWidth(navWidth - 8)
                row.note:SetJustifyH("LEFT")
                row.note:SetWordWrap(false)
            end
            if section.toggle and not row.toggle then
                row.toggle = GUI2:CreateCheckBox(row, { width = 24, height = 32,
                    get = function() return row.section.toggle.get() end,
                    set = function(value)
                        local field = row.section.toggle
                        field.set(value)
                        if field.onChange then field.onChange(row.toggle, value) end
                        RefreshRows()
                        if self.options.onToggle then self.options.onToggle(row.section.id) end
                    end })
                row.toggle:SetPoint("LEFT", -26, 0)
            end
            if row.toggle then row.toggle:SetShown(section.toggle ~= nil) end
            if section.getState and not row.status then
                row.status = GUI2:CreateTexture(row, { layer = "ARTWORK" })
                row.status:SetSize(18, 18)
                row.status:SetPoint("LEFT", -26, 0)
            end
            if row.status then row.status:SetShown(section.getState ~= nil) end
            row:Show()
            rowY = rowY - (section.getNote and 54 or 40)
        end
        RefreshRows()
        if selected then RenderDetail(selected, self.previousSelected ~= selected.id) end
        self.previousSelected = self.selected
    end
    root:Hide()
    return root
end

-- The owner retains the shell; only stable detail schemas opt into form binding reuse.
function GUI2:BuildFeatureSettingsLayout(owner, options)
    return { { type = "custom", sections = options.sections,
        render = function(parent, x, y, width)
            local elements = YUI.Settings.Elements
            local viewport = elements and elements.scrollFrame
            options.width = width
            options.height = math.max(240, (viewport and viewport:GetHeight() or 480) + y - 35)
            local root = owner.settingsLayout
            if not root then
                root = self:CreateFeatureSettingsLayout(parent, options)
                owner.settingsLayout = root
            end
            root:Hide()
            root:SetParent(parent)
            root:ClearAllPoints()
            root:SetPoint("TOPLEFT", x, y)
            root:Refresh(options)
            root:Show()
            return width, options.height
        end } }
end
