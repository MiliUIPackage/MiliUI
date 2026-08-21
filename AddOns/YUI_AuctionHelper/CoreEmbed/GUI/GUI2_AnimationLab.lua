do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
if not YUI then return end

local GUI2 = YUI.GUI2
local Animation = YUI.Animation
if not GUI2 or not Animation then return end

GUI2.AnimationLab = GUI2.AnimationLab or {}

local Lab = GUI2.AnimationLab
local tinsert = tinsert or table.insert
local math_floor = math.floor

local function CreateButton(parent, text, width, onClick)
    if GUI2.Form and GUI2.Form.CreateButton then
        return GUI2.Form:CreateButton(parent, { text = text, width = width or 104, height = 26, onClick = onClick })
    end

    local button = GUI2:CreateButtonFrame(parent, { template = "BackdropTemplate", width = width or 104, height = 26 })
    local label = GUI2:CreateText(button, text, "font.size.sm", "color.text.primary")
    label:SetPoint("CENTER")
    button.text = label
    button:SetScript("OnClick", onClick)
    return button
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
    panel.title = label

    return panel
end

local function ResetBox(frame, parent, x, y)
    if not frame then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    frame:SetAlpha(1)
    if frame.SetScale then
        frame:SetScale(1)
    end
    frame:Show()
end

function Lab:RefreshStats()
    if not self.frame or not self.frame.stats then
        return
    end

    local stats = Animation:GetStats()
    self.frame.stats:SetText("active=" .. tostring(stats.active or 0) ..
        "  tween=" .. tostring(stats.tweens or 0) ..
        "  native=" .. tostring(stats.native or 0) ..
        "  owners=" .. tostring(stats.owners or 0))
end

function Lab:ResetSamples()
    Animation:StopOwner(self, false)

    local frame = self.frame
    if not frame then return end

    ResetBox(frame.motionBox, frame.motionSection, 22, -58)
    ResetBox(frame.transformBox, frame.transformSection, 34, -58)
    ResetBox(frame.stackBox, frame.stackSection, 28, -54)
    ResetBox(frame.floatText, frame.stackSection, 28, -98)

    if frame.floatText and frame.floatText.label then
        frame.floatText.label:SetText("+1280")
    end
    if frame.progress then
        frame.progress:SetValue(0.36, true)
    end
    if frame.controlCheck then
        frame.controlCheck:SetChecked(false, true)
    end
    if frame.controlSwitch then
        frame.controlSwitch:SetValue(false, true)
    end
    if frame.controlSegment then
        frame.controlSegment:SetValue("one", true)
    end
    if frame.controlProgress then
        frame.controlProgress:SetValue(0.28, true)
    end
    if frame.controlColor then
        frame.controlColor:SetValue({ 1, 0.82, 0.05, 1 }, true)
    end
    if frame.controlModSwitch then
        frame.controlModSwitch:SetValue(false, true)
    end
    if frame.maskController then
        frame.maskController:SetProgress(0.35)
    end
    if frame.maskValue then
        frame.maskValue:SetText("mask=35%")
    end
    if frame.stressItems then
        for _, item in ipairs(frame.stressItems) do
            item:Hide()
            item:SetAlpha(1)
            if item.SetScale then item:SetScale(1) end
        end
    end

    self:RefreshStats()
end

function Lab:PlayMotion(mode, side)
    local frame = self.frame
    if not frame or not frame.motionBox then return end

    side = side or "left"
    ResetBox(frame.motionBox, frame.motionSection, 22, -58)
    if frame.motionBox.label then
        frame.motionBox.label:SetText((mode == "out" and "Out " or "In ") .. side)
    end

    local options = {
        owner = self,
        key = "motion-slide",
        distance = 56,
        duration = 0.35,
        hide = false,
    }
    if mode == "out" then
        options.to = side
        Animation:SlideOut(frame.motionBox, options)
    else
        options.from = side
        Animation:SlideIn(frame.motionBox, options)
    end
    self:RefreshStats()
end

