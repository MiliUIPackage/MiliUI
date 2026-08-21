do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
YUI.GUI2 = YUI.GUI2 or {}

local GUI2 = YUI.GUI2
local CreateFrame = CreateFrame
local UIParent = UIParent
local math_max = math.max
local math_floor = math.floor
local tonumber = tonumber

GUI2.Overlay = GUI2.Overlay or {}

local MODAL_SCRIM_ALPHA = 0.62
local MODAL_SCRIM_FADE_DURATION = 0.20

local function HideModalScrim(dialog)
    if not dialog then return end
    if YUI.Animation and YUI.Animation.StopOwner then
        YUI.Animation:StopOwner(dialog)
    end
    local scrim = dialog.gui2ModalScrim
    if scrim then
        scrim:SetAlpha(1)
        scrim:Hide()
    end
end

function GUI2.Overlay:ShowModalScrim(dialog, opts)
    if not (dialog and UIParent) then return nil end
    opts = opts or {}

    local scrim = dialog.gui2ModalScrim
    if not scrim then
        scrim = GUI2:CreateFrame(UIParent)
        scrim:SetAllPoints(UIParent)
        if scrim.EnableMouse then scrim:EnableMouse(true) end

        local shade = GUI2:CreateTexture(scrim, { layer = "BACKGROUND" })
        shade:SetAllPoints(scrim)
        shade:SetColorTexture(0, 0, 0, opts.alpha or MODAL_SCRIM_ALPHA)
        scrim.shade = shade
        scrim:Hide()
        dialog.gui2ModalScrim = scrim

        if dialog.HookScript then
            dialog:HookScript("OnHide", HideModalScrim)
        end
    elseif scrim.shade then
        scrim.shade:SetColorTexture(0, 0, 0, opts.alpha or MODAL_SCRIM_ALPHA)
    end

    local dialogLevel = dialog.GetFrameLevel and dialog:GetFrameLevel() or 2
    if dialogLevel < 2 and dialog.SetFrameLevel then
        dialogLevel = 2
        dialog:SetFrameLevel(dialogLevel)
    end
    if scrim.SetFrameStrata and dialog.GetFrameStrata then
        scrim:SetFrameStrata(dialog:GetFrameStrata() or "DIALOG")
    end
    if scrim.SetFrameLevel then
        local requestedLevel = tonumber(opts.frameLevel)
        local scrimLevel = requestedLevel ~= nil
            and math_max(math_floor(requestedLevel), 0)
            or math_max(dialogLevel - 1, 0)
        scrim:SetFrameLevel(scrimLevel)
    end

    scrim:SetAlpha(1)
    scrim:Show()
    if GUI2.FadeIn then
        GUI2:FadeIn(scrim, {
            from = 0,
            to = 1,
            duration = opts.duration or MODAL_SCRIM_FADE_DURATION,
            owner = dialog,
            key = opts.key or "modal-scrim",
        })
    end
    return scrim
end

function GUI2:ShowModalScrim(dialog, opts)
    return self.Overlay:ShowModalScrim(dialog, opts)
end

local function PlayOverlayEnter(frame, key)
    if frame and GUI2.SlideIn then
        GUI2:SlideIn(frame, {
            owner = GUI2.Overlay,
            key = key or "overlay-popup",
            from = "bottom",
            distance = 14,
            duration = 0.14,
        })
    end
end

local function Panel(parent, title, body, width, height, tone)
    local frame = GUI2:CreatePanel(parent, {
        width = width or 220,
        height = height or 96,
        surface = "color.surface.popup",
        border = tone == "danger" and "color.border.error" or "color.popup.border",
        shadow = true,
        shadowKey = "shadow.popup.size",
    })
    local heading = GUI2:CreateText(frame, title, "font.size.lg", tone == "danger" and "color.state.error" or "color.text.heading")
    heading:SetPoint("TOPLEFT", 12, -10)
    local text = GUI2:CreateText(frame, body, "font.size.sm", "color.text.secondary")
    text:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    text:SetWidth((width or 220) - 24)
    text:SetWordWrap(true)
    frame.heading = heading
    frame.body = text
    return frame
end

