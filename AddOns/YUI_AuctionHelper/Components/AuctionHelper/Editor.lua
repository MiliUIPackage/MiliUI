do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.productEnabled then
        return
    end
end
-------------------------------------------------------------------------------
--- YUI 购物助手 DIY 编辑器
-------------------------------------------------------------------------------

local _, addonNs = ...
local YUI = _G.YUI or addonNs
if not YUI then return end

local GUI2 = YUI.GUI2
local Profiles = YUI.AuctionHelperProfiles
local ItemAPI = YUI.API and YUI.API.Item
local GetItemIcon = _G.GetItemIcon
    or (_G.C_Item and _G.C_Item.GetItemIconByID)
local QUESTION_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"
local ITEM_ICON_SIZE = 36
local L = YUI.Locale and YUI.Locale:Get("AuctionHelper")
    or setmetatable({}, { __index = function(_, key) return tostring(key) end })
if not GUI2 or not Profiles then return end

local Editor = {}
YUI.AuctionHelperEditor = Editor
local Appearance = YUI.AuctionHelperAppearance

local function GetAppearanceTheme()
    local config = Editor.config or Editor.settingsConfig
    local getter = config and config.getDB
    if type(getter) ~= "function" then return "auto" end
    local ok, db = pcall(getter)
    if not ok or type(db) ~= "table" then return "auto" end
    local style = db.themeStyle
    if style == "native" or style == "dark" then return style end
    return "auto"
end

local function RegisterAppearance(frame, heading, role)
    if not Appearance then return end
    Appearance:Register(frame, {
        themeProvider = GetAppearanceTheme,
        heading = heading,
        role = role,
    })
end

local function Notify(message)
    message = message or L["editor.error.generic"]
    if YUI.Print then
        YUI:Print(message)
    elseif _G.UIErrorsFrame and _G.UIErrorsFrame.AddMessage then
        _G.UIErrorsFrame:AddMessage(message, 1, 0.82, 0)
    end
end

local function CreateText(parent, text, size, color, justify)
    local label = GUI2:CreateText(
        parent,
        text or "",
        size or "font.size.md",
        color or "color.text.primary",
        justify or "LEFT"
    )
    return label
end

local function CreateButton(parent, text, width, onClick, tone)
    return GUI2.Form:CreateButton(parent, {
        text = text,
        width = width,
        height = 26,
        tone = tone or "default",
        onClick = onClick,
    })
end

local function ResolveItemIcon(itemID)
    itemID = math.floor(tonumber(itemID) or 0)
    if itemID <= 0 or not GetItemIcon then return QUESTION_ICON, false end
    local icon = GetItemIcon(itemID)
    return icon or QUESTION_ICON, icon ~= nil
end

local function ResolveItemNameAndQuality(itemID)
    itemID = math.floor(tonumber(itemID) or 0)
    if itemID <= 0 then return nil end
    if ItemAPI and ItemAPI.GetInfo then
        local info = ItemAPI.GetInfo(itemID)
        if info and type(info.name) == "string" and info.name ~= "" then
            return info.name, info.quality
        end
    end
    if not _G.GetItemInfo then return nil end
    local name, _, quality = _G.GetItemInfo(itemID)
    if type(name) == "string" and name ~= "" then
        return name, quality
    end
    return nil
end

local function ApplyItemNameQualityColor(label, quality, loaded)
    if loaded and quality ~= nil and ItemAPI and ItemAPI.GetQualityColor then
        local r, g, b = ItemAPI.GetQualityColor(quality)
        if r then
            label.gui2ColorKey = nil
            label:SetTextColor(r, g, b)
            return
        end
    end
    GUI2:SetTextColorKey(label, loaded and "color.text.primary" or "color.text.muted")
end

local function StyleItemTag(label)
    if label.SetFont and GUI2.Fonts and GUI2.Fonts.normal then
        label:SetFont(GUI2.Fonts.normal, 12, "OUTLINE")
    end
    if label.SetShadowOffset then label:SetShadowOffset(1, -1) end
    if label.SetTextColor then label:SetTextColor(1, 0.82, 0) end
    if label.SetWordWrap then label:SetWordWrap(false) end
end

local function ResolveRuntimeItemTag(item)
    if type(item) ~= "table" then return "" end
    local isEnglish = YUI.Locale and YUI.Locale.Current
        and YUI.Locale:Current() == "enUS"
    local tagKey = isEnglish and item.enUSShortTagKey or item.tagKey
    local text = type(item.tag) == "string" and item.tag
        or (tagKey and L[tagKey])
        or ""
    if isEnglish and #text > 6 then text = text:sub(1, 6) end
    return text
end

local function AttachItemTooltip(frame, itemIDProvider)
    if not frame then return end
    frame:EnableMouse(true)
    frame:HookScript("OnEnter", function(self)
        local itemID = type(itemIDProvider) == "function" and itemIDProvider() or itemIDProvider
        itemID = math.floor(tonumber(itemID) or 0)
        if itemID <= 0 or not _G.GameTooltip then return end
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        _G.GameTooltip:SetItemByID(itemID)
        _G.GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function()
        if YUI.HideGameTooltip then
            YUI.HideGameTooltip()
        elseif _G.GameTooltip then
            _G.GameTooltip:Hide()
        end
    end)
end

local function ResolveCraftingQualityInfo(itemID)
    itemID = math.floor(tonumber(itemID) or 0)
    local tradeSkill = _G.C_TradeSkillUI
    if itemID <= 0 or not tradeSkill then return nil end

    local qualityInfo
    local getter = tradeSkill.GetItemReagentQualityInfo
    if getter then
        local ok, result = pcall(getter, itemID)
        if ok then qualityInfo = result end
    end
    if not qualityInfo and tradeSkill.GetItemCraftedQualityInfo then
        local ok, result = pcall(tradeSkill.GetItemCraftedQualityInfo, itemID)
        if ok then qualityInfo = result end
    end
    return type(qualityInfo) == "table" and qualityInfo or nil
end

local function ApplyCraftingQualityBadge(slot, itemID)
    if not slot then return end
    if slot.craftingQualityBadge then slot.craftingQualityBadge:Hide() end

    local qualityInfo = ResolveCraftingQualityInfo(itemID)
    local atlas = qualityInfo and qualityInfo.iconInventory
    if not atlas then return end

    local badge = slot.craftingQualityBadge
    if not badge then
        badge = GUI2:CreateTexture(slot, { layer = "OVERLAY" })
        badge:SetPoint("TOPLEFT", -3, 2)
        badge:SetDrawLayer("OVERLAY", 7)
        slot.craftingQualityBadge = badge
    end
    badge:SetAtlas(atlas, true)
    badge:Show()
end

local function RequestItemData(itemID)
    itemID = math.floor(tonumber(itemID) or 0)
    if itemID > 0 and _G.C_Item and _G.C_Item.RequestLoadItemDataByID then
        _G.C_Item.RequestLoadItemDataByID(itemID)
    end
end