function Lab:PlayTransform()
    local frame = self.frame
    if not frame or not frame.transformBox then return end

    ResetBox(frame.transformBox, frame.transformSection, 34, -58)
    Animation:Pop(frame.transformBox, {
        owner = self,
        key = "transform-pop",
        duration = 0.28,
    })
    Animation:Pulse(frame.transformBox, {
        owner = self,
        key = "transform-pulse",
        duration = 0.55,
        amount = 0.08,
    })
    self:RefreshStats()
end

function Lab:PlayStack()
    local frame = self.frame
    if not frame then return end

    ResetBox(frame.stackBox, frame.stackSection, 28, -54)
    ResetBox(frame.floatText, frame.stackSection, 28, -98)
    Animation:SlideIn(frame.stackBox, {
        owner = self,
        key = "stack-slide",
        from = "left",
        distance = 48,
        duration = 0.32,
    })
    Animation:Pulse(frame.stackBox, {
        owner = self,
        key = "stack-pulse",
        duration = 0.6,
        amount = 0.07,
    })
    Animation:FloatText(frame.floatText, {
        owner = self,
        key = "stack-float",
        distance = 52,
        duration = 0.82,
        hide = false,
    })
    self:RefreshStats()
end

function Lab:PlayProgress()
    local frame = self.frame
    if not frame or not frame.progress then return end

    local nextValue = frame.progress.value and frame.progress.value > 0.65 and 0.22 or 0.86
    frame.progress:SetValue(nextValue, {
        animate = true,
        owner = self,
        duration = 0.45,
        easing = "sineOut",
    })
    self:RefreshStats()
end

function Lab:PlayControlSamples()
    local frame = self.frame
    if not frame then return end

    if frame.controlCheck then
        frame.controlCheck:SetChecked(not frame.controlCheck:GetChecked())
    end
    if frame.controlSwitch then
        frame.controlSwitch:Toggle()
    end
    if frame.controlSegment then
        local nextValue = frame.controlSegment.value == "one" and "two" or frame.controlSegment.value == "two" and "three" or "one"
        frame.controlSegment:SetValue(nextValue)
    end
    if frame.controlProgress then
        local nextValue = frame.controlProgress.value and frame.controlProgress.value > 0.62 and 0.28 or 0.82
        frame.controlProgress:SetValue(nextValue)
    end
    if frame.controlColor then
        local current = frame.controlColor.value
        local bright = type(current) == "table" and ((current[1] or current.r or 0) > 0.5)
        frame.controlColor:SetValue(bright and { 0.1, 0.6, 1, 1 } or { 1, 0.82, 0.05, 1 })
    end
    if frame.controlModSwitch then
        frame.controlModSwitch:SetValue(not frame.controlModSwitch.gui2Value)
    end
    self:RefreshStats()
end

function Lab:UpdateControlMotionStatus()
    local frame = self.frame
    if not frame then return end

    local strength = GUI2.GetMotionStrength and GUI2:GetMotionStrength() or "standard"
    if frame.controlMotionStatus then
        frame.controlMotionStatus:SetText("Motion: " .. tostring(strength) .. "；Off 只切状态，Low/Std/High 逐级增强。")
    end
    if frame.motionStrengthControl and frame.motionStrengthControl.value ~= strength then
        frame.motionStrengthControl:SetValue(strength, true)
    end
end

function Lab:SetMotionStrength(value)
    value = value or "standard"
    if GUI2.Appearance and GUI2.Appearance.SetUserOption then
        GUI2.Appearance:SetUserOption("motionStrength", value)
    elseif GUI2.Appearance and GUI2.Appearance.GetDB then
        local db = GUI2.Appearance:GetDB()
        if type(db) == "table" then
            db.userOptions = db.userOptions or {}
            db.userOptions.motionStrength = value
        end
    end
    self:UpdateControlMotionStatus()
end