function GUI2.Overlay:CreateTooltip(parent, opts)
    opts = opts or {}
    return Panel(parent, opts.title or "提示说明", opts.body or "只读的上下文说明。", opts.width or 220, opts.height or 82)
end

function GUI2.Overlay:CreatePopover(parent, opts)
    opts = opts or {}
    local frame = Panel(parent, opts.title or "浮动面板", opts.body or "小型可交互浮层。", opts.width or 240, opts.height or 118)
    local action = GUI2.Form:CreateButton(frame, { text = opts.actionText or "操作", width = 86 })
    action:SetPoint("BOTTOMRIGHT", -10, 10)
    return frame
end

function GUI2.Overlay:CreatePopup(parent, opts)
    opts = opts or {}
    local frame = Panel(parent, opts.title or "弹出窗口", opts.body or "带操作按钮的浮层容器。", opts.width or 260, opts.height or 132)
    local ok = GUI2.Form:CreateButton(frame, { text = opts.okText or "完成", width = 80, state = "selected" })
    ok:SetPoint("BOTTOMRIGHT", -10, 10)
    PlayOverlayEnter(frame, "overlay-popup")
    return frame
end

function GUI2.Overlay:CreateConfirmDialog(parent, opts)
    opts = opts or {}
    local frame = Panel(parent, opts.title or "确认操作", opts.body or "危险操作确认示例。", opts.width or 280, opts.height or 136, "danger")
    local cancel = GUI2.Form:CreateButton(frame, { text = opts.cancelText or "取消", width = 78 })
    cancel:SetPoint("BOTTOMRIGHT", -100, 10)
    local confirm = GUI2.Form:CreateButton(frame, { text = opts.confirmText or "确认", width = 84, state = "selected" })
    confirm:SetPoint("BOTTOMRIGHT", -10, 10)
    PlayOverlayEnter(frame, "overlay-confirm")
    return frame
end

