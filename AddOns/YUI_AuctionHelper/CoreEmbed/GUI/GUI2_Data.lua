local __yuiAddonName = ...
local __yuiState = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[__yuiAddonName]
if __yuiState and not __yuiState.loadCore then
    return
end
local YUI = _G.YUI
YUI.GUI2 = YUI.GUI2 or {}

local GUI2 = YUI.GUI2
local CreateFrame = CreateFrame
local math_floor = math.floor
local math_max = math.max
local math_min = math.min

GUI2.Data = GUI2.Data or {}

local DEFAULT_PROGRESS_TEXTURE = "Interface\\Buttons\\WHITE8x8"

local function ConfigureMotion(frame, opts, owner)
    if not frame then return end
    opts = opts or {}
    frame.gui2Animate = opts.animate ~= false and opts.motion ~= false
    frame.gui2MotionOwner = owner or frame
end

local function InheritMotion(child, owner)
    if not child or not owner then return end
    child.gui2Animate = owner.gui2Animate
    child.gui2MotionOwner = owner
end

local function ParseSetOptions(setOptions)
    local silent = setOptions == true
    local animate = not silent
    local options = nil

    if type(setOptions) == "table" then
        options = setOptions
        silent = setOptions.silent == true
        if setOptions.animate ~= nil then
            animate = setOptions.animate == true
        else
            animate = not silent
        end
        if setOptions.motion == false then
            animate = false
        end
    end

    return silent, animate, options
end

local function NormalizeFillColor(r, g, b, a)
    if type(r) == "table" or type(r) == "string" then
        return r
    end
    if type(r) == "number" then
        return { r, g or 1, b or 1, a == nil and 1 or a }
    end
    return nil
end

local function ApplyProgressFillStyle(frame)
    local fill = frame and frame.fill
    if not fill then return end

    local texture = frame.gui2FillTexture
    local color = frame.gui2FillColor
    if type(texture) == "string" and texture ~= "" then
        fill.gui2PaintKey = nil
        fill:SetTexture(texture)
        if type(color) == "string" then
            fill:SetVertexColor(GUI2:GetColor(color))
        elseif type(color) == "table" then
            fill:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] == nil and 1 or color[4])
        else
            fill:SetVertexColor(1, 1, 1, 1)
        end
        return
    end

    if fill.SetVertexColor then
        fill:SetVertexColor(1, 1, 1, 1)
    end
    if type(color) == "table" then
        fill.gui2PaintKey = nil
        fill:SetColorTexture(color[1] or 1, color[2] or 1, color[3] or 1, color[4] == nil and 1 or color[4])
    else
        local colorKey = type(color) == "string" and color or "color.accent.primary"
        fill.gui2PaintKey = colorKey
        fill:SetColorTexture(GUI2:GetColor(colorKey))
    end
end

function GUI2.Data:CreateIconSlot(parent, opts)
    return GUI2:CreateIconSlot(parent, opts)
end

function GUI2.Data:CreateBadge(parent, text, tone)
    local frame = GUI2:CreatePanel(parent, {
        width = 82,
        height = 22,
        surface = tone == "accent" and "color.accent.soft" or "color.surface.sunken",
        border = tone == "accent" and "color.border.accent" or "color.border.default",
    })
    local label = GUI2:CreateText(frame, text or "Badge", "font.size.sm", tone == "accent" and "color.text.accent" or "color.text.primary")
    label:SetPoint("CENTER")
    frame.text = label
    return frame
end

function GUI2.Data:CreateTag(parent, text, tone)
    local frame = self:CreateBadge(parent, text or "Tag", tone)
    frame:SetSize(66, 20)
    return frame
end

function GUI2.Data:CreateInfoRow(parent, label, value)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(260, 26)
    local left = GUI2:CreateText(frame, label or "Label", "font.size.md", "color.text.secondary")
    left:SetPoint("LEFT", 0, 0)
    local right = GUI2:CreateText(frame, value or "Value", "font.size.md", "color.text.primary", "RIGHT")
    right:SetPoint("RIGHT", 0, 0)
    frame.label = left
    frame.value = right
    return frame
end