function Lab:PlayMask()
    local frame = self.frame
    if not frame or not frame.maskController then return end

    local nextValue = frame.maskController.value and frame.maskController.value > 0.65 and 0.28 or 0.88
    frame.maskController:TweenTo(nextValue, {
        owner = self,
        duration = 0.46,
        easing = "sineOut",
    })
    if frame.maskValue then
        Animation:Tween({
            owner = self,
            target = frame.maskValue,
            key = "mask-label",
            from = frame.maskController.value or 0,
            to = nextValue,
            duration = 0.46,
            easing = "sineOut",
            onUpdate = function(value)
                frame.maskValue:SetText("mask=" .. tostring(math_floor((value * 100) + 0.5)) .. "%")
            end,
        })
    end
    self:RefreshStats()
end

function Lab:Stress()
    local frame = self.frame
    if not frame or not frame.lifecycleSection then return end

    frame.stressItems = frame.stressItems or {}
    for index = 1, 20 do
        local item = frame.stressItems[index]
        if not item then
            item = GUI2:CreatePanel(frame.lifecycleSection, {
                width = 18,
                height = 18,
                surface = "color.accent.primary",
                border = "color.border.subtle",
            })
            frame.stressItems[index] = item
        end
        local row = math_floor((index - 1) / 10)
        local col = (index - 1) % 10
        item:ClearAllPoints()
        item:SetPoint("TOPLEFT", frame.lifecycleGrid, "TOPLEFT", col * 24, -row * 28)
        item:SetAlpha(1)
        if item.SetScale then item:SetScale(1) end
        item:Show()

        Animation:Play(item, {
            owner = self,
            key = "stress",
            driver = "tween",
            duration = 0.28 + (index % 5) * 0.05,
            easing = "out",
            effects = {
                { type = "alpha", from = 0.2, to = 1 },
                { type = "translation", fromX = 0, fromY = -18, toX = 0, toY = 0 },
                { type = "scale", from = 0.72, to = 1 },
            },
        })
    end
    self:RefreshStats()
end

function Lab:PlayAll()
    self:PlayMotion()
    self:PlayTransform()
    self:PlayStack()
    self:PlayProgress()
    self:PlayMask()
end

function Lab:BuildMotionSection(content)
    local section = CreateSection(content, "Motion", 12, -12, 300, 160)
    self.frame.motionSection = section

    local box = GUI2:CreatePanel(section, { width = 94, height = 40, surface = "color.surface.panel", border = "color.border.accent" })
    local label = GUI2:CreateText(box, "Slide", "font.size.md", "color.text.accent")
    label:SetPoint("CENTER")
    box.label = label
    self.frame.motionBox = box

    local hint = GUI2:CreateText(section, "from 是进场来源，to 是离场方向。旧 direction 仍兼容。", "font.size.sm", "color.text.secondary")
    hint:SetPoint("TOPLEFT", 132, -52)
    hint:SetWidth(148)
    hint:SetJustifyH("LEFT")

    local dirs = {
        { label = "In L", mode = "in", side = "left" },
        { label = "In R", mode = "in", side = "right" },
        { label = "In T", mode = "in", side = "top" },
        { label = "In B", mode = "in", side = "bottom" },
        { label = "Out L", mode = "out", side = "left" },
        { label = "Out R", mode = "out", side = "right" },
        { label = "Out T", mode = "out", side = "top" },
        { label = "Out B", mode = "out", side = "bottom" },
    }
    for index, def in ipairs(dirs) do
        local row = math_floor((index - 1) / 4)
        local col = (index - 1) % 4
        local button = CreateButton(section, def.label, 58, function()
            Lab:PlayMotion(def.mode, def.side)
        end)
        button:SetPoint("BOTTOMLEFT", 12 + col * 66, 12 + (1 - row) * 30)
    end
end

function Lab:BuildTransformSection(content)
    local section = CreateSection(content, "Transform", 324, -12, 300, 160)
    self.frame.transformSection = section

    local box = GUI2:CreatePanel(section, { width = 102, height = 58, surface = "color.surface.popup", border = "color.border.accent", shadow = true })
    local label = GUI2:CreateText(box, "Pop", "font.size.md", "color.text.heading")
    label:SetPoint("CENTER")
    box.label = label
    self.frame.transformBox = box

    local hint = GUI2:CreateText(section, "缩放目标本身，边框跟着动；动画结束后重新校准为 1px。", "font.size.sm", "color.text.secondary")
    hint:SetPoint("TOPLEFT", 150, -54)
    hint:SetWidth(130)
    hint:SetJustifyH("LEFT")

    local button = CreateButton(section, "Pop + Pulse", 112, function() Lab:PlayTransform() end)
    button:SetPoint("BOTTOMLEFT", 12, 12)