function GUI2.Overlay:CreateMenu(parent, opts)
    opts = opts or {}
    local width = opts.width or 180
    local items = opts.items or { "第一项", "第二项", "禁用项" }
    local rowHeight = opts.rowHeight or 24
    local gap = opts.gap or 6
    local height = opts.height or (16 + (#items * rowHeight) + math_max(#items - 1, 0) * gap)
    local frame = GUI2:CreatePanel(parent, {
        width = width,
        height = height,
        surface = "color.surface.popup",
        border = "color.popup.border",
        shadow = true,
        shadowKey = "shadow.popup.size",
    })
    for i, item in ipairs(items) do
        local spec = type(item) == "table" and item or { text = item }
        local disabled = spec.disabled == true
        local row = GUI2:CreateButtonFrame(frame, {
            template = "BackdropTemplate",
            width = width - 16,
            height = rowHeight,
        })
        row.gui2Surface = "color.surface.popup"
        GUI2:ApplyBackdrop(row, "color.surface.popup")
        GUI2:CreateBorder(row, "color.border.subtle")
        row:SetPoint("TOPLEFT", 8, -8 - ((i - 1) * (rowHeight + gap)))
        local textColor = disabled and "color.text.disabled" or (spec.danger and "color.state.error" or "color.text.primary")
        local text = GUI2:CreateText(row, spec.text or "", "font.size.sm", textColor)
        text:SetPoint("LEFT", 8, 0)
        text:SetPoint("RIGHT", -8, 0)
        text:SetJustifyH("LEFT")
        row.text = text
        row:SetScript("OnEnter", function(button)
            if disabled then return end
            button.gui2Surface = "color.control.hover"
            GUI2:ApplyBackdrop(button, "color.control.hover")
        end)
        row:SetScript("OnLeave", function(button)
            button.gui2Surface = "color.surface.popup"
            GUI2:ApplyBackdrop(button, "color.surface.popup")
        end)
        row:SetScript("OnClick", function(button)
            if disabled then return end
            if spec.onClick then spec.onClick(button, frame, spec) end
            if opts.closeOnClick ~= false then
                frame:Hide()
            end
        end)
    end
    return frame
end

function GUI2.Overlay:CreateDropdownMenu(parent, opts)
    opts = opts or {}
    return self:CreateMenu(parent, {
        width = opts.width or 190,
        height = opts.height,
        items = opts.items or { "午夜黑", "原生黑金" },
    })
end

function GUI2.Overlay:CreateContextMenu(parent, opts)
    opts = opts or {}
    return self:CreateMenu(parent, {
        width = opts.width or 200,
        height = opts.height,
        items = opts.items or { "打开设置", "移动到顶部栏", "重置模块" },
    })
end

function GUI2.Overlay:CreateToast(parent, opts)
    opts = opts or {}
    local tone = opts.tone
    local width = opts.width or 260
    local padding = 12
    local gap = 4
    local borderKey = "color.popup.border"
    local titleColorKey = "color.text.heading"
    if tone == "warning" then
        borderKey = "color.state.warning"
        titleColorKey = "color.state.warning"
    elseif tone == "danger" or tone == "error" then
        borderKey = "color.state.error"
        titleColorKey = "color.state.error"
    end

    local frame = GUI2:CreatePanel(parent, {
        width = width,
        height = opts.height or 54,
        surface = "color.surface.popup",
        border = borderKey,
        shadow = true,
    })
    local title = GUI2:CreateText(frame, opts.title or "通知消息", "font.size.md", titleColorKey)
    title:SetPoint("TOPLEFT", padding, -8)
    title:SetWidth(width - padding * 2)
    title:SetWordWrap(true)

    local body = GUI2:CreateText(frame, opts.body or "轻量级反馈已经加入队列。", "font.size.sm", "color.text.secondary")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    body:SetWidth(width - padding * 2)
    body:SetWordWrap(true)

    local titleHeight = title:GetStringHeight() or 16
    local bodyHeight = body:GetStringHeight() or 14
    frame:SetHeight(math.max(opts.height or 54, 8 + titleHeight + gap + bodyHeight + padding))
    frame.title = title
    frame.body = body
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

function GUI2.Overlay:RenderLab(parent, lab)
    local width = parent:GetWidth() > 100 and parent:GetWidth() or 920
    lab:RenderHeader(parent, "浮层组件（Overlay）", "用于临时信息、菜单、确认和反馈提示，重点检查层级、阴影、边框和文字可读性。")
    lab:RenderComponentList(parent, "组件清单（Component List）", {
        "提示说明（Tooltip）", "浮动面板（Popover）", "弹出窗口（Popup）", "确认弹窗（ConfirmDialog）",
        "菜单（Menu）", "下拉菜单（DropdownMenu）", "上下文菜单（ContextMenu）", "通知消息（Toast）",
    })

    local top = CreateSection(parent, "提示与弹出（Tooltip / Popover / Popup）", 18, -88, width - 36, 186)
    local tooltip = self:CreateTooltip(top, { title = "提示说明", body = "用于解释按钮或状态。", width = 220 })
    tooltip:SetPoint("TOPLEFT", 14, -42)
    local popover = self:CreatePopover(top, { title = "浮动面板", body = "可放少量操作内容。", width = 250, height = 112 })
    popover:SetPoint("LEFT", tooltip, "RIGHT", 18, 0)
    local popup = self:CreatePopup(top, { title = "弹出窗口", body = "用于短流程操作。", width = 270, height = 118 })
    popup:SetPoint("LEFT", popover, "RIGHT", 18, 0)

    local menus = CreateSection(parent, "菜单与反馈（Menu / Dialog / Toast）", 18, -292, width - 36, 196)
    local dropdown = self:CreateDropdownMenu(menus, { width = 176, height = 96 })
    dropdown:SetPoint("TOPLEFT", 14, -38)
    local context = self:CreateContextMenu(menus, { width = 184, height = 96 })
    context:SetPoint("LEFT", dropdown, "RIGHT", 14, 0)
    local confirm = self:CreateConfirmDialog(menus, { width = 254, height = 96, title = "删除配置", body = "此操作需要确认。" })
    confirm:SetPoint("LEFT", context, "RIGHT", 14, 0)
    local toast = self:CreateToast(menus, { width = 218, title = "已保存", body = "配置已更新。" })
    toast:SetPoint("LEFT", confirm, "RIGHT", 14, 0)

end
