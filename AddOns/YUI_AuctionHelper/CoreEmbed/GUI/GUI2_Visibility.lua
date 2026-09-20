do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local _, YUI = ...
local GUI2 = YUI and YUI.GUI2
if not (GUI2 and GUI2.Form and YUI.Visibility) then return end
local V = YUI.Visibility
local BRANCHES = { "inCombat", "outOfCombat" }
local MODES = { "always", "hidden", "hover", "target" }
local editors = setmetatable({}, { __mode = "k" })
local overlay

local function T(key)
    local locale = YUI.Locale and YUI.Locale:Get("Core")
    return locale and locale["visibility." .. key] or key
end

local function Normalize(rule)
    return V:MigrateGroup(rule)
end

local function Supported(key)
    local api = YUI.API and YUI.API.Visibility
    return not api or not api.IsSupported or api.IsSupported(key) == true
end

local function BranchSummary(branch, full, short)
    local text = T((short and "short_mode." or "mode.") .. branch.mode)
    if not V:HasActiveHides(branch) then return text end
    if not full then return text .. "＊" end
    text = text .. " · " .. T("hide_heading") .. ":"
    if branch.hide.mounted ~= "any" then text = text .. " · " .. T("hide." .. branch.hide.mounted) end
    if branch.hide.skyriding then text = text .. " · " .. T("hide.skyriding") end
    if branch.hide.housing then text = text .. " · " .. T("hide.housing") end
    return text
end

local function SameEffective(a, b)
    if a.mode ~= b.mode then return false end
    return (a.mode == "hover" or a.mode == "hidden") or
        (a.hide.mounted == b.hide.mounted and a.hide.skyriding == b.hide.skyriding and a.hide.housing == b.hide.housing)
end

local function Tooltip(button, rule, branchKey)
    if not _G.GameTooltip then return end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(T("title"))
    for _, key in ipairs(BRANCHES) do
        if not branchKey or branchKey == key then
            local branch = rule[key]
            local hide = branch.hide
            GameTooltip:AddLine(" ")
            GameTooltip:AddLine(T("branch." .. key), 0.7, 0.8, 0.9)
            local mountOnly = branch.mode == "always" and hide.mounted ~= "any"
                and not hide.skyriding and not hide.housing
            if mountOnly then
                GameTooltip:AddLine(T(hide.mounted == "unmounted" and "tooltip.only_mounted" or "tooltip.only_unmounted"), 1, 1, 1, true)
            else
                GameTooltip:AddLine(T("mode." .. branch.mode), 1, 1, 1, true)
                if V:HasActiveHides(branch) then
                    GameTooltip:AddLine(T("tooltip.hide_any"), 1, 1, 1, true)
                    for _, condition in ipairs({ "mounted", "unmounted", "skyriding", "housing" }) do
                        if hide.mounted == condition or hide[condition] == true then
                            GameTooltip:AddLine("· " .. T("hide." .. condition), 1, 1, 1, true)
                        end
                    end
                end
            end
        end
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(T("pet_battle_locked"), 0.7, 0.8, 0.9, true)
    GameTooltip:Show()
end

local function Anchor(panel, button)
    panel:ClearAllPoints()
    panel:SetClampedToScreen(true)
    local scale = button.GetEffectiveScale and button:GetEffectiveScale() or 1
    local panelScale = panel.GetEffectiveScale and panel:GetEffectiveScale() or 1
    local bottom = button.GetBottom and button:GetBottom() or 0
    local top = button.GetTop and button:GetTop() or (bottom + button:GetHeight())
    local screenHeight = UIParent:GetHeight() * UIParent:GetEffectiveScale()
    local below, above = bottom * scale, screenHeight - top * scale
    local needed = (panel:GetHeight() + 12) * panelScale
    if below < needed and above > below then
        panel:SetPoint("BOTTOMLEFT", button, "TOPLEFT", 0, 4)
    else
        panel:SetPoint("TOPLEFT", button, "BOTTOMLEFT", 0, -4)
    end
end

local function Dropdown(parent, width)
    local button = GUI2:CreateButtonFrame(parent, { width = width, height = 30, template = "BackdropTemplate" })
    GUI2:SkinDropdownButton(button)
    return button
end

-- Lightweight choices share themed paints without a permanent button border.
local function Option(parent, opts)
    local button = GUI2:CreateButtonFrame(parent, opts)
    local hover = GUI2:CreateTexture(button, "color.control.hover", "HIGHLIGHT")
    hover:SetAllPoints(button)
    button:SetHighlightTexture(hover, "BLEND")
    function button:SetDisabled(disabled)
        self.gui2Disabled = disabled == true
        self:SetEnabled(not self.gui2Disabled)
        self:SetAlpha(self.gui2Disabled and 0.45 or 1)
    end
    return button