end

function Lab:BuildStackSection(content)
    local section = CreateSection(content, "Stacking", 636, -12, 300, 160)
    self.frame.stackSection = section

    local box = GUI2:CreatePanel(section, { width = 88, height = 42, surface = "color.control.bg", border = "color.border.default" })
    local label = GUI2:CreateText(box, "Hit", "font.size.md", "color.text.primary")
    label:SetPoint("CENTER")
    box.label = label
    self.frame.stackBox = box

    local floatFrame = GUI2:CreateFrame(section, { width = 86, height = 34 })
    local text = GUI2:CreateText(floatFrame, "+1280", 22, "color.text.accent")
    text:SetPoint("CENTER")
    floatFrame.label = text
    self.frame.floatText = floatFrame

    local hint = GUI2:CreateText(section, "一次点击同时播底板滑入、闪一下和数字上飘；连续点会替换同类旧动画。", "font.size.sm", "color.text.secondary")
    hint:SetPoint("TOPLEFT", 136, -52)
    hint:SetWidth(142)
    hint:SetJustifyH("LEFT")

    local button = CreateButton(section, "Play Stack", 102, function() Lab:PlayStack() end)
    button:SetPoint("BOTTOMLEFT", 166, 12)
end

function Lab:BuildProgressSection(content)
    local section = CreateSection(content, "Tween / Progress", 12, -184, 300, 170)
    self.frame.progressSection = section

    local progress = GUI2.Data and GUI2.Data:CreateProgressBar(section, { width = 226, height = 24, value = 0.36, iconPosition = "follow", roundedIcon = true })
    if progress then
        progress:SetPoint("TOPLEFT", 28, -62)
        self.frame.progress = progress
    end

    local hint = GUI2:CreateText(section, "SetValue(value, { animate = true }) 走 TweenDriver。", "font.size.sm", "color.text.secondary")
    hint:SetPoint("TOPLEFT", 28, -102)
    hint:SetWidth(236)
    hint:SetJustifyH("LEFT")

    local button = CreateButton(section, "Tween Value", 110, function() Lab:PlayProgress() end)
    button:SetPoint("BOTTOMLEFT", 12, 12)
end

function Lab:BuildMaskSection(content)
    local section = CreateSection(content, "Mask Capability", 324, -184, 300, 170)
    self.frame.maskSection = section

    local track = GUI2:CreatePanel(section, { width = 220, height = 28, surface = "color.control.track", border = "color.border.default" })
    track:SetPoint("TOPLEFT", 30, -62)

    local texture = GUI2:CreateTexture(track, "color.accent.primary", 220, 28)
    texture:SetPoint("LEFT", track, "LEFT", 0, 0)
    self.frame.maskController = Animation.Mask:Create(texture, {
        owner = self,
        orientation = "horizontal",
        direction = "right",
        value = 0.35,
    })

    local value = GUI2:CreateText(section, "mask=35%", "font.size.md", "color.text.accent")
    value:SetPoint("TOPLEFT", 30, -102)
    self.frame.maskValue = value

    local hint = GUI2:CreateText(section, "v1 只验证裁剪能力，圆环组件留到 v2。", "font.size.sm", "color.text.secondary")
    hint:SetPoint("TOPLEFT", 30, -116)
    hint:SetWidth(236)
    hint:SetJustifyH("LEFT")

    local button = CreateButton(section, "Tween Mask", 104, function() Lab:PlayMask() end)
    button:SetPoint("BOTTOMLEFT", 12, 10)
end

