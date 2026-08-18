local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local YUI = _G.YUI
YUI.GUI2 = YUI.GUI2 or {}

local GUI2 = YUI.GUI2
local Assets = YUI.Assets
local SecurityAPI = YUI.API and YUI.API.Security or YUI.WOW_API or {}

local CreateFrame = CreateFrame
local UIParent = UIParent
local tinsert = table.insert
local ipairs = ipairs
local unpack = unpack

local Lab = {}
GUI2.Lab = Lab

local TAB_DEFS = {
    { id = "presets", label = "主题/Preset", title = "主题方案（Preset）", width = 112 },
    { id = "primitive", label = "基础/Primitive", title = "基础组件（Primitive）", width = 118 },
    { id = "form", label = "表单/Form", title = "表单控件（Form）", width = 108 },
    { id = "data", label = "数据/Data", title = "数据展示（Data）", width = 108 },
    { id = "overlay", label = "浮层/Overlay", title = "浮层组件（Overlay）", width = 118 },
    { id = "application", label = "业务/App", title = "业务组件（Application）", width = 108 },
    { id = "secure", label = "安全/Secure", title = "安全组件（Secure）", width = 112 },
}

local function ClearFrame(frame)
    if not frame then return end

    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        child:Hide()
        child:SetParent(nil)
    end

    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region.SetText or region.SetTexture or region.SetColorTexture then
            region:Hide()
        end
    end
end

local function CreateLabButton(parent, text, width, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 120, 28)
    GUI2:ApplyBackdrop(button, "color.control.bg")
    GUI2:CreateBorder(button, "color.border.default")

    local label = GUI2:CreateText(button, text, "font.size.md", "color.text.primary")
    label:SetPoint("CENTER")
    button.text = label
    button.gui2Surface = "color.control.bg"

    button:SetScript("OnEnter", function(self)
        self:SetBackdropColor(GUI2:GetColor("color.control.hover"))
        GUI2:SetBorderColor(self, "color.border.accent")
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropColor(GUI2:GetColor(self.gui2Selected and "color.control.active" or "color.control.bg"))
        GUI2:SetBorderColor(self, self.gui2Selected and "color.border.accent" or "color.border.default")
    end)
    button:SetScript("OnMouseDown", function(self)
        if self.text then
            self.text:SetPoint("CENTER", 1, -1)
        end
    end)
    button:SetScript("OnMouseUp", function(self)
        if self.text then
            self.text:SetPoint("CENTER", 0, 0)
        end
    end)
    if onClick then
        button:SetScript("OnClick", onClick)
    end

    return button
end

local function SetButtonSelected(button, selected)
    if not button then return end
    button.gui2Selected = selected
    button:SetBackdropColor(GUI2:GetColor(selected and "color.control.active" or "color.control.bg"))
    GUI2:SetBorderColor(button, selected and "color.border.accent" or "color.border.default")
    if button.text then
        button.text:SetTextColor(GUI2:GetColor(selected and "color.text.accent" or "color.text.primary"))
    end
end

local function GetUsableWidth(parent, fallback)
    local width = parent and parent:GetWidth() or 0
    if not width or width < 100 then
        return fallback or 920
    end
    return width
end

local function InLockdown()
    if SecurityAPI.InCombatLockdown then
        return SecurityAPI.InCombatLockdown() and true or false
    end
    if InCombatLockdown then
        return InCombatLockdown() and true or false
    end
    return false
end