end

local function AddRadioIndicator(button)
    local function Disc(size, subLevel)
        local texture = GUI2:CreateTexture(button, {
            texture = GUI2.DurationRingTextures.disc,
            width = size, height = size, layer = "ARTWORK", subLevel = subLevel,
        })
        -- Preserve smooth sampling when the small discs land between screen pixels.
        GUI2:ApplyTexturePixelPolicy(texture)
        texture:SetPoint("CENTER", button, "LEFT", 9, 0)
        return texture
    end
    button.radioRing = Disc(18, 0)
    button.radioBackground = Disc(16, 1)
    button.radioDot = Disc(8, 2)
    function button:RefreshTheme()
        local border = (self.gui2Selected or self.gui2Hovered) and "color.border.accent" or "color.border.default"
        self.radioRing:SetVertexColor(GUI2:GetColor(border))
        self.radioBackground:SetVertexColor(GUI2:GetColor("color.control.bg"))
        self.radioDot:SetVertexColor(GUI2:GetColor("color.accent.fill"))
        self.radioDot:SetShown(self.gui2Selected == true)
    end
    function button:SetSelected(selected)
        self.gui2Selected = selected == true
        self:RefreshTheme()
    end
    button:HookScript("OnEnter", function(self)
        self.gui2Hovered = not self.gui2Disabled
        self:RefreshTheme()
    end)
    button:HookScript("OnLeave", function(self)
        self.gui2Hovered = false
        self:RefreshTheme()
    end)
    button:RefreshTheme()
    GUI2:RegisterThemeObject(button)
end

local function CloseButton(parent, callback)
    local button = Option(parent, { width = 24, height = 24, onClick = callback })
    local icon = GUI2:CreateIcon(button, { icon = GUI2:GetSettingsIcon("x"), size = 14 })
    icon:SetPoint("CENTER")
    return button
end