function Lab:BuildLifecycleSection(content)
    local section = CreateSection(content, "Lifecycle / Stats", 636, -184, 300, 170)
    self.frame.lifecycleSection = section

    local text = GUI2:CreateText(section, "StopOwner 会清理当前 Lab 作为 owner 的所有动画。", "font.size.sm", "color.text.secondary")
    text:SetPoint("TOPLEFT", 18, -48)
    text:SetWidth(250)
    text:SetJustifyH("LEFT")

    local stress = CreateButton(section, "Stress 20", 96, function() Lab:Stress() end)
    stress:SetPoint("TOPLEFT", 18, -76)

    local stop = CreateButton(section, "Stop Owner", 104, function()
        Animation:StopOwner(Lab, false)
        Lab:RefreshStats()
    end)
    stop:SetPoint("LEFT", stress, "RIGHT", 10, 0)

    local grid = GUI2:CreateFrame(section, { width = 240, height = 48 })
    grid:SetPoint("TOPLEFT", 18, -116)
    section.grid = grid
    self.frame.lifecycleGrid = grid
end

function Lab:BuildControlMotionSection(content)
    local section = CreateSection(content, "Control Micro Motion", 12, -366, 924, 126)
    self.frame.controlSection = section

    local strength = GUI2.GetMotionStrength and GUI2:GetMotionStrength() or "standard"
    local status = GUI2:CreateText(section, "Motion: " .. tostring(strength) .. "；Off 只切状态，Low/Std/High 逐级增强。", "font.size.sm", "color.text.secondary")
    status:SetPoint("TOPLEFT", 14, -40)
    status:SetWidth(244)
    status:SetJustifyH("LEFT")
    self.frame.controlMotionStatus = status

    local motion = GUI2.Form and GUI2.Form:CreateSegmentedControl(section, {
        width = 230,
        height = 26,
        value = strength,
        motion = false,
        items = {
            { text = "Off", value = "off" },
            { text = "Low", value = "low" },
            { text = "Std", value = "standard" },
            { text = "High", value = "high" },
        },
        set = function(value)
            Lab:SetMotionStrength(value)
        end,
    })
    if motion then
        motion:SetPoint("TOPLEFT", 14, -70)
        self.frame.motionStrengthControl = motion
    end

    local button = CreateButton(section, "Press", 80, function() Lab:PlayControlSamples() end)
    button:SetPoint("TOPLEFT", 270, -36)
    self.frame.controlButton = button

    local disabled = GUI2.Form and GUI2.Form:CreateButton(section, { text = "Disabled", width = 92, height = 26, disabled = true })
    if disabled then
        disabled:SetPoint("LEFT", button, "RIGHT", 10, 0)
        self.frame.controlDisabledButton = disabled
    end

    local check = GUI2.Form and GUI2.Form:CreateCheckbox(section, { text = "Check", width = 108, checked = false })
    if check then
        check:SetPoint("LEFT", disabled or button, "RIGHT", 14, 0)
        self.frame.controlCheck = check
    end

    local color = GUI2.Form and GUI2.Form:CreateColorPicker(section, { width = 54, height = 26, default = { 1, 0.82, 0.05, 1 } })
    if color then
        color:SetPoint("LEFT", check or disabled or button, "RIGHT", 12, 0)
        self.frame.controlColor = color
    end

    local modSwitch = GUI2.Application and GUI2.Application:CreateModSwitch(section, {
        width = 92,
        height = 56,
        label = "Mod",
        default = false,
        onLabel = "ON",
        offLabel = "OFF",
    })
    if modSwitch then
        modSwitch:SetPoint("TOPLEFT", 780, -38)
        self.frame.controlModSwitch = modSwitch
    end

    local switch = GUI2.Form and GUI2.Form:CreateSwitch(section, { width = 68, checked = false, onText = "ON", offText = "OFF" })
    if switch then
        switch:SetPoint("TOPLEFT", 270, -74)
        self.frame.controlSwitch = switch
    end

    local segment = GUI2.Form and GUI2.Form:CreateSegmentedControl(section, {
        width = 168,
        value = "one",
        items = {
            { text = "One", value = "one" },
            { text = "Two", value = "two" },
            { text = "Three", value = "three" },
        },
    })
    if segment then
        segment:SetPoint("LEFT", switch, "RIGHT", 12, 0)
        self.frame.controlSegment = segment
    end

    local progress = GUI2.Data and GUI2.Data:CreateProgressBar(section, { width = 150, height = 20, value = 0.28, iconPosition = "follow", roundedIcon = true })
    if progress then
        progress:SetPoint("LEFT", segment, "RIGHT", 14, 0)
        self.frame.controlProgress = progress
    end

    self:UpdateControlMotionStatus()