function GUI2.Data:CreateStatBlock(parent, opts)
    opts = opts or {}
    local frame = GUI2:CreatePanel(parent, {
        width = opts.width or 136,
        height = opts.height or 76,
        surface = "color.surface.panel",
        border = "color.border.default",
    })
    local label = GUI2:CreateText(frame, opts.label or "Latency", "font.size.sm", "color.text.secondary")
    label:SetPoint("TOPLEFT", 10, -10)
    local value = GUI2:CreateText(frame, opts.value or "24 ms", "font.size.title", opts.tone or "color.text.accent")
    value:SetPoint("BOTTOMLEFT", 10, 10)
    frame.label = label
    frame.value = value
    return frame
end

function GUI2.Data:CreateEmptyState(parent, opts)
    opts = opts or {}
    local frame = GUI2:CreatePanel(parent, {
        width = opts.width or 250,
        height = opts.height or 104,
        surface = "color.surface.sunken",
        border = "color.border.subtle",
    })
    local title = GUI2:CreateText(frame, opts.title or "No results", "font.size.lg", "color.text.heading")
    title:SetPoint("TOP", 0, -22)
    local body = GUI2:CreateText(frame, opts.body or "Change filters or try another preset.", "font.size.sm", "color.text.secondary")
    body:SetPoint("TOP", title, "BOTTOM", 0, -8)
    body:SetWidth((opts.width or 250) - 28)
    body:SetJustifyH("CENTER")
    frame.title = title
    frame.body = body
    return frame
end

function GUI2.Data:CreateList(parent, opts)
    opts = opts or {}
    local frame = GUI2:CreatePanel(parent, {
        width = opts.width or 260,
        height = opts.height or 120,
        surface = "color.surface.panel",
        border = "color.border.default",
    })
    local items = opts.items or { "Item one", "Item two", "Item three" }
    for i, item in ipairs(items) do
        local row = GUI2:CreatePanel(frame, {
            width = (opts.width or 260) - 16,
            height = 26,
            surface = i == 2 and "color.control.active" or "color.surface.raised",
            border = i == 2 and "color.border.accent" or "color.border.subtle",
        })
        row:SetPoint("TOPLEFT", 8, -8 - ((i - 1) * 32))
        local text = GUI2:CreateText(row, item, "font.size.sm", i == 2 and "color.text.accent" or "color.text.primary")
        text:SetPoint("LEFT", 8, 0)
    end
    return frame
end