function Lab:Create()
    if self.frame then
        return self.frame
    end

    local frame = GUI2:CreatePanel(UIParent, {
        name = "YUI_GUI2_LabFrame",
        width = 980,
        height = 640,
        surface = "color.surface.window",
        border = "color.border.strong",
        shadow = true,
        shadowKey = "shadow.popup.size",
    })
    frame:SetPoint("CENTER", -126, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()

    tinsert(UISpecialFrames, "YUI_GUI2_LabFrame")

    local title = GUI2:CreateText(frame, "YUI GUI2.0 控件审查", "font.size.title", "color.text.heading")
    title:SetPoint("TOPLEFT", 18, -16)
    frame.title = title

    local subtitle = GUI2:CreateText(frame, "按组件分类罗列 GUI2.0 控件，用于逐项检查午夜黑、原生黑金等预设表现。", "font.size.sm", "color.text.secondary")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    frame.subtitle = subtitle

    local close = GUI2:CreateCloseButton(frame, function()
        frame:Hide()
    end)
    close:SetPoint("TOPRIGHT", -14, -14)
    frame.close = close

    local tabBar = CreateFrame("Frame", nil, frame)
    tabBar:SetPoint("TOPLEFT", 16, -70)
    tabBar:SetPoint("TOPRIGHT", -16, -70)
    tabBar:SetHeight(34)
    frame.tabBar = tabBar

    self.tabs = {}
    local x = 0
    for _, tab in ipairs(TAB_DEFS) do
        local button = CreateLabButton(tabBar, tab.label, tab.width or 118, function()
            Lab:SelectTab(tab.id)
        end)
        button:SetPoint("LEFT", x, 0)
        button.tabId = tab.id
        self.tabs[tab.id] = button
        x = x + button:GetWidth() + 8
    end

    local content = GUI2:CreatePanel(frame, {
        surface = "color.surface.panel",
        border = "color.border.default",
        shadow = false,
    })
    content:SetPoint("TOPLEFT", 16, -112)
    content:SetPoint("BOTTOMRIGHT", -16, 16)
    frame.content = content

    local componentListPanel = GUI2:CreatePanel(frame, {
        width = 246,
        surface = "color.surface.popup",
        border = "color.popup.border",
        shadow = true,
        shadowKey = "shadow.popup.size",
    })
    componentListPanel:SetPoint("TOPLEFT", frame, "TOPRIGHT", 8, -112)
    componentListPanel:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 8, 16)
    frame.componentListPanel = componentListPanel

    local componentListContent = CreateFrame("Frame", nil, componentListPanel)
    componentListContent:SetPoint("TOPLEFT", 0, 0)
    componentListContent:SetPoint("BOTTOMRIGHT", 0, 0)
    frame.componentListContent = componentListContent

    self.frame = frame
    self:SelectTab("presets")
    return frame
end

function Lab:Open()
    local frame = self:Create()
    frame:Show()
    self:RefreshTheme()
end

function Lab:Toggle()
    local frame = self:Create()
    if frame:IsShown() then
        frame:Hide()
    else
        self:Open()
    end
end

function Lab:SelectTab(id)
    if self.frame and self.frame.content and self.frame.content.gui2ContainsSecure and id ~= "secure" and InLockdown() then
        if YUI.Print then
            YUI:Print("GUI2 Secure Lab cannot be rebuilt during combat.")
        end
        id = "secure"
    end

    self.activeTab = id
    for tabId, button in pairs(self.tabs or {}) do
        SetButtonSelected(button, tabId == id)
    end
    self:RenderActiveTab()
end

function Lab:RefreshTheme()
    if not self.frame then return end
    GUI2:RefreshPrimitive(self.frame)
    GUI2:RefreshPrimitive(self.frame.content)
    if self.frame.close and self.frame.close.RefreshTheme then
        self.frame.close:RefreshTheme()
    else
        GUI2:RefreshPrimitive(self.frame.close)
    end

    if self.frame.title then
        self.frame.title:SetTextColor(GUI2:GetColor("color.text.heading"))
    end
    if self.frame.subtitle then
        self.frame.subtitle:SetTextColor(GUI2:GetColor("color.text.secondary"))
    end
    if self.frame.componentListPanel then
        GUI2:RefreshPrimitive(self.frame.componentListPanel)
    end

    for tabId, button in pairs(self.tabs or {}) do
        GUI2:RefreshPrimitive(button)
        SetButtonSelected(button, tabId == self.activeTab)
    end

    self:RenderActiveTab()
end

function Lab:RenderHeader(parent, title, description)
    local width = GetUsableWidth(parent)
    local header = GUI2:CreateText(parent, title, "font.size.title", "color.text.heading")
    header:SetPoint("TOPLEFT", 18, -16)
    local body = GUI2:CreateText(parent, description, "font.size.md", "color.text.secondary")
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
    body:SetWidth(width - 40)
    body:SetWordWrap(true)
    return body
end