end

function Lab:Create()
    if self.frame then
        return self.frame
    end

    local frame = GUI2:CreatePanel(UIParent, {
        name = "YUI_AnimationLabFrame",
        width = 980,
        height = 640,
        surface = "color.surface.window",
        border = "color.border.strong",
        shadow = true,
        shadowKey = "shadow.popup.size",
    })
    frame:SetPoint("CENTER", -86, 0)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()
    frame:SetScript("OnHide", function()
        Animation:StopOwner(Lab, false)
        Lab:RefreshStats()
    end)

    tinsert(UISpecialFrames, "YUI_AnimationLabFrame")

    local title = GUI2:CreateText(frame, "YUI Animation Lab", "font.size.title", "color.text.heading")
    title:SetPoint("TOPLEFT", 18, -16)
    frame.title = title

    local subtitle = GUI2:CreateText(frame, "验证 Core\\Animation、GUI2 动画封装、owner 清理和 target + key 替换策略。", "font.size.sm", "color.text.secondary")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    frame.subtitle = subtitle

    local close = GUI2:CreateCloseButton(frame, function()
        frame:Hide()
    end)
    close:SetPoint("TOPRIGHT", -14, -14)
    frame.close = close

    local toolbar = GUI2:CreateFrame(frame, { width = 620, height = 30 })
    toolbar:SetPoint("TOPLEFT", 16, -68)
    frame.toolbar = toolbar

    local playAll = CreateButton(toolbar, "Play All", 86, function() Lab:PlayAll() end)
    playAll:SetPoint("LEFT", 0, 0)
    local stopOwner = CreateButton(toolbar, "Stop Owner", 104, function()
        Animation:StopOwner(Lab, false)
        Lab:RefreshStats()
    end)
    stopOwner:SetPoint("LEFT", playAll, "RIGHT", 8, 0)
    local reset = CreateButton(toolbar, "Reset", 76, function() Lab:ResetSamples() end)
    reset:SetPoint("LEFT", stopOwner, "RIGHT", 8, 0)
    local stress = CreateButton(toolbar, "Stress 20", 92, function() Lab:Stress() end)
    stress:SetPoint("LEFT", reset, "RIGHT", 8, 0)

    local stats = GUI2:CreateText(frame, "", "font.size.sm", "color.text.secondary")
    stats:SetPoint("TOPRIGHT", -20, -74)
    stats:SetWidth(330)
    stats:SetJustifyH("RIGHT")
    frame.stats = stats

    local content = GUI2:CreatePanel(frame, {
        surface = "color.surface.panel",
        border = "color.border.default",
    })
    content:SetPoint("TOPLEFT", 16, -108)
    content:SetPoint("BOTTOMRIGHT", -16, 16)
    frame.content = content

    self.frame = frame
    self:BuildMotionSection(content)
    self:BuildTransformSection(content)
    self:BuildStackSection(content)
    self:BuildProgressSection(content)
    self:BuildMaskSection(content)
    self:BuildLifecycleSection(content)
    self:BuildControlMotionSection(content)
    self:ResetSamples()

    return frame
end

function Lab:Open()
    local frame = self:Create()
    frame:Show()
    self:UpdateControlMotionStatus()
    self:RefreshStats()
end

function Lab:Toggle()
    local frame = self:Create()
    if frame:IsShown() then
        frame:Hide()
    else
        self:Open()
    end
end

local function RegisterSlash()
    if not SlashCmdList or SlashCmdList.YUI_ANIMATION_LAB then return end
    _G.SLASH_YUI_ANIMATION_LAB1 = "/yuianim"
    _G.SLASH_YUI_ANIMATION_LAB2 = "/yuianimation"
    SlashCmdList.YUI_ANIMATION_LAB = function()
        Lab:Toggle()
    end
end

RegisterSlash()