local function EnsureOverlay()
    if overlay then return overlay end
    local o = { modes = {}, hides = {}, rows = {} }
    overlay = o
    o.blocker = GUI2:CreateFrame(UIParent, { mouse = true, hidden = true })
    o.blocker:SetAllPoints(UIParent)
    o.blocker:SetFrameStrata("FULLSCREEN_DIALOG")
    o.blocker:SetFrameLevel(719)
    local function Panel(level, height)
        local panel = GUI2:CreatePanel(UIParent, { width = 320, height = height,
            surface = "color.surface.popup", border = "color.popup.border", shadow = true })
        panel:SetFrameStrata("FULLSCREEN_DIALOG")
        panel:SetFrameLevel(level)
        panel:EnableMouse(true)
        panel:Hide()
        if panel.EnableKeyboard then
            panel:EnableKeyboard(true)
            panel:SetScript("OnKeyDown", function(self, key)
                self:SetPropagateKeyboardInput(key ~= "ESCAPE")
                if key == "ESCAPE" and o.owner then o:CloseTopPanel() end
            end)
        end
        return panel
    end
    o.main = Panel(720, 118)
    o.detail = Panel(730, 330)
    local title = GUI2:CreateText(o.main, T("title"), "font.size.md", "color.text.heading", "LEFT")
    title:SetPoint("TOPLEFT", 12, -12)
    local close = CloseButton(o.main, function() if o.owner then o.owner:ClosePanel() end end)
    close:SetPoint("TOPRIGHT", -6, -6)
    o.detailTitle = GUI2:CreateText(o.detail, "", "font.size.md", "color.text.secondary", "LEFT")
    o.detailTitle:SetPoint("TOPLEFT", 12, -12)
    function o:CloseTopPanel()
        if self.detail:IsShown() and self.main:IsShown() then
            self.detail:Hide()
            self.detailAnchor = nil
            self.main:EnableKeyboard(true)
        elseif self.owner then self.owner:ClosePanel() end
    end
    local detailClose = CloseButton(o.detail, function() o:CloseTopPanel() end)
    detailClose:SetPoint("TOPRIGHT", -6, -6)
    local function Commit(field)
        local owner = o.owner
        if not owner then return end
        owner:RefreshSummary()
        if owner.setter then owner.setter(owner:GetValue(), field, owner) end
        for editor in pairs(editors) do
            if editor ~= owner and owner.binding and editor.binding == owner.binding then
                editor:SetValue(owner.rule, true)
            end
        end
        o:Refresh()
    end
    for index, mode in ipairs(MODES) do
        local button = Option(o.detail, { width = 296, height = 28,
            text = T("mode." .. mode), justifyH = "LEFT",
            onClick = function()
                if not o.owner then return end
                o.owner.rule[o.branch].mode = mode
                Commit(o.branch .. ".mode")
            end })
        button.text = GUI2:CreateText(button, T("mode." .. mode), "font.size.md", "color.text.primary", "LEFT")
        button.text:SetPoint("LEFT", 26, 0)
        AddRadioIndicator(button)
        o.modes[mode] = button
    end
    o.divider = GUI2:CreateDivider(o.detail, { width = 296, height = 1 })
    o.hideLabel = GUI2:CreateText(o.detail, T("hide_heading"), "font.size.md", "color.text.secondary", "LEFT")
    for _, key in ipairs({ "mounted", "unmounted", "skyriding", "housing" }) do
        o.hides[key] = GUI2.Form:CreateCheckbox(o.detail, { width = 296, height = 28, text = T("hide." .. key),
            set = function(value)
                if o.refreshing or not o.owner then return end
                local hide = o.owner.rule[o.branch].hide
                if key == "mounted" or key == "unmounted" then hide.mounted = value and key or "any"
                else hide[key] = value == true end
                Commit(o.branch .. ".hide." .. key)
            end })
    end
    function o:Refresh()
        local owner = self.owner
        if not owner then return end
        self.refreshing = true
        for _, key in ipairs(BRANCHES) do self.rows[key].text:SetText(BranchSummary(owner.rule[key], false)) end
        local branch = owner.rule[self.branch or "inCombat"]
        local y = -42
        for _, mode in ipairs(MODES) do
            local button = self.modes[mode]
            local shown = mode ~= "hover" or owner.allowHover
            button:SetShown(shown)
            if shown then
                button:ClearAllPoints(); button:SetPoint("TOPLEFT", self.detail, "TOPLEFT", 12, y)
                button:SetWidth(self.detail:GetWidth() - 24)
                button:SetSelected(branch.mode == mode)
                button:SetDisabled(owner.gui2Disabled or (mode == "target" and not Supported("target")))
                y = y - 28
            end
        end
        local showHides = branch.mode ~= "hover" and branch.mode ~= "hidden"
        self.divider:SetShown(showHides)
        if showHides then
            self.divider:ClearAllPoints()
            self.divider:SetPoint("TOPLEFT", self.detail, "TOPLEFT", 12, y - 3)
            self.divider:SetWidth(self.detail:GetWidth() - 24)
            y = y - 8
        end
        self.hideLabel:SetShown(showHides)
        if showHides then self.hideLabel:ClearAllPoints(); self.hideLabel:SetPoint("TOPLEFT", self.detail, "TOPLEFT", 12, y - 5); y = y - 30 end
        for _, key in ipairs({ "mounted", "unmounted", "skyriding", "housing" }) do
            local checkbox = self.hides[key]
            checkbox:SetShown(showHides)
            if showHides then
                checkbox:ClearAllPoints(); checkbox:SetPoint("TOPLEFT", self.detail, "TOPLEFT", 12, y)
                checkbox:SetWidth(self.detail:GetWidth() - 24)
                checkbox:SetValue((key == "mounted" or key == "unmounted") and branch.hide.mounted == key or branch.hide[key] == true, true)
                checkbox:SetDisabled(owner.gui2Disabled or not Supported(key == "unmounted" and "mounted" or key))
                y = y - 30
            end
        end
        self.detail:SetHeight(-y + 8)
        if self.detailAnchor then Anchor(self.detail, self.detailAnchor) end
        self.refreshing = false
    end
    function o:OpenBranch(key, button)
        if self.detail:IsShown() and self.branch == key and self.detailAnchor == button then
            self:CloseTopPanel()
            return
        end
        if GameTooltip then GameTooltip:Hide() end
        self.main:EnableKeyboard(false)
        self.branch = key
        self.detailAnchor = button
        self.detailTitle:SetText(T("branch." .. key) .. " · " .. T("title"))
        self:Refresh()
        Anchor(self.detail, button)
        self.detail:Show()
    end
    for index, key in ipairs(BRANCHES) do
        local label = GUI2:CreateText(o.main, T("branch." .. key), "font.size.md", "color.text.primary", "LEFT")
        label:SetPoint("TOPLEFT", 12, -42 - (index - 1) * 36)
        local button = Dropdown(o.main, 252)
        button:SetPoint("TOPLEFT", 96, -36 - (index - 1) * 36)
        button:SetPoint("RIGHT", o.main, "RIGHT", -12, 0)
        button:SetScript("OnMouseUp", function() o:OpenBranch(key, button) end)
        o.rows[key] = button
    end
    o.blocker:SetScript("OnMouseDown", function() if o.owner then o.owner:ClosePanel() end end)
    return o
end