local function ParsePreviewIDs(text, excludeID)
    local values, seen = {}, {}
    excludeID = math.floor(tonumber(excludeID) or 0)
    if excludeID > 0 then seen[excludeID] = true end
    for token in tostring(text or ""):gmatch("%d+") do
        local itemID = math.floor(tonumber(token) or 0)
        if itemID > 0 and not seen[itemID] and #values < 11 then
            values[#values + 1] = itemID
            seen[itemID] = true
        end
    end
    return values
end

local function HexToColor(hex)
    hex = type(hex) == "string" and hex:gsub("#", "") or "3366CC"
    if not hex:match("^%x%x%x%x%x%x$") then hex = "3366CC" end
    return {
        (tonumber(hex:sub(1, 2), 16) or 51) / 255,
        (tonumber(hex:sub(3, 4), 16) or 102) / 255,
        (tonumber(hex:sub(5, 6), 16) or 204) / 255,
        1,
    }
end

local function ColorToHex(value)
    value = type(value) == "table" and value or { 0.2, 0.4, 0.8, 1 }
    local function Byte(component)
        return math.max(0, math.min(255, math.floor(((tonumber(component) or 0) * 255) + 0.5)))
    end
    return ("%02X%02X%02X"):format(Byte(value[1]), Byte(value[2]), Byte(value[3]))
end

local function SetTextureColor(texture, colorKey)
    if not texture then return end
    texture:SetColorTexture(GUI2:GetColor(colorKey))
end

local function CreateTreeRow(parent, opts)
    local row = GUI2:CreateButtonFrame(parent)
    row:SetSize(opts.width or 172, opts.height or 26)

    local background = GUI2:CreateTexture(row, { layer = "BACKGROUND" })
    background:SetAllPoints()
    row.background = background

    local selectedRail = GUI2:CreateTexture(row, { layer = "ARTWORK" })
    selectedRail:SetPoint("TOPLEFT", 0, 0)
    selectedRail:SetPoint("BOTTOMLEFT", 0, 0)
    selectedRail:SetWidth(2)
    SetTextureColor(selectedRail, "color.border.accent")
    selectedRail:SetShown(opts.selected == true)

    local labelLeft = opts.level == 1 and 38 or 42
    if opts.level == 1 then
        local color = HexToColor(opts.color)
        local marker = GUI2:CreateTexture(row, { layer = "ARTWORK" })
        marker:SetSize(3, 14)
        marker:SetPoint("LEFT", 27, 0)
        marker:SetColorTexture(color[1], color[2], color[3], 1)
    else
        local chevronButton = GUI2:CreateButtonFrame(row)
        chevronButton:SetSize(20, opts.height or 26)
        chevronButton:SetPoint("LEFT", 4, 0)
        local chevron = GUI2:CreateTexture(chevronButton, { layer = "ARTWORK" })
        chevron:SetSize(10, 10)
        chevron:SetPoint("CENTER")
        chevron:SetAtlas(opts.expanded and "uitools-icon-chevron-down" or "uitools-icon-chevron-right")
        chevron:SetVertexColor(GUI2:GetColor("color.text.secondary"))
        chevronButton:SetScript("OnClick", opts.onToggle)

        local preset = Profiles:GetIconPreset(opts.icon)
        if preset and preset.atlas then
            local icon = GUI2:CreateTexture(row, { layer = "ARTWORK" })
            icon:SetSize(16, 16)
            icon:SetPoint("LEFT", 23, 0)
            icon:SetAtlas(preset.atlas, false)
        end
    end

    local text = CreateText(
        row,
        opts.text,
        opts.level == 1 and "font.size.md" or "font.size.lg",
        opts.selected and "color.text.accent" or "color.text.primary"
    )
    text:SetPoint("LEFT", labelLeft, 0)
    text:SetPoint("RIGHT", -6, 0)
    text:SetWordWrap(false)
    row.text = text

    local function RefreshBackground(hovered)
        if opts.selected then
            SetTextureColor(background, "color.control.active")
            background:Show()
        elseif hovered then
            SetTextureColor(background, "color.control.hover")
            background:Show()
        else
            background:Hide()
        end
    end
    RefreshBackground(false)
    row:SetScript("OnEnter", function() RefreshBackground(true) end)
    row:SetScript("OnLeave", function() RefreshBackground(false) end)
    row:SetScript("OnClick", opts.onClick)
    return row
end

local function CreateAtlasPicker(parent, value, onChange)
    local picker = GUI2:CreateFrame(parent)
    picker:SetSize(352, 72)
    picker.value = value
    picker.buttons = {}

    local function RefreshSelection()
        for id, button in pairs(picker.buttons) do
            GUI2:SetBorderColor(
                button.backdrop or button,
                id == picker.value and "color.border.accent" or "color.border.default"
            )
            if button.backdrop then
                button.backdrop.gui2Surface = id == picker.value
                    and "color.control.active" or "color.control.bg"
                GUI2:ApplyBackdrop(button.backdrop, button.backdrop.gui2Surface)
            end
        end
    end

    for index, preset in ipairs(Profiles.ICON_PRESETS) do
        local iconID = preset.id
        local button = GUI2:CreateButtonFrame(picker, { template = "BackdropTemplate" })
        button:SetSize(32, 32)
        local column = (index - 1) % 9
        local row = math.floor((index - 1) / 9)
        button:SetPoint("TOPLEFT", column * 40, -(row * 40))
        GUI2:CreateBackdrop(button, false)
        local icon = GUI2:CreateTexture(button, { layer = "ARTWORK" })
        icon:SetSize(20, 20)
        icon:SetPoint("CENTER")
        icon:SetAtlas(preset.atlas, false)
        button:SetScript("OnClick", function()
            if picker.disabled then return end
            if picker.value == iconID then return end
            picker.value = iconID
            RefreshSelection()
            if onChange then onChange(iconID) end
        end)
        picker.buttons[iconID] = button
    end

    function picker:SetDisabled(disabled)
        self.disabled = disabled == true
        for _, button in pairs(self.buttons) do
            button:EnableMouse(not self.disabled)
            button:SetAlpha(self.disabled and 0.45 or 1)
        end
    end

    RefreshSelection()
    return picker
end

local function GetCatalog(config)
    local db = config.getDB()
    return Profiles:Ensure(db, config.getDefaultName())
end

local function GetProfileOptions(config)
    local profiles = Profiles:GetAll(config.getDB(), config.getDefaultName())
    local options = {}
    for _, profile in ipairs(profiles or {}) do
        local name = Profiles:GetProfileName(profile, L)
        if Profiles:IsOfficial(profile) then
            name = string.format(L["profiles.official_option"], name)
        end
        options[#options + 1] = { text = name, value = profile.id }
    end
    return options
end

local function RefreshRuntime(config)
    if config.onChanged then
        config.onChanged()
    elseif YUI.AuctionHelperRefreshShoppingProfile then
        YUI.AuctionHelperRefreshShoppingProfile()
    end
end

local function DestroyChildren(frame)
    if not frame then return end
    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        region:Hide()
    end
end

local modalStack = {}

local function RemoveModal(panel)
    for index = #modalStack, 1, -1 do
        if modalStack[index] == panel then
            table.remove(modalStack, index)
            return
        end
    end
end

local function RefreshModalLevels()
    for index, panel in ipairs(modalStack) do
        local dimmer = panel and panel.dimmer
        if dimmer then
            local baseLevel = 700 + ((index - 1) * 100)
            dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
            dimmer:SetFrameLevel(baseLevel)
            panel:SetFrameLevel(baseLevel + 2)
        end
    end
end

local function CreateModal(width, height, title)
    local dimmer = GUI2:CreateFrame(UIParent)
    dimmer:SetAllPoints(UIParent)
    dimmer:SetFrameStrata("FULLSCREEN_DIALOG")
    dimmer:EnableMouse(true)
    local shade = GUI2:CreateTexture(dimmer, { layer = "BACKGROUND" })
    shade:SetAllPoints()
    shade:SetColorTexture(0, 0, 0, 0.72)

    local panel = GUI2:CreateFrame(dimmer, {
        width = width,
        height = height,
        template = "BackdropTemplate",
    })
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
    panel:EnableMouse(true)

    local heading = CreateText(panel, title, "font.size.xl", "color.text.heading", "CENTER")
    heading:SetPoint("TOPLEFT", 20, -16)
    heading:SetPoint("TOPRIGHT", -20, -16)
    panel.heading = heading
    panel.dimmer = dimmer
    panel.shade = shade
    RegisterAppearance(panel, heading, "dialog")
    function panel:ShowModal()
        RemoveModal(self)
        modalStack[#modalStack + 1] = self
        RefreshModalLevels()
        self.shade:SetAlpha(1)
        self.dimmer:Show()
        if GUI2.FadeIn then
            GUI2:FadeIn(self.shade, {
                from = 0,
                to = 1,
                duration = 0.20,
                owner = self,
                key = "auction-editor-modal-scrim",
            })
        end
        self:Show()
    end
    function panel:HideModal()
        if YUI.Animation and YUI.Animation.StopOwner then
            YUI.Animation:StopOwner(self)
        end
        self:Hide()
        self.shade:SetAlpha(1)
        self.dimmer:Hide()
        RemoveModal(self)
        RefreshModalLevels()
    end
    function panel:Close()
        self:HideModal()
        self.dimmer:SetParent(nil)
    end
    panel:ShowModal()
    return panel
end

local function CreateFloatingWindow(width, height, title)
    local panel = GUI2:CreateFrame(UIParent, {
        width = width,
        height = height,
        template = "BackdropTemplate",
    })
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(500)
    panel:EnableMouse(true)
    panel:SetMovable(true)
    panel:SetClampedToScreen(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function(self)
        self:StartMoving()
    end)
    panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
    end)

    local heading = CreateText(panel, title, "font.size.xl", "color.text.heading", "CENTER")
    heading:SetPoint("TOPLEFT", 20, -16)
    heading:SetPoint("TOPRIGHT", -20, -16)
    panel.heading = heading
    RegisterAppearance(panel, heading, "editor")
    function panel:ShowModal() self:Show() end
    function panel:HideModal() self:Hide() end
    function panel:Close() self:Hide() end
    panel:Hide()
    return panel
end

local function ShowMessage(title, body)
    local panel = CreateModal(390, 170, title)
    local text = CreateText(panel, body, "font.size.md", "color.text.secondary", "CENTER")
    text:SetPoint("TOPLEFT", 24, -58)
    text:SetPoint("TOPRIGHT", -24, -58)
    text:SetHeight(52)
    text:SetWordWrap(true)
    local close = CreateButton(panel, L["common.close"], 100, function()
        panel:Close()
    end, "warning")
    close:SetPoint("BOTTOM", 0, 18)
end

local function ShowDeleteConfirm(config, profileID, onDone)
    local profile = Profiles:GetByID(config.getDB(), profileID, config.getDefaultName())
    if not profile then return end
    if Profiles:IsOfficial(profile) then
        Notify(L["profiles.error.official_read_only"])
        return
    end
    local panel = CreateModal(410, 178, L["profiles.delete_title"])
    local message = CreateText(
        panel,
        string.format(L["profiles.delete_message"], profile.name),
        "font.size.md",
        "color.text.secondary",
        "CENTER"
    )
    message:SetPoint("TOPLEFT", 24, -58)
    message:SetPoint("TOPRIGHT", -24, -58)
    message:SetHeight(52)
    message:SetWordWrap(true)
    local cancel = CreateButton(panel, L["common.cancel"], 100, function()
        panel:Close()
    end)
    cancel:SetPoint("BOTTOMRIGHT", -130, 18)
    local remove = CreateButton(panel, L["common.delete"], 100, function()
        local result, code = Profiles:Delete(
            config.getDB(),
            profileID,
            config.getDefaultName()
        )
        if not result then
            Notify(code == "last_profile"
                and L["profiles.error.last_profile"]
                or L["editor.error.generic"])
            return
        end
        panel:Close()
        RefreshRuntime(config)
        if onDone then onDone(result) end
    end, "danger")
    remove:SetPoint("BOTTOMRIGHT", -20, 18)
end

local function ShowNewProfileDialog(config, onDone)
    local panel = CreateModal(430, 238, L["profiles.new_title"])
    local nameLabel = CreateText(panel, L["profiles.name"])
    nameLabel:SetPoint("TOPLEFT", 24, -58)
    local nameEdit = GUI2.Form:CreateEditBox(panel, {
        width = 382,
        height = 28,
        text = L["profiles.new_default_name"],
        autoFocus = true,
    })
    nameEdit:SetPoint("TOPLEFT", 24, -80)

    local sourceLabel = CreateText(panel, L["profiles.source"])
    sourceLabel:SetPoint("TOPLEFT", 24, -120)
    local sourceOptions = {}
    for _, official in ipairs(Profiles:GetOfficialProfiles()) do
        sourceOptions[#sourceOptions + 1] = {
            text = string.format(
                L["profiles.source.official"],
                Profiles:GetProfileName(official, L)
            ),
            value = official.id,
        }
    end
    sourceOptions[#sourceOptions + 1] = {
        text = L["profiles.source.current"],
        value = "current",
    }
    local source = sourceOptions[1].value
    local sourceDropdown = GUI2.Form:CreateDropdown(panel, {
        width = 382,
        value = source,
        options = sourceOptions,
        onChange = function(_, value)
            source = value
        end,
    })
    sourceDropdown:SetPoint("TOPLEFT", 24, -142)

    local cancel = CreateButton(panel, L["common.cancel"], 100, function()
        panel:Close()
    end)
    cancel:SetPoint("BOTTOMRIGHT", -130, 18)
    local create = CreateButton(panel, L["common.create"], 100, function()
        local profile, code = Profiles:Create(
            config.getDB(),
            nameEdit:GetText(),
            source,
            config.getDefaultName()
        )
        if not profile then
            Notify(code == "invalid_name"
                and L["profiles.error.invalid_name"]
                or L["editor.error.generic"])
            return
        end
        panel:Close()
        RefreshRuntime(config)
        if onDone then onDone(profile) end
    end, "warning")
    create:SetPoint("BOTTOMRIGHT", -20, 18)
    nameEdit:SetScript("OnEnterPressed", function()
        create:Click()
    end)
end

local function CreateMultilineEdit(parent, width, height)
    local scroll = GUI2:CreateScrollFrame(parent)
    scroll:SetSize(width, height)
    scroll:EnableMouseWheel(true)
    local edit = GUI2.Form:CreateEditBox(scroll, {
        width = width - 22,
        height = height,
        text = "",
        autoFocus = false,
    })
    edit:SetMultiLine(true)
    edit:SetTextInsets(10, 10, 8, 8)
    edit:SetJustifyV("TOP")
    edit:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 0)
    scroll:SetScrollChild(edit)

    local function RefreshLayout()
        local viewportWidth = scroll:GetWidth() or width
        local viewportHeight = scroll:GetHeight() or height
        edit:SetWidth(math.max(80, viewportWidth - 22))
        local lines = edit.GetNumLines and edit:GetNumLines() or 1
        edit:SetHeight(math.max(viewportHeight, (lines * 18) + 20))
        if scroll.UpdateScrollChildRect then scroll:UpdateScrollChildRect() end
    end
    edit:HookScript("OnTextChanged", RefreshLayout)
    scroll.RefreshEditLayout = RefreshLayout
    RefreshLayout()
    return scroll, edit
end

local function ShowExportDialog(config)
    local profile = Profiles:GetActive(config.getDB(), config.getDefaultName())
    if not profile then return end
    local value, code = Profiles:Export(profile)
    if not value then
        Notify(code == "serialization_unavailable"
            and L["profiles.error.serialization"]
            or L["editor.error.generic"])
        return
    end
    local panel = CreateModal(620, 310, L["profiles.export_title"])
    local hint = CreateText(panel, L["profiles.export_hint"], "font.size.sm", "color.text.secondary")
    hint:SetPoint("TOPLEFT", 24, -52)
    hint:SetPoint("TOPRIGHT", -24, -52)
    local viewport, edit = CreateMultilineEdit(panel, 572, 180)
    viewport:SetPoint("TOPLEFT", 24, -76)
    edit:SetText(value)
    viewport:RefreshEditLayout()
    edit:HighlightText()
    edit:SetFocus()
    local selectAll = CreateButton(panel, L["profiles.select_all"], 112, function()
        edit:SetFocus()
        edit:HighlightText()
    end)
    selectAll:SetPoint("BOTTOMRIGHT", -140, 18)
    local close = CreateButton(panel, L["common.close"], 110, function()
        panel:Close()
    end, "warning")
    close:SetPoint("BOTTOMRIGHT", -20, 18)
end

local function ShowImportDialog(config, onDone)
    local panel = CreateModal(620, 344, L["profiles.import_title"])
    local hint = CreateText(panel, L["profiles.import_hint"], "font.size.sm", "color.text.secondary")
    hint:SetPoint("TOPLEFT", 24, -52)
    hint:SetPoint("TOPRIGHT", -24, -52)
    local viewport, edit = CreateMultilineEdit(panel, 572, 202)
    viewport:SetPoint("TOPLEFT", 24, -76)
    edit:SetFocus()

    local cancel = CreateButton(panel, L["common.cancel"], 110, function()
        panel:Close()
    end)
    cancel:SetPoint("BOTTOMRIGHT", -140, 18)
    local import = CreateButton(panel, L["common.import"], 110, function()
        local profile, code = Profiles:Import(
            config.getDB(),
            edit:GetText(),
            config.getDefaultName()
        )
        if not profile then
            local message = L["profiles.error.invalid_import"]
            if code == "serialization_unavailable" then
                message = L["profiles.error.serialization"]
            end
            ShowMessage(L["profiles.import_failed"], message)
            return
        end
        panel:Close()
        RefreshRuntime(config)
        if onDone then onDone(profile) end
        ShowMessage(
            L["profiles.import_success"],
            string.format(L["profiles.import_summary"], profile.name, #profile.tabs)
        )
    end, "warning")
    import:SetPoint("BOTTOMRIGHT", -20, 18)
end

function Editor:CreateSettingsSection(parent, config, yPos)
    self.settingsConfig = config
    local title = CreateText(parent, L["profiles.section"], "font.size.sm", "color.text.secondary")
    title:SetPoint("TOPLEFT", 14, yPos)
    yPos = yPos - 20

    local catalog = GetCatalog(config)
    local remove
    local edit
    local function RefreshActionState(profileID)
        local official = Profiles:IsOfficial(profileID)
        if remove then remove:SetDisabled(official) end
        if edit then edit:SetDisabled(official) end
    end
    local dropdown = GUI2.Form:CreateDropdown(parent, {
        width = 272,
        height = 28,
        value = catalog and catalog.activeId,
        options = function() return GetProfileOptions(config) end,
        onChange = function(_, value)
            local profile = Profiles:Select(
                config.getDB(),
                value,
                config.getDefaultName()
            )
            if profile then
                RefreshActionState(profile.id)
                RefreshRuntime(config)
            end
        end,
    })
    dropdown:SetPoint("TOPLEFT", 14, yPos)
    yPos = yPos - 34

    local function RefreshDropdown(profile)
        local latest = GetCatalog(config)
        dropdown:RefreshOptions()
        local profileID = profile and profile.id or (latest and latest.activeId)
        dropdown:SetValue(profileID, true)
        RefreshActionState(profileID)
    end

    remove = CreateButton(parent, L["common.delete"], 86, function()
        local latest = GetCatalog(config)
        ShowDeleteConfirm(config, latest.activeId, RefreshDropdown)
    end, "danger")
    remove:SetPoint("TOPLEFT", 14, yPos)
    local create = CreateButton(parent, L["common.new"], 86, function()
        ShowNewProfileDialog(config, RefreshDropdown)
    end)
    create:SetPoint("LEFT", remove, "RIGHT", 7, 0)
    edit = CreateButton(parent, L["common.edit"], 86, function()
        Editor:Open(config)
    end, "warning")
    edit:SetPoint("LEFT", create, "RIGHT", 7, 0)
    edit:HookScript("OnEnter", function(self)
        local latest = GetCatalog(config)
        if not latest or not Profiles:IsOfficial(latest.activeId) or not _G.GameTooltip then return end
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        _G.GameTooltip:SetText(L["profiles.error.official_read_only"], 1, 1, 1, 1, true)
        _G.GameTooltip:Show()
    end)
    edit:HookScript("OnLeave", function()
        if YUI.HideGameTooltip then
            YUI.HideGameTooltip()
        elseif _G.GameTooltip then
            _G.GameTooltip:Hide()
        end
    end)
    yPos = yPos - 32

    local import = CreateButton(parent, L["profiles.import_string"], 132, function()
        ShowImportDialog(config, RefreshDropdown)
    end)
    import:SetPoint("TOPLEFT", 14, yPos)
    local export = CreateButton(parent, L["profiles.export_string"], 132, function()
        ShowExportDialog(config)
    end)
    export:SetPoint("LEFT", import, "RIGHT", 8, 0)
    yPos = yPos - 38
    RefreshActionState(catalog and catalog.activeId)

    self.settingsProfileDropdown = dropdown
    self.RefreshSettings = function()
        RefreshDropdown()
    end
    return yPos
end

local function FlattenCategory(category)
    local items = {}
    for rowIndex, row in ipairs(category.rows or {}) do
        for itemIndex, item in ipairs(row) do
            items[#items + 1] = {
                item = item,
                rowIndex = rowIndex,
                itemIndex = itemIndex,
            }
        end
    end
    return items
end

local function ParseOtherIDs(text, primaryID)
    local ids = { primaryID }
    local seen = { [primaryID] = true }
    for token in tostring(text or ""):gmatch("%d+") do
        local itemID = tonumber(token)
        if itemID and itemID > 0 and not seen[itemID] and #ids < 12 then
            ids[#ids + 1] = math.floor(itemID)
            seen[itemID] = true
        end
    end
    return ids
end

local function OtherIDsText(ids)
    local values = {}
    for index = 2, #(ids or {}) do
        values[#values + 1] = tostring(ids[index])
    end
    return table.concat(values, " ")
end

local function ValuesEqual(left, right)
    if left == right then return true end
    if type(left) ~= type(right) or type(left) ~= "table" then return false end
    for key, value in pairs(left) do
        if not ValuesEqual(value, right[key]) then return false end
    end
    for key in pairs(right) do
        if left[key] == nil then return false end
    end
    return true
end

function Editor:SetDirtyState(dirty)
    self.dirty = dirty == true
    if not self.dirtyText then return end
    if self.readOnly then
        self.dirtyText:SetText(L["profiles.official_read_only"])
        self.dirtyText:Show()
        return
    end
    if self.dirty then
        self.dirtyText:SetText(L["editor.unsaved"])
        self.dirtyText:Show()
    else
        self.dirtyText:Hide()
    end
end

function Editor:MarkDirty()
    if self.refreshingControls or self.readOnly then return end
    self:SetDirtyState(not ValuesEqual(self.draft, self.cleanDraft))
end

function Editor:RequireEditable()
    if not self.readOnly then return true end
    Notify(L["profiles.error.official_read_only"])
    return false
end

function Editor:RefreshEditorProfileDropdown(profileID)
    local dropdown = self.editorProfileDropdown
    if not dropdown or not self.config then return end
    dropdown:RefreshOptions()
    dropdown:SetValue(profileID or self.profileID, true)
end

function Editor:GetSelection()
    local tab = self.draft and self.draft.tabs[self.selectedTab]
    if not tab then return nil end
    if not self.selectedCategory then return tab end
    return tab.categories[self.selectedCategory]
end

function Editor:MoveSelected(delta)
    if not self:RequireEditable() then return end
    local tabIndex = self.selectedTab
    if self.selectedCategory then
        local categories = self.draft.tabs[tabIndex].categories
        local target = self.selectedCategory + delta
        if target < 1 or target > #categories then return end
        categories[self.selectedCategory], categories[target] =
            categories[target], categories[self.selectedCategory]
        self.selectedCategory = target
    else
        local target = tabIndex + delta
        if target < 1 or target > #self.draft.tabs then return end
        self.draft.tabs[tabIndex], self.draft.tabs[target] =
            self.draft.tabs[target], self.draft.tabs[tabIndex]
        self.selectedTab = target
    end
    self:MarkDirty()
    self:Refresh()
end

function Editor:DeleteSelected()
    if not self:RequireEditable() then return end
    if self.selectedCategory then
        local categories = self.draft.tabs[self.selectedTab].categories
        table.remove(categories, self.selectedCategory)
        self.selectedCategory = nil
    else
        if #self.draft.tabs <= 1 then
            Notify(L["editor.error.last_tab"])
            return
        end
        table.remove(self.draft.tabs, self.selectedTab)
        self.selectedTab = math.max(1, self.selectedTab - 1)
        self.expandedTabs = { [self.selectedTab] = true }
    end
    self.selectedItem = nil
    self:MarkDirty()
    self:Refresh()
end

function Editor:AddTab()
    if not self:RequireEditable() then return end
    if #self.draft.tabs >= Profiles.MAX_TABS then
        Notify(string.format(L["editor.error.max_tabs"], Profiles.MAX_TABS))
        return
    end
    local panel = CreateModal(430, 286, L["editor.add_tab"])
    local nameLabel = CreateText(panel, L["editor.tab_name"])
    nameLabel:SetPoint("TOPLEFT", 24, -58)
    local name = GUI2.Form:CreateEditBox(panel, {
        width = 382, height = 28, text = L["editor.new_tab_name"], autoFocus = true,
    })
    name:SetPoint("TOPLEFT", 24, -80)
    local iconLabel = CreateText(panel, L["editor.tab_icon"])
    iconLabel:SetPoint("TOPLEFT", 24, -120)
    local iconID = "consumable"
    local icons = CreateAtlasPicker(panel, iconID, function(value)
        iconID = value
    end)
    icons:SetPoint("TOPLEFT", 24, -142)
    local cancel = CreateButton(panel, L["common.cancel"], 100, function() panel:Close() end)
    cancel:SetPoint("BOTTOMRIGHT", -130, 18)
    local create = CreateButton(panel, L["common.create"], 100, function()
        local tabName = name:GetText():match("^%s*(.-)%s*$")
        if tabName == "" then return end
        self.draft.tabs[#self.draft.tabs + 1] = {
            name = tabName,
            icon = iconID,
            categories = {},
        }
        self.selectedTab = #self.draft.tabs
        self.selectedCategory = nil
        self.expandedTabs[self.selectedTab] = true
        self:MarkDirty()
        panel:Close()
        self:Refresh()
    end, "warning")
    create:SetPoint("BOTTOMRIGHT", -20, 18)
end

function Editor:AddCategory()
    if not self:RequireEditable() then return end
    local tab = self.draft.tabs[self.selectedTab]
    if not tab or #tab.categories >= Profiles.MAX_CATEGORIES_PER_TAB then return end
    local panel = CreateModal(430, 238, L["editor.add_category"])
    local nameLabel = CreateText(panel, L["editor.category_name"])
    nameLabel:SetPoint("TOPLEFT", 24, -58)
    local name = GUI2.Form:CreateEditBox(panel, {
        width = 382, height = 28, text = L["editor.new_category_name"], autoFocus = true,
    })
    name:SetPoint("TOPLEFT", 24, -80)
    local colorLabel = CreateText(panel, L["editor.category_color"])
    colorLabel:SetPoint("TOPLEFT", 24, -120)
    local categoryColor = "3366CC"
    local color = GUI2.Form:CreateColorPicker(panel, {
        width = 382,
        height = 28,
        field = true,
        hasAlpha = false,
        value = HexToColor(categoryColor),
        set = function(value)
            categoryColor = ColorToHex(value)
        end,
    })
    color:SetPoint("TOPLEFT", 24, -142)
    local cancel = CreateButton(panel, L["common.cancel"], 100, function() panel:Close() end)
    cancel:SetPoint("BOTTOMRIGHT", -130, 18)
    local create = CreateButton(panel, L["common.create"], 100, function()
        local categoryName = name:GetText():match("^%s*(.-)%s*$")
        if categoryName == "" then
            Notify(L["editor.error.invalid_category"])
            return
        end
        tab.categories[#tab.categories + 1] = {
            name = categoryName,
            color = categoryColor,
            rows = {},
        }
        self.selectedCategory = #tab.categories
        self.selectedItem = nil
        self:MarkDirty()
        panel:Close()
        self:Refresh()
    end, "warning")
    create:SetPoint("BOTTOMRIGHT", -20, 18)
end

function Editor:HideItemEditor()
    self.itemEditorGeneration = (self.itemEditorGeneration or 0) + 1
    if self.itemEditorPanel then self.itemEditorPanel:Hide() end
end

function Editor:OpenItemDialog(category, selection)
    local panel = self.itemEditorPanel
    local content = self.itemEditorContent
    if not category or not panel or not content then return end
    local row = selection and category.rows[selection.rowIndex]
    local item = row and row[selection.itemIndex]
    local editing = item ~= nil
    self.itemEditorGeneration = (self.itemEditorGeneration or 0) + 1
    local editorGeneration = self.itemEditorGeneration
    DestroyChildren(content)
    self.itemEditorHeading:SetText(editing and L["editor.edit_item"] or L["editor.add_item"])
    panel:Show()

    local previewPanel = GUI2:CreatePanel(content, {
        width = 276,
        height = 72,
        surface = "color.surface.raised",
        border = "color.border.subtle",
    })
    previewPanel:SetPoint("TOPLEFT", 0, 0)
    local previewButton = GUI2:CreateIconSlot(previewPanel, {
        size = ITEM_ICON_SIZE,
        icon = QUESTION_ICON,
        padding = 2,
    })
    previewButton:SetPoint("LEFT", 10, 0)
    local previewIcon = previewButton.icon
    local previewTag = CreateText(previewButton, "", 12, "color.text.accent", "CENTER")
    previewTag:SetPoint("TOP", 0, -2)
    StyleItemTag(previewTag)
    local previewTitle = CreateText(
        previewPanel,
        L["editor.item_preview"],
        "font.size.xs",
        "color.text.secondary"
    )
    previewTitle:SetPoint("TOPLEFT", previewButton, "TOPRIGHT", 10, 0)
    local previewValue = CreateText(previewPanel, "", "font.size.md", "color.text.primary")
    previewValue:SetPoint("BOTTOMLEFT", previewButton, "BOTTOMRIGHT", 10, 0)
    local previewQualityBadge = GUI2:CreateTexture(previewPanel, { layer = "ARTWORK" })
    previewQualityBadge:SetPoint("LEFT", previewValue, "RIGHT", 5, 0)
    previewQualityBadge:Hide()

    local primaryLabel = CreateText(content, L["editor.primary_item_id"], "font.size.xs", "color.text.secondary")
    primaryLabel:SetPoint("TOPLEFT", 0, -88)
    local primary = GUI2.Form:CreateEditBox(content, {
        width = 276,
        height = 28,
        text = editing and tostring(item.ids[1]) or "",
        autoFocus = not editing,
    })
    primary:SetPoint("TOPLEFT", 0, -108)
    primary:SetNumeric(true)
    primary:SetMaxLetters(10)
    AttachItemTooltip(previewButton, function() return primary:GetText() end)
    local tagLabel = CreateText(content, L["editor.short_tag"], "font.size.xs", "color.text.secondary")
    tagLabel:SetPoint("TOPLEFT", 0, -152)
    local tagHint = CreateText(content, L["editor.short_tag_hint"], "font.size.xs", "color.text.muted", "RIGHT")
    tagHint:SetPoint("TOPRIGHT", 0, -152)
    local tag = GUI2.Form:CreateEditBox(content, {
        width = 276,
        height = 28,
        text = editing and Profiles:ResolveText(item, "tag", "tagKey", L) or "",
    })
    tag:SetPoint("TOPLEFT", 0, -172)
    tag:SetMaxLetters(6)
    local otherLabel = CreateText(content, L["editor.other_quality_ids"], "font.size.xs", "color.text.secondary")
    otherLabel:SetPoint("TOPLEFT", 0, -216)
    local otherHint = CreateText(content, L["editor.other_quality_hint"], "font.size.xs", "color.text.muted", "RIGHT")
    otherHint:SetPoint("TOPRIGHT", 0, -216)
    local other = GUI2.Form:CreateEditBox(content, {
        width = 276,
        height = 28,
        text = editing and OtherIDsText(item.ids) or "",
    })
    other:SetPoint("TOPLEFT", 0, -236)

    local otherPreview = GUI2:CreateFrame(content)
    otherPreview:SetSize(276, 76)
    otherPreview:SetPoint("TOPLEFT", 0, -274)

    local function RenderPreviews(requestLoad)
        local primaryID = math.floor(tonumber(primary:GetText()) or 0)
        local primaryTexture, primaryFound = ResolveItemIcon(primaryID)
        previewButton:SetIcon(primaryTexture)
        previewTag:SetText(tag:GetText():match("^%s*(.-)%s*$"))
        local itemName, itemQuality = ResolveItemNameAndQuality(primaryID)
        previewValue:SetText(itemName or (primaryID > 0 and tostring(primaryID) or L["editor.primary_item_id"]))
        previewQualityBadge:ClearAllPoints()
        previewQualityBadge:SetPoint(
            "LEFT",
            previewValue,
            "LEFT",
            math.min(previewValue:GetStringWidth() or 0, 184) + 5,
            0
        )
        local qualityInfo = ResolveCraftingQualityInfo(primaryID)
        local qualityAtlas = qualityInfo and qualityInfo.iconSmall
        if qualityAtlas then
            previewQualityBadge:SetAtlas(qualityAtlas, true)
            previewQualityBadge:Show()
        else
            previewQualityBadge:Hide()
        end
        ApplyItemNameQualityColor(
            previewValue,
            itemQuality,
            primaryID > 0 and primaryFound and itemName ~= nil
        )

        DestroyChildren(otherPreview)
        local previewIDs = ParsePreviewIDs(other:GetText(), primaryID)
        for index, itemID in ipairs(previewIDs) do
            local texture = ResolveItemIcon(itemID)
            local slot = GUI2:CreateIconSlot(otherPreview, {
                size = ITEM_ICON_SIZE,
                icon = texture,
                padding = 2,
            })
            local column = (index - 1) % 6
            local previewRow = math.floor((index - 1) / 6)
            slot:SetPoint("TOPLEFT", column * 42, -(previewRow * 42))
            AttachItemTooltip(slot, itemID)
            ApplyCraftingQualityBadge(slot, itemID)
        end

        if requestLoad then
            RequestItemData(primaryID)
            for _, itemID in ipairs(previewIDs) do RequestItemData(itemID) end
            if _G.C_Timer and _G.C_Timer.After then
                _G.C_Timer.After(0.25, function()
                    if editorGeneration == self.itemEditorGeneration and panel:IsShown() then
                        RenderPreviews(false)
                    end
                end)
            end
        end
    end
    primary:HookScript("OnTextChanged", function() RenderPreviews(true) end)
    tag:HookScript("OnTextChanged", function() RenderPreviews(false) end)
    other:HookScript("OnTextChanged", function() RenderPreviews(true) end)
    RenderPreviews(true)

    local function ReadItemValues()
        local primaryID = math.floor(tonumber(primary:GetText()) or 0)
        if primaryID <= 0 then
            Notify(L["editor.error.invalid_item"])
            return nil
        end
        return {
            ids = ParseOtherIDs(other:GetText(), primaryID),
            tag = tag:GetText():match("^%s*(.-)%s*$"),
        }
    end

    local function ApplyItemValues()
        local values = ReadItemValues()
        if not values then return false end
        if editing then
            item.ids = values.ids
            item.tag = values.tag
            item.tagKey = nil
            item.enUSShortTagKey = nil
        else
            if #category.rows == 0
                or #category.rows[#category.rows] >= Profiles.MAX_ITEMS_PER_ROW then
                category.rows[#category.rows + 1] = {}
            end
            category.rows[#category.rows][#category.rows[#category.rows] + 1] = values
            self.selectedItem = {
                rowIndex = #category.rows,
                itemIndex = #category.rows[#category.rows],
            }
        end
        self:MarkDirty()
        return true
    end

    local cancel = CreateButton(content, L["common.cancel"], 100, function()
        self:HideItemEditor()
    end)
    local save = CreateButton(
        content,
        editing and L["editor.save_item"] or L["editor.add_to_category"],
        150,
        function()
            if not ApplyItemValues() then return end
            self:HideItemEditor()
            self:RefreshRight()
        end,
        "warning"
    )
    save:SetPoint("BOTTOMRIGHT", 0, 0)
    cancel:SetPoint("RIGHT", save, "LEFT", -8, 0)

end

function Editor:AddItem()
    if not self:RequireEditable() then return end
    local category = self:GetSelection()
    if not self.selectedCategory or not category then return end
    self:OpenItemDialog(category)
end

function Editor:RefreshTree()
    local child = self.treeChild
    DestroyChildren(child)
    self.expandedTabs = self.expandedTabs or {}
    local y = -2
    for tabIndex, tab in ipairs(self.draft.tabs) do
        local currentTabIndex = tabIndex
        local expanded = self.expandedTabs[tabIndex] == true
        local tabButton = CreateTreeRow(child, {
            width = 172,
            height = 29,
            level = 0,
            text = Profiles:ResolveText(tab, "name", "nameKey", L),
            icon = tab.icon,
            expanded = expanded,
            selected = tabIndex == self.selectedTab and not self.selectedCategory,
            onToggle = function()
                self.expandedTabs[currentTabIndex] = not expanded
                self:RefreshTree()
            end,
            onClick = function()
                self.selectedTab = currentTabIndex
                self.selectedCategory = nil
                self.selectedItem = nil
                self.expandedTabs[currentTabIndex] = true
                self:Refresh()
            end,
        })
        tabButton:SetPoint("TOPLEFT", 2, y)
        y = y - 30
        if expanded then
            for categoryIndex, category in ipairs(tab.categories) do
                local currentCategoryIndex = categoryIndex
                local categoryButton = CreateTreeRow(child, {
                    width = 172,
                    height = 25,
                    level = 1,
                    text = Profiles:ResolveText(category, "name", "nameKey", L),
                    color = category.color,
                    selected = tabIndex == self.selectedTab and categoryIndex == self.selectedCategory,
                    onClick = function()
                        self.selectedTab = currentTabIndex
                        self.selectedCategory = currentCategoryIndex
                        self.selectedItem = nil
                        self.expandedTabs[currentTabIndex] = true
                        self:Refresh()
                    end,
                })
                categoryButton:SetPoint("TOPLEFT", 2, y)
                y = y - 26
            end
            y = y - 3
        end
    end
    child:SetHeight(math.max(410, -y + 8))
end

function Editor:RefreshItemButtonSelection()
    for _, entry in ipairs(self.itemButtons or {}) do
        local selected = self.selectedItem
            and self.selectedItem.rowIndex == entry.rowIndex
            and self.selectedItem.itemIndex == entry.itemIndex
        if entry.button.SetSelected then
            entry.button:SetSelected(selected)
        else
            GUI2:SetBorderColor(
                entry.button.backdrop or entry.button,
                selected and "color.border.accent" or "color.border.default"
            )
        end
    end
end

function Editor:SelectItem(category, rowIndex, itemIndex)
    if self.readOnly then return end
    self.selectedItem = { rowIndex = rowIndex, itemIndex = itemIndex }
    self:RefreshItemButtonSelection()
    self:RefreshItemOperations(category)
    self:OpenItemDialog(category, self.selectedItem)
end

function Editor:IsItemSelected(rowIndex, itemIndex)
    local selected = self.selectedItem
    return selected ~= nil
        and selected.rowIndex == rowIndex
        and selected.itemIndex == itemIndex
end

function Editor:GetSelectedItemRow(category)
    local selected = self.selectedItem
    local row = selected and category and category.rows and category.rows[selected.rowIndex]
    local item = row and row[selected.itemIndex]
    return row, item, selected
end

function Editor:RefreshItemOperations(category)
    local operations = self.itemOperationButtons
    if not operations then return end
    local row, item, selected = self:GetSelectedItemRow(category)
    local hasSelection = item ~= nil
    operations.previous:SetShown(hasSelection)
    operations.next:SetShown(hasSelection)
    operations.remove:SetShown(hasSelection)
    operations.lineBreak:SetShown(hasSelection)
    local hasPrevious = hasSelection
        and (selected.itemIndex > 1 or selected.rowIndex > 1)
    local hasNext = hasSelection
        and (selected.itemIndex < #row or selected.rowIndex < #category.rows)
    operations.previous:SetDisabled(not hasPrevious)
    operations.next:SetDisabled(not hasNext)
    operations.lineBreak:SetDisabled(not hasSelection or selected.itemIndex >= #row)
end

function Editor:MoveSelectedItem(category, delta)
    if not self:RequireEditable() then return false end
    local row, item, selected = self:GetSelectedItemRow(category)
    if not item then return false end
    if delta < 0 then
        if selected.itemIndex > 1 then
            local targetIndex = selected.itemIndex - 1
            row[selected.itemIndex], row[targetIndex] = row[targetIndex], row[selected.itemIndex]
            selected.itemIndex = targetIndex
        else
            local previousRow = category.rows[selected.rowIndex - 1]
            local previousIndex = previousRow and #previousRow or 0
            if previousIndex < 1 then return false end
            previousRow[previousIndex], row[1] = row[1], previousRow[previousIndex]
            selected.rowIndex = selected.rowIndex - 1
            selected.itemIndex = previousIndex
        end
    elseif delta > 0 then
        if selected.itemIndex < #row then
            local targetIndex = selected.itemIndex + 1
            row[selected.itemIndex], row[targetIndex] = row[targetIndex], row[selected.itemIndex]
            selected.itemIndex = targetIndex
        else
            local nextRow = category.rows[selected.rowIndex + 1]
            if not nextRow or #nextRow < 1 then return false end
            row[#row], nextRow[1] = nextRow[1], row[#row]
            selected.rowIndex = selected.rowIndex + 1
            selected.itemIndex = 1
        end
    else
        return false
    end
    self:MarkDirty()
    self:RefreshRight()
    return true
end

function Editor:InsertLineBreak(category)
    if not self:RequireEditable() then return false end
    local row, item, selected = self:GetSelectedItemRow(category)
    if not item then
        Notify(L["editor.error.select_item"])
        return false
    end
    if selected.itemIndex >= #row then
        Notify(L["editor.error.already_break"])
        return false
    end

    local nextRow = {}
    for index = selected.itemIndex + 1, #row do
        nextRow[#nextRow + 1] = row[index]
    end
    for index = #row, selected.itemIndex + 1, -1 do
        table.remove(row, index)
    end
    table.insert(category.rows, selected.rowIndex + 1, nextRow)
    self:MarkDirty()
    self:RefreshRight()
    return true
end

function Editor:DeleteSelectedItem(category)
    if not self:RequireEditable() then return false end
    local row, item, selected = self:GetSelectedItemRow(category)
    if not item then return false end
    table.remove(row, selected.itemIndex)
    if #row == 0 then table.remove(category.rows, selected.rowIndex) end
    self.selectedItem = nil
    self:MarkDirty()
    self:HideItemEditor()
    self:RefreshRight()
    return true
end

function Editor:RemoveLineBreak(category, rowIndex)
    if not self:RequireEditable() then return false end
    local first = category and category.rows and category.rows[rowIndex]
    local following = category and category.rows and category.rows[rowIndex + 1]
    if not first or not following then return false end

    local firstCount = #first
    local capacity = math.max(0, Profiles.MAX_ITEMS_PER_ROW - firstCount)
    local moveCount = math.min(capacity, #following)
    for _ = 1, moveCount do
        first[#first + 1] = table.remove(following, 1)
    end

    local selection = self.selectedItem
    if selection and selection.rowIndex == rowIndex + 1 then
        if selection.itemIndex <= moveCount then
            selection.rowIndex = rowIndex
            selection.itemIndex = firstCount + selection.itemIndex
        else
            selection.itemIndex = selection.itemIndex - moveCount
        end
    end

    if #following == 0 then
        table.remove(category.rows, rowIndex + 1)
        if selection and selection.rowIndex > rowIndex + 1 then
            selection.rowIndex = selection.rowIndex - 1
        end
    end
    return moveCount > 0
end

function Editor:RefreshRight()
    local panel = self.rightContent
    local operationsPanel = self.itemOperationsFrame
    DestroyChildren(panel)
    if operationsPanel then
        DestroyChildren(operationsPanel)
        operationsPanel:Hide()
    end
    self.itemButtons = {}
    self.itemOperationButtons = nil
    panel:SetHeight(440)
    local tab = self.draft.tabs[self.selectedTab]
    if not tab then return end

    local isCategory = self.selectedCategory ~= nil
    local target = isCategory and tab.categories[self.selectedCategory] or tab
    if operationsPanel then operationsPanel:SetShown(isCategory and not self.readOnly) end
    local heading = CreateText(
        panel,
        isCategory and L["editor.category_settings"] or L["editor.tab_settings"],
        "font.size.lg",
        "color.text.heading"
    )
    heading:SetPoint("TOPLEFT", 0, 0)

    local nameLabel = CreateText(
        panel,
        isCategory and L["editor.category_name"] or L["editor.tab_name"],
        "font.size.sm",
        "color.text.secondary"
    )
    nameLabel:SetPoint("TOPLEFT", 0, -34)
    local initialName = target.name
    local initialNameKey = target.nameKey
    local initialDisplayName = Profiles:ResolveText(target, "name", "nameKey", L)
    local name = GUI2.Form:CreateEditBox(panel, {
        width = isCategory and 240 or 280,
        height = 28,
        text = initialDisplayName,
        onChange = function(_, value)
            if self.refreshingControls then return end
            if type(value) ~= "string"
                or value == Profiles:ResolveText(target, "name", "nameKey", L) then
                return
            end
            if value == initialDisplayName then
                target.name = initialName
                target.nameKey = initialNameKey
            else
                target.name = value
                target.nameKey = nil
            end
            self:MarkDirty()
            if self.treeRefreshScheduled then return end
            self.treeRefreshScheduled = true
            C_Timer.After(0, function()
                self.treeRefreshScheduled = nil
                if self.window and self.window:IsShown() then self:RefreshTree() end
            end)
        end,
    })
    name:SetPoint("TOPLEFT", 0, -54)
    if name.SetDisabled then name:SetDisabled(self.readOnly) end

    local moveUp = CreateButton(panel, L["common.move_up"], 88, function()
        self:MoveSelected(-1)
    end)
    moveUp:SetPoint("TOPRIGHT", -94, -54)
    local moveDown = CreateButton(panel, L["common.move_down"], 88, function()
        self:MoveSelected(1)
    end)
    moveDown:SetPoint("TOPRIGHT", 0, -54)
    moveUp:SetDisabled(self.readOnly)
    moveDown:SetDisabled(self.readOnly)

    if not isCategory then
        local iconLabel = CreateText(panel, L["editor.tab_icon"], "font.size.sm", "color.text.secondary")
        iconLabel:SetPoint("TOPLEFT", 0, -96)
        local icons = CreateAtlasPicker(panel, target.icon, function(value)
            if self.refreshingControls then return end
            if value == target.icon then return end
            target.icon = value
            self:MarkDirty()
            self:RefreshTree()
        end)
        icons:SetPoint("TOPLEFT", 0, -116)
        icons:SetDisabled(self.readOnly)
        local help = CreateText(
            panel,
            L["editor.tab_overflow_hint"],
            "font.size.sm",
            "color.text.secondary"
        )
        help:SetPoint("TOPLEFT", 0, -202)
        help:SetPoint("TOPRIGHT", 0, -202)
        help:SetWordWrap(true)
        return
    end

    local colorLabel = CreateText(panel, L["editor.category_color"], "font.size.sm", "color.text.secondary")
    colorLabel:SetPoint("TOPLEFT", 0, -96)
    local color = GUI2.Form:CreateColorPicker(panel, {
        width = 240,
        height = 28,
        field = true,
        hasAlpha = false,
        value = HexToColor(target.color),
        set = function(value)
            if self.refreshingControls then return end
            local nextColor = ColorToHex(value)
            local currentColor = tostring(target.color or ""):gsub("#", ""):upper()
            if nextColor == currentColor then return end
            target.color = nextColor
            self:MarkDirty()
        end,
    })
    color:SetPoint("TOPLEFT", 0, -116)
    if color.SetDisabled then color:SetDisabled(self.readOnly) end
    local itemsHeading = CreateText(panel, L["editor.category_items"], "font.size.sm", "color.text.heading")
    itemsHeading:SetPoint("TOPLEFT", 0, -164)
    local grid = GUI2:CreateFrame(panel)
    grid:SetPoint("TOPLEFT", 0, -186)
    grid:SetPoint("TOPRIGHT", 0, -186)
    grid:SetHeight(150)

    local y = 0
    for rowIndex, row in ipairs(target.rows) do
        local currentRowIndex = rowIndex
        local x = 0
        for itemIndex, item in ipairs(row) do
            local currentItemIndex = itemIndex
            local button = GUI2:CreateIconSlot(grid, {
                size = ITEM_ICON_SIZE,
                icon = GetItemIcon(item.ids[1]),
                padding = 2,
                selected = self:IsItemSelected(rowIndex, itemIndex),
                onClick = function()
                    self:SelectItem(target, currentRowIndex, currentItemIndex)
                end,
            })
            button:SetPoint("TOPLEFT", x, y)
            local tag = CreateText(
                button,
                ResolveRuntimeItemTag(item),
                12,
                "color.text.accent",
                "CENTER"
            )
            tag:SetPoint("TOP", 0, -2)
            StyleItemTag(tag)
            self.itemButtons[#self.itemButtons + 1] = {
                button = button,
                rowIndex = currentRowIndex,
                itemIndex = currentItemIndex,
            }
            AttachItemTooltip(button, item.ids[1])
            x = x + 42
        end
        if rowIndex < #target.rows and #row < Profiles.MAX_ITEMS_PER_ROW then
            local marker = GUI2:CreateFrame(grid)
            marker:SetPoint("TOPLEFT", 0, y - 43)
            marker:SetPoint("TOPRIGHT", 0, y - 43)
            marker:SetHeight(20)

            local line = GUI2:CreateTexture(marker, { layer = "BACKGROUND" })
            line:SetPoint("LEFT", 0, 0)
            line:SetPoint("RIGHT", 0, 0)
            line:SetHeight(1)
            SetTextureColor(line, "color.border.subtle")

            local removeBreak = GUI2:CreateButtonFrame(marker)
            removeBreak:SetHeight(20)
            local removeText = CreateText(
                removeBreak,
                L["editor.remove_line_break"],
                "font.size.xs",
                "color.text.accent",
                "RIGHT"
            )
            local removeTextWidth = removeText.GetStringWidth and removeText:GetStringWidth() or 0
            removeBreak:SetWidth(math.max(108, math.ceil(removeTextWidth) + 12))
            removeBreak:SetPoint("RIGHT", -4, 0)
            removeText:SetAllPoints()
            removeBreak:SetScript("OnEnter", function()
                GUI2:SetTextColorKey(removeText, "color.text.primary")
            end)
            removeBreak:SetScript("OnLeave", function()
                GUI2:SetTextColorKey(removeText, "color.text.accent")
            end)
            removeBreak:SetScript("OnClick", function()
                if self:RemoveLineBreak(target, currentRowIndex) then
                    self:MarkDirty()
                    self:RefreshRight()
                end
            end)
            removeBreak:SetShown(not self.readOnly)
            y = y - 68
        else
            y = y - 44
        end
    end
    local add = CreateButton(operationsPanel, L["editor.add_item"], 100, function()
        self:AddItem()
    end, "warning")
    add:SetPoint("LEFT", 6, 0)
    local previous = CreateButton(operationsPanel, L["editor.item_previous"], 86, function()
        self:MoveSelectedItem(target, -1)
    end)
    previous:SetPoint("LEFT", add, "RIGHT", 8, 0)
    local next = CreateButton(operationsPanel, L["editor.item_next"], 86, function()
        self:MoveSelectedItem(target, 1)
    end)
    next:SetPoint("LEFT", previous, "RIGHT", 8, 0)
    local lineBreak = CreateButton(operationsPanel, L["editor.line_break_after"], 104, function()
        self:InsertLineBreak(target)
    end)
    lineBreak:SetPoint("LEFT", next, "RIGHT", 8, 0)
    local remove = CreateButton(operationsPanel, L["editor.remove_item"], 86, function()
        self:DeleteSelectedItem(target)
    end, "danger")
    remove:SetPoint("LEFT", lineBreak, "RIGHT", 8, 0)
    self.itemOperationButtons = {
        previous = previous,
        next = next,
        remove = remove,
        lineBreak = lineBreak,
    }
    self:RefreshItemOperations(target)
    grid:SetHeight(math.max(150, -y))
    panel:SetHeight(math.max(280, 190 - y))

    self:RefreshItemButtonSelection()
end

function Editor:Refresh()
    local wasRefreshing = self.refreshingControls
    self.refreshingControls = true
    self:HideItemEditor()
    self:RefreshTree()
    self:RefreshRight()
    self.refreshingControls = wasRefreshing
end

function Editor:RefreshWindowActions()
    local actions = self.windowActions
    if not actions then return end
    local readOnly = self.readOnly == true
    actions.rename:SetDisabled(readOnly)
    actions.deleteProfile:SetDisabled(readOnly)
    actions.addTab:SetDisabled(readOnly)
    actions.addCategory:SetDisabled(readOnly)
    actions.deleteSelected:SetDisabled(readOnly)
    actions.save:SetDisabled(readOnly)
    actions.cancel:SetText(readOnly and L["common.close"] or L["common.cancel"])
end

function Editor:LoadProfile(profile)
    if not profile then return false end
    self.profileID = profile.id
    self.readOnly = Profiles:IsOfficial(profile)
    self.draft = Profiles:Copy(profile)
    self.cleanDraft = Profiles:Copy(profile)
    self.selectedTab = 1
    self.selectedCategory = nil
    self.selectedItem = nil
    self.expandedTabs = { [1] = true }
    self.openGeneration = (self.openGeneration or 0) + 1
    local openGeneration = self.openGeneration
    self.refreshingControls = true
    self:SetDirtyState(false)
    self:RefreshWindowActions()
    self:RefreshEditorProfileDropdown(profile.id)
    self:Refresh()
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0, function() self:FinishOpen(openGeneration) end)
    else
        self:FinishOpen(openGeneration)
    end
    if self.rightScroll and self.rightScroll.SetVerticalScroll then
        self.rightScroll:SetVerticalScroll(0)
    end
    return true
end

function Editor:SwitchProfile(profileID)
    local profile = Profiles:Select(
        self.config.getDB(),
        profileID,
        self.config.getDefaultName()
    )
    if not profile then
        self:RefreshEditorProfileDropdown(self.profileID)
        Notify(L["editor.error.generic"])
        return false
    end
    self:LoadProfile(profile)
    RefreshRuntime(self.config)
    if self.RefreshSettings then self:RefreshSettings() end
    return true
end

function Editor:RequestProfileSwitch(profileID)
    if not profileID or profileID == self.profileID then return end
    self:RefreshEditorProfileDropdown(self.profileID)
    if not self.dirty then
        self:SwitchProfile(profileID)
        return
    end

    local panel = CreateModal(470, 188, L["editor.unsaved_title"])
    local message = CreateText(
        panel,
        L["editor.switch_unsaved_message"],
        "font.size.md",
        "color.text.secondary",
        "CENTER"
    )
    message:SetPoint("TOPLEFT", 24, -58)
    message:SetPoint("TOPRIGHT", -24, -58)
    message:SetHeight(44)
    message:SetWordWrap(true)
    local save = CreateButton(panel, L["editor.save_switch"], 126, function()
        if self:Save(true) then
            panel:Close()
            self:SwitchProfile(profileID)
        end
    end, "warning")
    save:SetPoint("BOTTOMLEFT", 20, 18)
    local discardButton = CreateButton(panel, L["editor.discard"], 126, function()
        panel:Close()
        self:SwitchProfile(profileID)
    end, "danger")
    discardButton:SetPoint("BOTTOM", 0, 18)
    local cancel = CreateButton(panel, L["common.cancel"], 126, function()
        panel:Close()
        self:RestoreEscapeCapture()
    end)
    cancel:SetPoint("BOTTOMRIGHT", -20, 18)
end

function Editor:Save(suppressRefresh)
    if not self:RequireEditable() then return false end
    local profile, code = Profiles:Update(
        self.config.getDB(),
        self.profileID,
        self.draft,
        self.config.getDefaultName()
    )
    if not profile then
        Notify(code == "invalid_name"
            and L["profiles.error.invalid_name"]
            or L["editor.error.invalid_data"])
        return false
    end
    self.draft = Profiles:Copy(profile)
    self.cleanDraft = Profiles:Copy(profile)
    self:SetDirtyState(false)
    if not suppressRefresh then
        RefreshRuntime(self.config)
        if self.RefreshSettings then self:RefreshSettings() end
    end
    return true
end

function Editor:RenameProfile()
    if not self:RequireEditable() then return end
    local panel = CreateModal(430, 190, L["profiles.rename_title"])
    local label = CreateText(panel, L["profiles.name"])
    label:SetPoint("TOPLEFT", 24, -58)
    local edit = GUI2.Form:CreateEditBox(panel, {
        width = 382,
        height = 28,
        text = self.draft.name,
        autoFocus = true,
    })
    edit:SetPoint("TOPLEFT", 24, -80)
    edit:HighlightText()
    local cancel = CreateButton(panel, L["common.cancel"], 100, function() panel:Close() end)
    cancel:SetPoint("BOTTOMRIGHT", -130, 18)
    local confirm = CreateButton(panel, L["common.rename"], 100, function()
        local profile, code = Profiles:Rename(
            self.config.getDB(),
            self.profileID,
            edit:GetText(),
            self.config.getDefaultName()
        )
        if not profile then
            Notify(code == "invalid_name"
                and L["profiles.error.invalid_name"]
                or L["editor.error.generic"])
            return
        end
        self.draft.name = profile.name
        if self.cleanDraft then self.cleanDraft.name = profile.name end
        self:MarkDirty()
        self:RefreshEditorProfileDropdown(profile.id)
        panel:Close()
        if self.RefreshSettings then self:RefreshSettings() end
    end, "warning")
    confirm:SetPoint("BOTTOMRIGHT", -20, 18)
end

function Editor:CreateProfile()
    if self.dirty and not self:Save() then return end
    ShowNewProfileDialog(self.config, function()
        if self.RefreshSettings then self:RefreshSettings() end
        self:Open(self.config)
    end)
end

function Editor:ImportProfile()
    if self.dirty and not self:Save() then return end
    ShowImportDialog(self.config, function()
        if self.RefreshSettings then self:RefreshSettings() end
        self:Open(self.config)
    end)
end

function Editor:ExportProfile()
    if self.dirty and not self:Save() then return end
    ShowExportDialog(self.config)
end

function Editor:DuplicateProfile()
    if self.dirty and not self:Save() then return end
    local profile, code = Profiles:Duplicate(
        self.config.getDB(),
        self.profileID,
        Profiles:GetProfileName(self.draft, L) .. " - " .. L["common.copy"],
        self.config.getDefaultName()
    )
    if not profile then
        Notify(code == "invalid_name"
            and L["profiles.error.invalid_name"]
            or L["editor.error.generic"])
        return
    end
    RefreshRuntime(self.config)
    if self.RefreshSettings then self:RefreshSettings() end
    self:Open(self.config)
end

function Editor:CloseFromEscape()
    if _G.C_Timer and _G.C_Timer.After then
        local window = self.window
        _G.C_Timer.After(0, function()
            if window and window:IsShown() then self:Close() end
        end)
    else
        self:Close()
    end
end

function Editor:RestoreEscapeCapture()
    local window = self.window
    if not window or not window:IsShown() then return end
    if window.EnableKeyboard then window:EnableKeyboard(true) end
    if window.SetPropagateKeyboardInput then window:SetPropagateKeyboardInput(true) end
end

function Editor:Close(discard)
    if self.dirty and not discard then
        local panel = CreateModal(470, 188, L["editor.unsaved_title"])
        local message = CreateText(
            panel,
            L["editor.unsaved_message"],
            "font.size.md",
            "color.text.secondary",
            "CENTER"
        )
        message:SetPoint("TOPLEFT", 24, -58)
        message:SetPoint("TOPRIGHT", -24, -58)
        message:SetHeight(44)
        message:SetWordWrap(true)
        local save = CreateButton(panel, L["editor.save_close"], 126, function()
            if self:Save() then
                panel:Close()
                self:Close(true)
            end
        end, "warning")
        save:SetPoint("BOTTOMLEFT", 20, 18)
        local discardButton = CreateButton(panel, L["editor.discard"], 126, function()
            panel:Close()
            self:Close(true)
        end, "danger")
        discardButton:SetPoint("BOTTOM", 0, 18)
        local cancel = CreateButton(panel, L["common.cancel"], 126, function()
            panel:Close()
            self:RestoreEscapeCapture()
        end)
        cancel:SetPoint("BOTTOMRIGHT", -20, 18)
        return
    end
    if self.window then
        self.openGeneration = (self.openGeneration or 0) + 1
        self.refreshingControls = nil
        self:HideItemEditor()
        self.window:HideModal()
        if self.window.EnableKeyboard then self.window:EnableKeyboard(false) end
    end
end

function Editor:BuildWindow()
    local window = CreateFloatingWindow(840, 620, L["editor.title"])
    window:ClearAllPoints()
    window:SetPoint("CENTER", UIParent, "CENTER", -120, 25)
    self.window = window
    GUI2:EnableEscapeClose(window, function() self:CloseFromEscape() end)

    local close = GUI2:CreateCloseButton(window, function()
        self:Close()
    end)
    close:SetPoint("TOPRIGHT", -14, -14)
    local profileDropdown = GUI2.Form:CreateDropdown(window, {
        width = 220,
        height = 28,
        options = function() return GetProfileOptions(self.config) end,
        onChange = function(_, value)
            if self.refreshingControls then return end
            self:RequestProfileSwitch(value)
        end,
    })
    profileDropdown:SetPoint("TOPLEFT", 18, -38)
    self.editorProfileDropdown = profileDropdown
    local dirty = CreateText(window, L["editor.unsaved"], "font.size.sm", "color.text.accent", "RIGHT")
    dirty:SetPoint("TOPRIGHT", -46, -18)
    dirty:Hide()
    self.dirtyText = dirty

    local create = CreateButton(window, L["common.new"], 72, function()
        self:CreateProfile()
    end)
    create:SetPoint("LEFT", profileDropdown, "RIGHT", 8, 0)
    local rename = CreateButton(window, L["common.rename"], 72, function()
        self:RenameProfile()
    end)
    rename:SetPoint("LEFT", create, "RIGHT", 8, 0)
    local duplicate = CreateButton(window, L["common.copy"], 72, function()
        self:DuplicateProfile()
    end)
    duplicate:SetPoint("LEFT", rename, "RIGHT", 8, 0)
    local deleteProfile = CreateButton(window, L["common.delete"], 82, function()
        if self.dirty and not self:Save() then return end
        ShowDeleteConfirm(self.config, self.profileID, function()
            if self.RefreshSettings then self:RefreshSettings() end
            self:Close(true)
        end)
    end, "danger")
    deleteProfile:SetPoint("LEFT", duplicate, "RIGHT", 8, 0)
    local importButton = CreateButton(window, L["profiles.import_string"], 96, function()
        self:ImportProfile()
    end)
    importButton:SetPoint("LEFT", deleteProfile, "RIGHT", 8, 0)
    local exportButton = CreateButton(window, L["profiles.export_string"], 96, function()
        self:ExportProfile()
    end)
    exportButton:SetPoint("LEFT", importButton, "RIGHT", 8, 0)

    local treePanel = GUI2:CreatePanel(window, {
        width = 194,
        height = 490,
        surface = "color.surface.panel",
        border = "color.border.subtle",
    })
    treePanel:SetPoint("TOPLEFT", 14, -70)
    local treeTitle = CreateText(treePanel, L["editor.tabs_categories"], "font.size.sm", "color.text.heading")
    treeTitle:SetPoint("TOPLEFT", 10, -10)
    local scroll = GUI2:CreateScrollFrame(treePanel)
    scroll:SetPoint("TOPLEFT", 4, -34)
    scroll:SetPoint("BOTTOMRIGHT", -18, 48)
    local child = GUI2:CreateFrame(scroll)
    child:SetWidth(176)
    child:SetHeight(470)
    scroll:SetScrollChild(child)
    self.treeChild = child

    local addTab = CreateButton(treePanel, L["editor.add_tab_short"], 86, function()
        self:AddTab()
    end)
    addTab:SetPoint("BOTTOMLEFT", 6, 16)
    local addCategory = CreateButton(treePanel, L["editor.add_category_short"], 86, function()
        self:AddCategory()
    end)
    addCategory:SetPoint("BOTTOMRIGHT", -6, 16)

    local rightPanel = GUI2:CreatePanel(window, {
        width = 610,
        height = 490,
        surface = "color.surface.panel",
        border = "color.border.subtle",
    })
    rightPanel:SetPoint("TOPRIGHT", -14, -70)
    local rightScroll = GUI2:CreateScrollFrame(rightPanel)
    rightScroll:SetPoint("TOPLEFT", 12, -12)
    rightScroll:SetPoint("BOTTOMRIGHT", -20, 56)
    local rightContent = GUI2:CreateFrame(rightScroll)
    rightContent:SetWidth(554)
    rightContent:SetHeight(600)
    rightScroll:SetScrollChild(rightContent)
    self.rightScroll = rightScroll
    self.rightContent = rightContent
    local itemOperationsFrame = GUI2:CreatePanel(rightPanel, {
        width = 554,
        height = 38,
        surface = "color.surface.raised",
        border = "color.border.subtle",
    })
    itemOperationsFrame:SetPoint("BOTTOMLEFT", 12, 10)
    itemOperationsFrame:SetFrameLevel(rightPanel:GetFrameLevel() + 5)
    itemOperationsFrame:EnableMouse(true)
    self.itemOperationsFrame = itemOperationsFrame

    local itemEditorPanel = GUI2:CreateFrame(window, {
        width = 300,
        height = 620,
        template = "BackdropTemplate",
    })
    itemEditorPanel:SetPoint("TOPLEFT", window, "TOPRIGHT", 8, 0)
    itemEditorPanel:SetFrameLevel(window:GetFrameLevel() + 10)
    itemEditorPanel:EnableMouse(true)
    itemEditorPanel:Hide()
    local itemEditorClose = GUI2:CreateCloseButton(itemEditorPanel, function()
        self:HideItemEditor()
    end)
    itemEditorClose:SetPoint("TOPRIGHT", -10, -10)
    local itemEditorHeading = CreateText(
        itemEditorPanel,
        "",
        "font.size.xl",
        "color.text.heading",
        "CENTER"
    )
    itemEditorHeading:SetPoint("TOPLEFT", 12, -16)
    itemEditorHeading:SetPoint("TOPRIGHT", -34, -16)
    RegisterAppearance(itemEditorPanel, itemEditorHeading, "item-editor")
    local itemEditorContent = GUI2:CreateFrame(itemEditorPanel)
    itemEditorContent:SetPoint("TOPLEFT", 12, -42)
    itemEditorContent:SetPoint("BOTTOMRIGHT", -12, 12)
    self.itemEditorPanel = itemEditorPanel
    self.itemEditorHeading = itemEditorHeading
    self.itemEditorContent = itemEditorContent

    local remove = CreateButton(window, L["editor.delete_selected"], 142, function()
        self:DeleteSelected()
    end, "danger")
    remove:SetPoint("BOTTOMLEFT", 14, 16)
    local cancel = CreateButton(window, L["common.cancel"], 100, function()
        self:Close()
    end)
    cancel:SetPoint("BOTTOMRIGHT", -132, 16)
    local save = CreateButton(window, L["editor.save_apply"], 112, function()
        if self:Save() then self:Close(true) end
    end, "warning")
    save:SetPoint("BOTTOMRIGHT", -14, 16)
    self.windowActions = {
        rename = rename,
        deleteProfile = deleteProfile,
        addTab = addTab,
        addCategory = addCategory,
        deleteSelected = remove,
        save = save,
        cancel = cancel,
    }
end

function Editor:FinishOpen(openGeneration)
    if openGeneration ~= self.openGeneration then return false end
    self.refreshingControls = nil
    self.cleanDraft = Profiles:Copy(self.draft)
    self:SetDirtyState(false)
    return true
end

function Editor:Open(config)
    self.config = config
    local profile = Profiles:GetActive(config.getDB(), config.getDefaultName())
    if not profile then return end
    if not self.window then self:BuildWindow() end
    self.window:ShowModal()
    self:RestoreEscapeCapture()
    self:LoadProfile(profile)
end