function Lab:RenderComponentList(parent, title, items, x, y, width, height)
    local panel = self.frame and self.frame.componentListPanel
    local content = self.frame and self.frame.componentListContent
    if not panel or not content then return end
    ClearFrame(content)
    GUI2:RefreshPrimitive(panel)

    local heading = GUI2:CreateText(content, title, "font.size.lg", "color.text.heading")
    heading:SetPoint("TOPLEFT", 12, -10)
    heading:SetWidth(222)
    heading:SetWordWrap(true)

    local total = #(items or {})
    local columns = 1
    local split = total
    local colWidth = 222
    for index, item in ipairs(items or {}) do
        local col = 0
        local row = index
        local line = GUI2:CreateText(content, item, "font.size.sm", "color.text.secondary")
        line:SetPoint("TOPLEFT", 14 + (col * colWidth), -48 - ((row - 1) * 18))
        line:SetWidth(colWidth - 8)
        line:SetWordWrap(false)
    end

    return panel
end

local function CreateReviewSection(parent, title, x, y, width, height)
    local panel = GUI2:CreatePanel(parent, {
        width = width,
        height = height,
        surface = "color.surface.raised",
        border = "color.border.default",
        shadow = true,
    })
    panel:SetPoint("TOPLEFT", x, y)
    local label = GUI2:CreateText(panel, title, "font.size.lg", "color.text.heading")
    label:SetPoint("TOPLEFT", 12, -10)
    return panel
end