function GUI2.Form:CreateVisibilityRuleEditor(parent, opts)
    opts = opts or {}
    local width = opts.width or 320
    local compact = opts.compact == true
    local frame = GUI2:CreateFrame(parent, { width = width, height = compact and (opts.height or 30) or 68 })
    frame.rule = Normalize(opts.value)
    frame.allowHover = opts.allowHover == true
    frame.binding, frame.setter, frame.getter = opts.binding, opts.set, opts.get
    frame.gui2Context = opts.context
    frame.rows = {}
    editors[frame] = true
    local function Open(button, key)
        if frame.gui2Disabled then return end
        if frame.getter then frame:SetValue(frame.getter(), true) end
        local o = EnsureOverlay()
        if o.owner and o.owner ~= frame then o.owner:ClosePanel() end
        if GameTooltip then GameTooltip:Hide() end
        o.owner = frame
        o.main:SetWidth(opts.popupWidth or 320)
        o.detail:SetWidth(opts.popupWidth or 320)
        o.blocker:Show()
        GUI2.VisibilityRuleOpenEditor = frame
        if key then o.main:Hide(); o:OpenBranch(key, button)
        else o.detail:Hide(); o.detailAnchor = nil; o:Refresh(); Anchor(o.main, button); o.main:EnableKeyboard(true); o.main:Show() end
    end
    if compact then
        frame.button = Dropdown(frame, width)
        frame.button:SetAllPoints(frame)
        frame.button:SetScript("OnMouseUp", function()
            if frame:IsPanelOpen() then frame:ClosePanel() else Open(frame.button) end
        end)
        frame.button:HookScript("OnEnter", function() Tooltip(frame.button, frame.rule) end)
        frame.button:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
    else
        for index, key in ipairs(BRANCHES) do
            local label = GUI2:CreateText(frame, T("branch." .. key), "font.size.md", "color.text.primary", "LEFT")
            label:SetPoint("TOPLEFT", 0, -8 - (index - 1) * 38)
            local labelWidth = opts.labelWidth or 84
            local button = Dropdown(frame, math.min(opts.controlWidth or 280, width - labelWidth))
            button:SetPoint("TOPLEFT", labelWidth, -(index - 1) * 38)
            button:SetScript("OnMouseUp", function() Open(button, key) end)
            button:HookScript("OnEnter", function() Tooltip(button, frame.rule, key) end)
            button:HookScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
            frame.rows[key] = button
        end
    end
    function frame:RefreshSummary()
        for key, button in pairs(self.rows) do button.text:SetText(BranchSummary(self.rule[key], false)) end
        local a, b = self.rule.inCombat, self.rule.outOfCombat
        local text = SameEffective(a, b) and (T("summary_prefix") .. BranchSummary(a, false))
            or (T("short.inCombat") .. ": " .. BranchSummary(a, false, true) .. " | " .. T("short.outOfCombat") .. ": " .. BranchSummary(b, false, true))
        self.gui2FullText = text
        if self.button then self.button.text:SetText(text) end
        return text
    end
    function frame:GetValue() return V:NormalizeBranches(self.rule) end
    function frame:SetValue(rule, silent)
        self.rule = Normalize(rule)
        self:RefreshSummary()
        if overlay and overlay.owner == self then overlay:Refresh() end
        if not silent and self.setter then self.setter(self:GetValue(), "rule", self) end
    end
    function frame:ClosePanel()
        if overlay and overlay.owner == self then
            overlay.main:Hide(); overlay.detail:Hide(); overlay.blocker:Hide(); overlay.owner = nil; overlay.detailAnchor = nil
        end
        if GUI2.VisibilityRuleOpenEditor == self then GUI2.VisibilityRuleOpenEditor = nil end
    end
    function frame:IsPanelOpen() return overlay and overlay.owner == self or false end
    function frame:OpenPanel() Open(self.button or self.rows.inCombat, not compact and "inCombat" or nil) end
    function frame:SetContext(context)
        if self.gui2Context ~= context then self:ClosePanel(); self.gui2Context = context end
    end
    function frame:GetContext() return self.gui2Context end
    function frame:RefreshCapabilities() if overlay and overlay.owner == self then overlay:Refresh() end end
    function frame:SetDisabled(disabled)
        self.gui2Disabled = disabled == true
        if self.gui2Disabled then self:ClosePanel() end
        if self.button then self.button:SetEnabled(not self.gui2Disabled) end
        for _, button in pairs(self.rows) do button:SetEnabled(not self.gui2Disabled) end
    end
    frame:SetScript("OnHide", function() frame:ClosePanel(); editors[frame] = nil end)
    frame:SetScript("OnShow", function()
        editors[frame] = true
        if frame.getter then frame:SetValue(frame.getter(), true) end
    end)
    frame:RefreshSummary()
    frame:SetDisabled(opts.disabled)
    return frame
end