function GUI2.Data:CreateTable(parent, opts)
    opts = opts or {}
    local width = opts.width or 360
    local rowHeight = opts.rowHeight or 24
    local headerY = opts.headerY or -10
    local dividerY = opts.dividerY or -32
    local rowStartY = opts.rowStartY or -44
    local columns = opts.columns or { "Name", "State", "Value" }
    local columnStep = math_floor((width - 20) / math_max(#columns, 1))
    local frame = GUI2:CreatePanel(parent, {
        width = width,
        height = opts.height or 132,
        surface = "color.surface.panel",
        border = "color.border.default",
    })
    local rows = opts.rows or {
        { "Clock", "Ready", "24" },
        { "YBar", "Active", "12" },
        { "GUI2", "Lab", "5B" },
    }
    for i, col in ipairs(columns) do
        local text = GUI2:CreateText(frame, col, "font.size.sm", "color.text.secondary")
        text:SetPoint("TOPLEFT", 10 + ((i - 1) * columnStep), headerY)
    end
    local divider = GUI2:CreateTexture(frame, "color.border.default", "OVERLAY")
    divider:SetPoint("TOPLEFT", 10, dividerY)
    divider:SetPoint("TOPRIGHT", -10, dividerY)
    divider:SetHeight(1)
    for r, row in ipairs(rows) do
        for c, cell in ipairs(row) do
            local text = GUI2:CreateText(frame, cell, "font.size.sm", c == 2 and "color.text.accent" or "color.text.primary")
            text:SetPoint("TOPLEFT", 10 + ((c - 1) * columnStep), rowStartY - ((r - 1) * rowHeight))
        end
    end
    return frame
end

local function ApplyProgressFill(frame)
    if not (frame and frame.fill) then return end
    local value = frame.value or 0
    if value < 0 then value = 0 end
    if value > 1 then value = 1 end

    local track = frame.track or frame
    frame.fill:ClearAllPoints()
    if frame.orientation == "vertical" then
        local height = math_floor(frame.barHeight * value)
        frame.fill:SetWidth(frame.barWidth)
        frame.fill:SetHeight(height)
        if frame.fillDirection == "down" then
            frame.fill:SetPoint("TOP", track, "TOP", 0, 0)
        else
            frame.fill:SetPoint("BOTTOM", track, "BOTTOM", 0, 0)
        end
    else
        local width = math_floor(frame.barWidth * value)
        frame.fill:SetWidth(width)
        frame.fill:SetHeight(frame.barHeight)
        if frame.fillDirection == "right" then
            frame.fill:SetPoint("RIGHT", track, "RIGHT", 0, 0)
        else
            frame.fill:SetPoint("LEFT", track, "LEFT", 0, 0)
        end
    end

    if frame.icon then
        if frame.iconPosition == "follow" then
            frame.icon:ClearAllPoints()
            frame.icon:SetSize(frame.iconSize, frame.iconSize)
            if frame.orientation == "vertical" then
                local half = math_floor(frame.iconSize / 2)
                local y = math_min(math_max(math_floor(frame.barHeight * value), half), frame.barHeight - half)
                frame.icon:SetPoint("CENTER", track, "BOTTOM", 0, y)
            else
                local half = math_floor(frame.iconSize / 2)
                local x = math_min(math_max(math_floor(frame.barWidth * value), half), frame.barWidth - half)
                frame.icon:SetPoint("CENTER", track, "LEFT", x, 0)
            end
        elseif frame.iconPosition == "center" then
            frame.icon:ClearAllPoints()
            frame.icon:SetPoint("CENTER", track, "CENTER", 0, 0)
        elseif frame.iconPosition == "follow-vertical" then
            frame.icon:ClearAllPoints()
            local y = math_floor(frame.barHeight * value)
            frame.icon:SetPoint("CENTER", track, "BOTTOM", 0, y)
        elseif frame.iconPosition == "follow-horizontal" then
            frame.icon:ClearAllPoints()
            local x = math_floor(frame.barWidth * value)
            frame.icon:SetPoint("CENTER", track, "LEFT", x, 0)
        end
    end
end

local function SetBorderTextureVisible(texture, visible)
    if not texture then return end
    if visible then
        texture:Show()
    else
        texture:Hide()
    end
end

local function ApplyProgressBorderCollapse(frame)
    local borders = frame and frame.track and frame.track.gui2Borders
    if not borders then return end

    SetBorderTextureVisible(borders.left, true)
    SetBorderTextureVisible(borders.right, true)
    SetBorderTextureVisible(borders.top, true)
    SetBorderTextureVisible(borders.bottom, true)

    if not (frame.collapseAdjacentBorder and frame.icon and (frame.iconGap or 0) <= 0) then
        return
    end

    if frame.iconPosition == "left" then
        SetBorderTextureVisible(borders.left, false)
    elseif frame.iconPosition == "right" then
        SetBorderTextureVisible(borders.right, false)
    elseif frame.iconPosition == "top" then
        SetBorderTextureVisible(borders.top, false)
    elseif frame.iconPosition == "bottom" or frame.iconPosition == "down" then
        SetBorderTextureVisible(borders.bottom, false)
    end
end

local function LayoutProgressBar(frame)
    if not (frame and frame.track) then return end

    local iconPosition = frame.iconPosition
    local iconSize = frame.iconSize or 0
    local iconGap = frame.iconGap or 0
    local barWidth = frame.barWidth or 1
    local barHeight = frame.barHeight or 1
    local extraWidth = (iconPosition == "left" or iconPosition == "right") and (iconSize + iconGap) or 0
    local extraHeight = (iconPosition == "top" or iconPosition == "bottom" or iconPosition == "down") and (iconSize + iconGap) or 0

    frame:SetSize(barWidth + extraWidth, barHeight + extraHeight)
    frame.track:ClearAllPoints()
    frame.track:SetSize(barWidth, barHeight)

    if iconPosition == "left" then
        frame.track:SetPoint("LEFT", frame, "LEFT", iconSize + iconGap, 0)
    elseif iconPosition == "right" then
        frame.track:SetPoint("LEFT", frame, "LEFT", 0, 0)
    elseif iconPosition == "top" then
        frame.track:SetPoint("TOP", frame, "TOP", 0, -(iconSize + iconGap))
    elseif iconPosition == "bottom" or iconPosition == "down" then
        frame.track:SetPoint("TOP", frame, "TOP", 0, 0)
    else
        frame.track:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end

    if frame.icon then
        frame.icon:ClearAllPoints()
        frame.icon:SetSize(iconSize, iconSize)
        if iconPosition == "left" then
            frame.icon:SetPoint("RIGHT", frame.track, "LEFT", -iconGap, 0)
        elseif iconPosition == "right" then
            frame.icon:SetPoint("LEFT", frame.track, "RIGHT", iconGap, 0)
        elseif iconPosition == "top" then
            frame.icon:SetPoint("BOTTOM", frame.track, "TOP", 0, iconGap)
        elseif iconPosition == "bottom" or iconPosition == "down" then
            frame.icon:SetPoint("TOP", frame.track, "BOTTOM", 0, -iconGap)
        elseif iconPosition == "center" then
            frame.icon:SetPoint("CENTER", frame.track, "CENTER", 0, 0)
        end
    end

    ApplyProgressFill(frame)
    ApplyProgressBorderCollapse(frame)
end

function GUI2.Data:CreateProgressBar(parent, opts)
    opts = opts or {}
    local vertical = opts.orientation == "vertical"
    local barWidth = opts.width or (vertical and 34 or 260)
    local barHeight = opts.height or (vertical and 136 or 24)
    local iconPosition = opts.iconPosition
    local sideIconSize = opts.iconSize or (vertical and barWidth or barHeight)
    local followIconSize = opts.followIconSize or opts.iconSize or GUI2:GetMetric("layout.size.icon", 22)
    local iconSize = iconPosition == "follow" and followIconSize or sideIconSize
    local iconGap = opts.iconGap or 0
    local extraWidth = (iconPosition == "left" or iconPosition == "right") and (iconSize + iconGap) or 0
    local extraHeight = (iconPosition == "top" or iconPosition == "bottom" or iconPosition == "down") and (iconSize + iconGap) or 0
    local frame = GUI2:CreateFrame(parent, {
        width = barWidth + extraWidth,
        height = barHeight + extraHeight,
    })
    ConfigureMotion(frame, opts)
    local track = GUI2:CreatePanel(frame, {
        width = barWidth,
        height = barHeight,
        surface = "color.control.track",
        border = "color.border.default",
    })
    frame.track = track
    local baseTrackRefreshTheme = track.RefreshTheme
    track.RefreshTheme = function(trackFrame)
        if baseTrackRefreshTheme then
            baseTrackRefreshTheme(trackFrame)
        elseif GUI2.RefreshPrimitive then
            GUI2:RefreshPrimitive(trackFrame)
        end
        ApplyProgressBorderCollapse(frame)
    end
    InheritMotion(track, frame)
    frame.orientation = vertical and "vertical" or "horizontal"
    frame.fillDirection = opts.fillDirection or (vertical and "up" or "left")
    frame.iconPosition = iconPosition
    frame.iconGap = iconGap
    frame.barWidth = barWidth
    frame.barHeight = barHeight
    frame.iconSize = iconSize
    frame.gui2IconAutoSize = opts.iconSize == nil and iconPosition ~= "follow"
    frame.collapseAdjacentBorder = opts.collapseAdjacentBorder == true
    frame.gui2FillTexture = opts.fillTexture
    frame.gui2FillColor = opts.fillColor or opts.fillKey or "color.accent.primary"

    local fill = GUI2:CreateTexture(track, {
        texture = opts.fillTexture or DEFAULT_PROGRESS_TEXTURE,
        layer = "ARTWORK",
    })
    frame.fill = fill
    ApplyProgressFillStyle(frame)
    InheritMotion(fill, frame)

    if iconPosition then
        local iconParent = iconPosition == "follow" and track or frame
        frame.icon = GUI2:CreateIconSlot(iconParent, {
            size = iconSize,
            rounded = opts.roundedIcon,
            icon = opts.icon,
            padding = opts.iconPadding or 0,
            animate = opts.animate,
            motion = opts.motion,
        })
        InheritMotion(frame.icon, frame)
        if frame.icon.SetFrameLevel and track.GetFrameLevel then
            frame.icon:SetFrameLevel(track:GetFrameLevel() + 3)
        end
    end

    frame.SetFillTexture = function(self, texture)
        self.gui2FillTexture = type(texture) == "string" and texture ~= "" and texture or nil
        ApplyProgressFillStyle(self)
    end
    frame.SetFillColor = function(self, r, g, b, a)
        self.gui2FillColor = NormalizeFillColor(r, g, b, a) or "color.accent.primary"
        ApplyProgressFillStyle(self)
    end
    frame.SetFillDirection = function(self, direction)
        self.fillDirection = direction or (self.orientation == "vertical" and "up" or "left")
        ApplyProgressFill(self)
    end
    frame.SetBarSize = function(self, width, height, nextIconSize)
        self.barWidth = math_max(1, tonumber(width) or self.barWidth or 1)
        self.barHeight = math_max(1, tonumber(height) or self.barHeight or 1)
        if nextIconSize ~= nil then
            self.iconSize = math_max(1, tonumber(nextIconSize) or self.iconSize or 1)
        elseif self.gui2IconAutoSize then
            self.iconSize = self.orientation == "vertical" and self.barWidth or self.barHeight
        end
        LayoutProgressBar(self)
    end
    frame.SetIcon = function(self, texture)
        if self.icon and self.icon.SetIcon then
            self.icon:SetIcon(texture)
        end
    end
    frame.RefreshTheme = function(self)
        if self.track and GUI2.RefreshPrimitive then
            GUI2:RefreshPrimitive(self.track)
        end
        ApplyProgressFillStyle(self)
        if self.icon and self.icon.RefreshTheme then
            self.icon:RefreshTheme()
        end
        ApplyProgressFill(self)
        ApplyProgressBorderCollapse(self)
    end
    GUI2:RegisterThemeObject(frame)
    LayoutProgressBar(frame)
    frame.SetValue = function(self, value, setOptions)
        local _, animate, options = ParseSetOptions(setOptions)
        local targetValue = tonumber(value) or 0
        if targetValue < 0 then targetValue = 0 end
        if targetValue > 1 then targetValue = 1 end

        if animate and self.gui2ValueInitialized and GUI2.PlayControlMotion then
            local handle = GUI2:PlayControlMotion(self, "progress-value", {
                owner = options and options.owner or self,
                key = options and options.key or nil,
                from = self.value or 0,
                to = targetValue,
                duration = options and options.duration or nil,
                durationKey = "medium",
                easing = options and options.easing or "sineOut",
                onUpdate = function(nextValue)
                    self.value = nextValue
                    ApplyProgressFill(self)
                end,
            })
            if handle then
                return handle
            end
        end

        self.value = targetValue
        ApplyProgressFill(self)
        self.gui2ValueInitialized = true
    end
    frame:SetValue(opts.value or 0.5, true)
    return frame
end

local function CreateSection(parent, title, x, y, width, height)
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

function GUI2.Data:RenderLab(parent, lab)
    local width = parent:GetWidth() > 100 and parent:GetWidth() or 920
    lab:RenderHeader(parent, "数据展示（Data）", "用于展示列表、行数据、统计、标签、空状态和进度条，重点检查信息密度和分割线。")
    lab:RenderComponentList(parent, "组件清单（Component List）", {
        "徽标（Badge）", "标签（Tag）", "信息行（InfoRow）", "统计块（StatBlock）",
        "空状态（EmptyState）", "列表（List）", "表格（Table）", "进度条（ProgressBar）",
    })

    local left = CreateSection(parent, "行与表格（Rows / List / Table）", 18, -88, 300, 400)
    local info = self:CreateInfoRow(left, "当前方案", "午夜黑")
    info:SetPoint("TOPLEFT", 14, -42)
    local list = self:CreateList(left, { width = 260, height = 104, items = { "普通行", "选中行", "禁用外观行" } })
    list:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -8)
    local tableFrame = self:CreateTable(left, {
        width = 260,
        height = 104,
        rowHeight = 18,
        dividerY = -30,
        rowStartY = -42,
        columns = { "名称", "状态", "值" },
        rows = {
            { "时钟", "就绪", "24" },
            { "信息条", "启用", "12" },
            { "组件库", "审查", "5B" },
        },
    })
    tableFrame:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -8)

    local middle = CreateSection(parent, "状态与标签（Stats / Badge / Tag）", 334, -88, 260, 400)
    local stat1 = self:CreateStatBlock(middle, { width = 118, label = "内存", value = "42 MB" })
    stat1:SetPoint("TOPLEFT", 14, -42)
    local stat2 = self:CreateStatBlock(middle, { width = 118, label = "帧率", value = "144", tone = "color.state.success" })
    stat2:SetPoint("LEFT", stat1, "RIGHT", 12, 0)
    local badge = self:CreateBadge(middle, "启用", "accent")
    badge:SetPoint("TOPLEFT", stat1, "BOTTOMLEFT", 0, -12)
    local tag = self:CreateTag(middle, "团队", "normal")
    tag:SetPoint("LEFT", badge, "RIGHT", 10, 0)
    local icon = GUI2:CreateIconSlot(middle, { size = 34, icon = "Interface\\Icons\\INV_Misc_QuestionMark" })
    icon:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 0, -14)
    local icon2 = GUI2:CreateIconSlot(middle, { size = 34, rounded = true, icon = "Interface\\Icons\\INV_Misc_Coin_01" })
    icon2:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    local empty = self:CreateEmptyState(middle, { width = 246, height = 76, title = "空状态", body = "没有符合条件的数据。" })
    empty:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -8)

    local progress = CreateSection(parent, "进度条（ProgressBar）", 610, -88, width - 628, 400)
    local hTitle = GUI2:CreateText(progress, "横向", "font.size.md", "color.text.heading")
    hTitle:SetPoint("TOPLEFT", 14, -38)
    local h1Label = GUI2:CreateText(progress, "左侧图标", "font.size.sm", "color.text.secondary")
    h1Label:SetPoint("TOPLEFT", 14, -62)
    local p1 = self:CreateProgressBar(progress, { width = 176, height = 22, value = 0.72, iconPosition = "left", roundedIcon = true })
    p1:SetPoint("TOPLEFT", h1Label, "BOTTOMLEFT", 0, -4)
    local h2Label = GUI2:CreateText(progress, "右侧图标", "font.size.sm", "color.text.secondary")
    h2Label:SetPoint("TOPLEFT", p1, "BOTTOMLEFT", 0, -10)
    local p2 = self:CreateProgressBar(progress, { width = 176, height = 22, value = 0.38, fillDirection = "right", iconPosition = "right", roundedIcon = true })
    p2:SetPoint("TOPLEFT", h2Label, "BOTTOMLEFT", 0, -4)
    local h3Label = GUI2:CreateText(progress, "跟随图标", "font.size.sm", "color.text.secondary")
    h3Label:SetPoint("TOPLEFT", p2, "BOTTOMLEFT", 0, -10)
    local p3 = self:CreateProgressBar(progress, { width = 176, height = 22, value = 0.58, iconPosition = "follow", roundedIcon = true })
    p3:SetPoint("TOPLEFT", h3Label, "BOTTOMLEFT", 0, -4)

    local vTitle = GUI2:CreateText(progress, "竖向", "font.size.md", "color.text.heading")
    vTitle:SetPoint("TOPLEFT", 14, -226)
    local v1Label = GUI2:CreateText(progress, "上", "font.size.sm", "color.text.secondary")
    v1Label:SetPoint("TOPLEFT", 14, -250)
    local p4 = self:CreateProgressBar(progress, { orientation = "vertical", width = 28, height = 104, value = 0.46, iconPosition = "top", roundedIcon = true })
    p4:SetPoint("TOPLEFT", v1Label, "BOTTOMLEFT", 0, -4)
    local v2Label = GUI2:CreateText(progress, "下", "font.size.sm", "color.text.secondary")
    v2Label:SetPoint("TOPLEFT", p4, "TOPRIGHT", 26, 18)
    local p5 = self:CreateProgressBar(progress, { orientation = "vertical", width = 28, height = 104, value = 0.84, iconPosition = "bottom", roundedIcon = true })
    p5:SetPoint("TOPLEFT", v2Label, "BOTTOMLEFT", 0, -4)
    local v3Label = GUI2:CreateText(progress, "跟随", "font.size.sm", "color.text.secondary")
    v3Label:SetPoint("TOPLEFT", p5, "TOPRIGHT", 26, 18)
    local p6 = self:CreateProgressBar(progress, { orientation = "vertical", width = 28, height = 104, value = 0.66, iconPosition = "follow", roundedIcon = true })
    p6:SetPoint("TOPLEFT", v3Label, "BOTTOMLEFT", 0, -4)
end