function Lab:RenderPrimitive(parent)
    local width = GetUsableWidth(parent)
    self:RenderHeader(parent, "基础组件（Primitive）", "底层组件负责容器、文本、按钮、图标按钮、分割线、色块、表格和模块开关，是其他分类复用的基础。")

    self:RenderComponentList(parent, "组件清单（Component List）", {
        "框架（Frame）", "面板（Panel）", "文本（Text）", "纹理（Texture）", "基础图标（Icon）", "符号图标（Glyph）",
        "边框（Border）", "阴影（Shadow）", "背景层（Backdrop）", "滚动容器（ScrollFrame）",
        "按钮框（ButtonFrame）", "普通按钮（Button）", "图标按钮（IconButton）", "图标槽（IconSlot）",
        "图标网格（IconGrid）", "关闭按钮（CloseButton）", "导航按钮（NavButton）", "滑条皮肤（SkinSlider）",
        "下拉按钮皮肤（SkinDropdownButton）", "下拉箭头（Dropdown Glyph）",
        "下拉列表（OpenDropdown）", "输入框皮肤（SkinEditBox）", "复选框皮肤（SkinCheckBox）", "滚动条皮肤（SkinScrollBar）",
        "表格（Table）", "分割线（Divider）", "色块（Swatch）", "模块开关（ModSwitch）",
    })

    local containers = CreateReviewSection(parent, "容器与文字（Panel / Text / Texture）", 18, -88, 300, 400)
    local p1 = GUI2:CreatePanel(containers, { width = 124, height = 50, surface = "color.surface.panel", border = "color.border.default" })
    p1:SetPoint("TOPLEFT", 14, -44)
    GUI2:CreateText(p1, "普通面板", "font.size.md", "color.text.primary"):SetPoint("CENTER")
    local p2 = GUI2:CreatePanel(containers, { width = 124, height = 50, surface = "color.surface.sunken", border = "color.border.subtle" })
    p2:SetPoint("LEFT", p1, "RIGHT", 12, 0)
    GUI2:CreateText(p2, "内凹面板", "font.size.md", "color.text.secondary"):SetPoint("CENTER")
    local p3 = GUI2:CreatePanel(containers, { width = 124, height = 50, surface = "color.surface.popup", border = "color.popup.border", shadow = true })
    p3:SetPoint("TOPLEFT", p1, "BOTTOMLEFT", 0, -12)
    GUI2:CreateText(p3, "浮层面板", "font.size.md", "color.text.accent"):SetPoint("CENTER")
    local divider = GUI2:CreateDivider(containers, 252, "分割线（Divider）")
    divider:SetPoint("TOPLEFT", p3, "BOTTOMLEFT", 0, -14)
    local texture = GUI2:CreateTexture(containers, "color.accent.primary", "ARTWORK")
    texture:SetSize(34, 18)
    texture:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -10)
    local textureLabel = GUI2:CreateText(containers, "纹理色块", "font.size.sm", "color.text.secondary")
    textureLabel:SetPoint("LEFT", texture, "RIGHT", 8, 0)

    local buttons = CreateReviewSection(parent, "按钮与图标（Button / IconButton）", 334, -88, 310, 400)
    local normal = GUI2:CreateButton(buttons, "普通", 72, 26)
    normal:SetPoint("TOPLEFT", 14, -44)
    local selected = GUI2:CreateButton(buttons, "选中", 72, 26)
    selected:SetPoint("LEFT", normal, "RIGHT", 10, 0)
    if selected.SetSelected then selected:SetSelected(true) end
    local close = GUI2:CreateCloseButton(buttons, function() end)
    close:SetPoint("LEFT", selected, "RIGHT", 14, 0)
    local glyph = GUI2:CreateGlyph(buttons, { glyph = "dropdownDown", size = 12 })
    glyph:SetPoint("LEFT", close, "RIGHT", 10, 0)
    local plainIcon = GUI2:CreateIcon(buttons, {
        icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        size = 24,
    })
    plainIcon:SetPoint("LEFT", glyph, "RIGHT", 12, 0)
    local gear = GUI2:CreateIconButton(buttons, { size = 28, icon = "Interface\\Icons\\INV_Misc_Gear_01", tooltip = "设置" })
    gear:SetPoint("LEFT", plainIcon, "RIGHT", 10, 0)
    local nav = GUI2:CreateNavButton(buttons, "导航项", "Interface\\Icons\\INV_Misc_Map_01", 138, 36)
    nav:SetPoint("TOPLEFT", normal, "BOTTOMLEFT", 0, -16)
    if nav.SetSelected then nav:SetSelected(true) end
    local anchor = nav
    if GUI2.CreateIconSlot and GUI2.CreateIconGrid then
        local slot = GUI2:CreateIconSlot(buttons, { size = 28, icon = "Interface\\Icons\\INV_Misc_QuestionMark" })
        slot:SetPoint("TOPLEFT", nav, "BOTTOMLEFT", 0, -14)
        local selectedSlot = GUI2:CreateIconSlot(buttons, { size = 28, selected = true, icon = "Interface\\Icons\\Spell_Holy_BorrowedTime" })
        selectedSlot:SetPoint("LEFT", slot, "RIGHT", 10, 0)
        local disabledSlot = GUI2:CreateIconSlot(buttons, { size = 28, disabled = true, icon = "Interface\\Icons\\Ability_Vanish" })
        disabledSlot:SetPoint("LEFT", selectedSlot, "RIGHT", 10, 0)
        local grid = GUI2:CreateIconGrid(buttons, {
            columns = 4,
            itemSize = 24,
            spacing = 6,
            width = 140,
            items = {
                { icon = "Interface\\Icons\\INV_Misc_QuestionMark", selected = true },
                { icon = "Interface\\Icons\\INV_Misc_Coin_01" },
                { icon = "Interface\\Icons\\INV_Misc_Bag_10", disabled = true },
                { icon = "Interface\\Icons\\Ability_Rogue_Sprint", count = 3 },
            },
        })
        grid:SetPoint("TOPLEFT", slot, "BOTTOMLEFT", 0, -12)
        anchor = grid
    end
    local mod = GUI2.Application:CreateModSwitch(buttons, {
        width = 132,
        height = 76,
        label = "模块开关",
        image = Assets:Core("images\\YUI-LOGO-300.png"),
        default = true,
        settingsClick = function() end,
    })
    mod:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)

    local smallLabel = GUI2:CreateText(buttons, "小图标尺寸", "font.size.sm", "color.text.secondary")
    smallLabel:SetPoint("TOPLEFT", mod, "BOTTOMLEFT", 0, -10)
    local glyph12 = GUI2:CreateGlyph(buttons, { glyph = "dropdownDown", size = 12 })
    glyph12:SetPoint("TOPLEFT", smallLabel, "BOTTOMLEFT", 0, -6)
    local glyph16 = GUI2:CreateGlyph(buttons, { glyph = "dropdownDown", size = 16 })
    glyph16:SetPoint("LEFT", glyph12, "RIGHT", 10, 0)
    local icon20 = GUI2:CreateIconButton(buttons, { size = 20, icon = "Interface\\Icons\\INV_Misc_Gear_01", padding = 0 })
    icon20:SetPoint("LEFT", glyph16, "RIGHT", 10, 0)
    local slot24 = GUI2:CreateIconSlot(buttons, { size = 24, icon = "Interface\\Icons\\INV_Misc_QuestionMark" })
    slot24:SetPoint("LEFT", icon20, "RIGHT", 10, 0)

    local data = CreateReviewSection(parent, "表格与色彩（Table / Swatch）", 660, -88, width - 678, 400)
    local sw1 = GUI2:CreateSwatch(data, "强调色", "color.accent.primary", 150, 38)
    sw1:SetPoint("TOPLEFT", 14, -44)
    local sw2 = GUI2:CreateSwatch(data, "警告色", "color.state.warning", 150, 38)
    sw2:SetPoint("TOPLEFT", sw1, "BOTTOMLEFT", 0, -8)
    local tableFrame = GUI2:CreateTable(data, {
        width = math.max(width - 706, 220),
        height = 84,
        rowHeight = 18,
        columns = {
            { text = "组件", width = 78 },
            { text = "状态", width = 64 },
            { text = "用途", width = 82 },
        },
        data = {
            { "按钮", "可点", "命令" },
            { "面板", "静态", "容器" },
            { "色块", "只读", "审查" },
        },
    })
    tableFrame:SetPoint("TOPLEFT", sw2, "BOTTOMLEFT", 0, -10)
end

function Lab:RenderPresets(parent)
    local width = GetUsableWidth(parent)
    local preset = GUI2:GetActivePreset()
    local skin = GUI2:GetActiveSkin()
    local afterHeader = self:RenderHeader(parent, "主题方案（Preset）", "切换 GUI2.0 的当前外观方案，集中检查背景、文字、边框、强调色、状态色和阴影。")
    self:RenderComponentList(parent, "主题清单（Preset List）", {
        "方案按钮（Preset Button）",
        "午夜黑",
        "原生黑金（Gilded）",
        "外观面板（Appearance）",
        "背景色（Surface Token）",
        "文字色（Text Token）",
        "边框色（Border Token）",
        "强调色（Accent Token）",
        "状态色（State Token）",
        "阴影（Shadow Token）",
        "圆角（Radius Token）",
    })

    local selector = CreateFrame("Frame", nil, parent)
    selector:SetPoint("TOPLEFT", afterHeader, "BOTTOMLEFT", 0, -18)
    selector:SetSize(width - 36, 34)

    local x = 0
    for _, item in ipairs(GUI2:GetPresets()) do
        local btn = CreateLabButton(selector, GUI2:GetPresetDisplayName(item), 190, function()
            if GUI2.Appearance and GUI2.Appearance.SetBasePreset then
                GUI2.Appearance:SetBasePreset(item.id, true)
            else
                GUI2:SetPreset(item.id)
            end
        end)
        btn:SetPoint("LEFT", x, 0)
        SetButtonSelected(btn, item.id == preset.id)
        x = x + 200
    end

    if GUI2.Appearance and GUI2.Appearance.Open then
        local appearance = CreateLabButton(selector, "外观面板（Appearance）", 170, function()
            GUI2.Appearance:Open()
        end)
        appearance:SetPoint("LEFT", x + 10, 0)
    end

    local meta = GUI2:CreateText(parent, "当前方案：" .. GUI2:GetPresetDisplayName(preset) .. "    当前皮肤：" .. (skin and skin.name or "未知"), "font.size.md", "color.text.accent")
    meta:SetPoint("TOPLEFT", selector, "BOTTOMLEFT", 0, -18)

    local samplePanel = GUI2:CreatePanel(parent, {
        width = width - 36,
        height = 314,
        surface = "color.surface.raised",
        border = "color.border.default",
        shadow = true,
    })
    samplePanel:SetPoint("TOPLEFT", meta, "BOTTOMLEFT", 0, -14)

    local row1 = {
        { "基础背景", "color.surface.base" },
        { "窗口背景", "color.surface.window" },
        { "面板背景", "color.surface.panel" },
        { "浮层背景", "color.surface.popup" },
    }
    local row2 = {
        { "主文字", "color.text.primary" },
        { "次文字", "color.text.secondary" },
        { "默认边框", "color.border.default" },
        { "浮层边框", "color.popup.border" },
    }
    local row3 = {
        { "主强调", "color.accent.primary" },
        { "柔强调", "color.accent.soft" },
        { "成功状态", "color.state.success" },
        { "警告状态", "color.state.warning" },
    }
    local row4 = {
        { "错误状态", "color.state.error" },
        { "危险状态", "color.state.danger" },
        { "阴影", "color.overlay.shadow" },
        { "高亮", "color.overlay.highlight" },
    }

    local rows = { row1, row2, row3, row4 }
    local startY = -18
    for rowIndex, row in ipairs(rows) do
        for colIndex, swatch in ipairs(row) do
            local card = GUI2:CreateSwatch(samplePanel, swatch[1], swatch[2], 190, 46)
            card:SetPoint("TOPLEFT", 18 + ((colIndex - 1) * 205), startY - ((rowIndex - 1) * 60))
        end
    end

    local divider = GUI2:CreateDivider(samplePanel, width - 72, "阴影 / 圆角 / 降级")
    divider:SetPoint("TOPLEFT", 18, -258)

    local note = GUI2:CreateText(samplePanel, "午夜黑用于默认深色专业风格；原生黑金沿用深色层级，窗口保持 GUI2 像素边框，菜单和提示类弹层使用黑色填充的 Blizzard tooltip 边框。渐变类样式在单色接口下会降级到可用颜色。", "font.size.sm", "color.text.secondary")
    note:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -8)
    note:SetWidth(width - 72)
    note:SetWordWrap(true)
end

function Lab:RenderPlaceholder(parent, tab)
    local width = GetUsableWidth(parent)
    local descriptions = {
        primitive = "这里展示基础组件（Primitive）和可复用皮肤入口。",
        form = "这里展示表单控件（Form）的输入、选择、状态与禁用形态。",
        data = "这里展示数据展示（Data）的行、列表、表格、标签、统计、空状态和进度条。",
        overlay = "这里展示浮层组件（Overlay）的提示、弹窗、菜单、确认和通知。",
        application = "这里展示业务组件（Application）的图标、列表、状态、动作和弹出图标菜单。",
        secure = "这里展示安全组件（Secure）的安全动作、图标动作、菜单项、动作列表和战斗队列。",
    }
    local title
    for _, def in ipairs(TAB_DEFS) do
        if def.id == tab then
            title = def.title
            break
        end
    end
    self:RenderHeader(parent, title or tab, descriptions[tab] or "待实现。")

    local panel = GUI2:CreatePanel(parent, {
        width = width - 36,
        height = 160,
        surface = "color.surface.raised",
        border = "color.border.default",
        shadow = true,
    })
    panel:SetPoint("TOPLEFT", 18, -110)

    local label = GUI2:CreateText(panel, "阶段占位（Placeholder）", "font.size.lg", "color.text.heading")
    label:SetPoint("TOPLEFT", 16, -18)

    local body = GUI2:CreateText(panel, "这个页签已经进入控件审查导航和主题刷新流程。后续会在同一容器内补齐真实组件。", "font.size.md", "color.text.secondary")
    body:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -10)
    body:SetWidth(width - 68)
    body:SetWordWrap(true)
end

function Lab:RenderActiveTab()
    if not self.frame or not self.frame.content then return end
    local content = self.frame.content
    if content.gui2ContainsSecure and InLockdown() then
        return
    end

    content.gui2ContainsSecure = false
    ClearFrame(content)

    if self.activeTab == "presets" then
        self:RenderPresets(content)
    elseif self.activeTab == "primitive" then
        self:RenderPrimitive(content)
    elseif self.activeTab == "form" and GUI2.Form and GUI2.Form.RenderLab then
        GUI2.Form:RenderLab(content, self)
    elseif self.activeTab == "data" and GUI2.Data and GUI2.Data.RenderLab then
        GUI2.Data:RenderLab(content, self)
    elseif self.activeTab == "overlay" and GUI2.Overlay and GUI2.Overlay.RenderLab then
        GUI2.Overlay:RenderLab(content, self)
    elseif self.activeTab == "application" and GUI2.Application and GUI2.Application.RenderLab then
        GUI2.Application:RenderLab(content, self)
    elseif self.activeTab == "secure" and GUI2.Secure and GUI2.Secure.RenderLab then
        GUI2.Secure:RenderLab(content, self)
        content.gui2ContainsSecure = true
    else
        self:RenderPlaceholder(content, self.activeTab)
    end
end

local function RegisterSlash()
    if not SlashCmdList then return end
    SLASH_YUI_GUI2_LAB1 = "/yui2"
    SlashCmdList["YUI_GUI2_LAB"] = function()
        GUI2.Lab:Toggle()
    end
end

RegisterSlash()
