do
    local addonName = ...
    local state = _G.YUI_CORE_EMBED_STATE and _G.YUI_CORE_EMBED_STATE[addonName]
    if state and not state.loadCore then
        return
    end
end
local YUI = _G.YUI
local GUI2 = YUI and YUI.GUI2
if not (GUI2 and GUI2.Form) then return end

local ROW_COUNT = 8
local sharedSelector
local SOURCE_ORDER = { "native", "lsm", "custom", "voice", "system", "tts" }
local EVENTS = {
    "YUI_NOTIFICATION_SOUND_CAPABILITIES_CHANGED",
    "YUI_SOUND_PACKS_CHANGED",
    "YUI_SOUND_PREFERENCES_CHANGED",
}

local function T(key)
    local locale = YUI.Locale and YUI.Locale:Get("Core")
    return locale and locale[key] or key
end

local function SourceLabel(kind)
    return T("notification.sound." .. (kind or "native"))
end

local function Equal(left, right)
    return left and right and left.kind == right.kind and left.value == right.value
end

local function Visible(frame)
    return frame:IsShown() and (not frame.IsVisible or frame:IsVisible())
end

local function Cancel(owner)
    local service = YUI.NotificationSound
    if service and service.CancelOwner then service:CancelOwner(owner) end
end

local function Normalize(selection)
    local service = YUI.NotificationSound
    if service and service.NormalizeSelection then return service:NormalizeSelection(selection) end
    return nil, "service-unavailable"
end

local function Capabilities()
    local service = YUI.NotificationSound
    return service and service:GetCapabilities() or {
        ready = false, sources = { native = true, lsm = true, custom = true },
    }
end

local function SelectionState(selection, options)
    local service = YUI.NotificationSound
    local state = service and service:GetSelectionState(selection, options) or {
        selection = selection, effective = { kind = "native" },
        backend = "local", reason = "service-unavailable", available = false,
    }
    if service and state.effective and state.effective.kind == "native"
        and state.selection and state.selection.kind ~= "native" and state.available == false then
        -- effective describes the fallback selection; confirm that the native
        -- fallback itself exists before promising it in the user-facing status.
        state.nativeAvailable = service:GetSelectionState({ kind = "native" }, options).available
    end
    return state
end

local function Choices(source, query, current, options)
    local service = YUI.NotificationSound
    return service and service:GetChoices(source, query, current, options) or {}
end

local function Label(selection, state, options)
    if not selection or selection.kind == "native" then return SourceLabel("native") end
    local label = state and state.label
    if not label then
        for _, choice in ipairs(Choices(selection.kind, "", selection, options)) do
            if Equal(choice, selection) then label = choice.label; break end
        end
    end
    return SourceLabel(selection.kind) .. " · " .. (label or selection.value or "")
end

local function Status(state)
    if state.reason == "module-disabled" then return T("notification.sound.module_disabled") end
    if state.muted then return T("notification.sound.muted") end
    if state.nativeAvailable == false then return T("notification.sound.unavailable") end
    if not Equal(state.selection, state.effective) then return T("notification.sound.fallback") end
    if state.available == false then return T("notification.sound.unavailable") end
    return ""
end

-- This selector has its own preview owner; closing it cannot stop a business alert
-- or the preview belonging to another notification control.
local function CreateSelector()
    local dialog = GUI2:CreatePanel(UIParent, {
        width = 460, height = 494, surface = "color.surface.popup",
        border = "color.popup.border", shadow = true, shadowKey = "shadow.popup.size",
    })
    dialog:Hide()
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetFrameLevel(760)
    dialog:EnableMouse(true)
    dialog.previewOwner = {}
    dialog.rows, dialog.drafts, dialog.choices = {}, {}, {}
    dialog.offset, dialog.query = 0, ""

    local title = GUI2:CreateText(dialog, T("notification.sound.title"), "font.size.lg", "color.text.heading", "LEFT")
    title:SetPoint("TOPLEFT", 18, -16)
    dialog.close = GUI2:CreateCloseButton(dialog, function() dialog:Hide() end)
    dialog.close:SetPoint("TOPRIGHT", -14, -14)

    local function Active()
        local control = dialog.control
        return control and Visible(dialog) and Visible(control) and not control.gui2Disabled
    end
    local function Preview(selection)
        if not Active() then return end
        selection = Normalize({ kind = selection.kind, value = selection.value })
        if not selection then return end
        local service = YUI.NotificationSound
        local played = service and service:Preview(dialog.previewOwner, selection, dialog.control.playbackOptions)
        dialog.previewFailed = played ~= true
        dialog:RefreshStatus()
    end
    local function Select(selection)
        if not Active() then return end
        selection = Normalize({ kind = selection.kind, value = selection.value })
        if not selection then return end
        local control = dialog.control
        -- Hide before committing: a setter may rebuild its settings page.
        dialog:Hide()
        control:SetValue(selection)
    end

    dialog.sourceDropdown = GUI2.Form:CreateDropdown(dialog, {
        width = 424, height = 28, default = "native",
        options = function() return dialog.sourceOptions end,
        getLabel = SourceLabel,
        set = function(source)
            if not Active() then return end
            Cancel(dialog.previewOwner)
            dialog.source, dialog.offset, dialog.query = source, 0, ""
            dialog.previewFailed = nil
            dialog.search:SetValue("", true)
            dialog:Refresh()
        end,
    })
    dialog.sourceDropdown:SetPoint("TOPLEFT", 18, -52)
    dialog.search = GUI2.Form:CreateEditBox(dialog, {
        width = 424, height = 28, text = "",
        placeholder = T("sound.center.search"), searchPlaceholder = true,
        onChange = function(_, query)
            if not Active() then return end
            dialog.query, dialog.offset = query or "", 0
            dialog:Refresh()
        end,
    })
    dialog.search:SetPoint("TOPLEFT", 18, -90)
    dialog.search:SetScript("OnEscapePressed", function() dialog:Hide() end)

    dialog.list = GUI2:CreatePanel(dialog, {
        width = 424, height = 280, surface = "color.surface.panel", border = "color.border.default",
    })
    dialog.list:SetPoint("TOPLEFT", 18, -126)
    local function Wheel(_, delta)
        dialog.offset = math.max(0, math.min(math.max(0, #dialog.choices - ROW_COUNT), dialog.offset - delta * 3))
        dialog:RefreshRows()
    end
    dialog.list:EnableMouseWheel(true)
    dialog.list:SetScript("OnMouseWheel", Wheel)
    dialog.empty = GUI2:CreateText(dialog.list, T("notification.sound.empty"), "font.size.md", "color.text.secondary", "CENTER")
    dialog.empty:SetPoint("CENTER")
    dialog.empty:SetWidth(400)
    for index = 1, ROW_COUNT do
        local row = GUI2.Form:CreateButton(dialog.list, {
            text = "", width = 342, height = 28, tone = "default", contentAlign = "left", justifyH = "LEFT",
        })
        row:SetPoint("TOPLEFT", 8, -8 - (index - 1) * 33)
        row:SetScript("OnClick", function()
            if row.choice and not row.gui2Disabled then Select(row.choice) end
        end)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", Wheel)
        row.preview = GUI2.Form:CreateButton(dialog.list, {
            text = T("common.preview_sound"), width = 58, height = 28, tone = "default",
            onClick = function()
                if row.choice and not row.preview.gui2Disabled then Preview(row.choice) end
            end,
        })
        row.preview:SetPoint("LEFT", row, "RIGHT", 8, 0)
        dialog.rows[index] = row
    end
    dialog.count = GUI2:CreateText(dialog, "", "font.size.sm", "color.text.secondary", "LEFT")
    dialog.count:SetPoint("BOTTOMLEFT", 18, 14)
    dialog.status = GUI2:CreateText(dialog, "", "font.size.sm", "color.text.secondary", "LEFT")
    dialog.status:SetPoint("TOPLEFT", 18, -416)
    dialog.status:SetSize(424, 44)
    dialog.status:SetWordWrap(true)

    dialog.inputPanel = GUI2:CreatePanel(dialog, {
        width = 424, height = 280, surface = "color.surface.panel", border = "color.border.default",
    })
    dialog.inputPanel:SetPoint("TOPLEFT", 18, -126)
    dialog.inputHelp = GUI2:CreateText(dialog.inputPanel, "", "font.size.sm", "color.text.secondary", "LEFT")
    dialog.inputHelp:SetPoint("TOPLEFT", 12, -14)
    dialog.inputHelp:SetSize(400, 44)
    dialog.inputHelp:SetWordWrap(true)
    dialog.input = GUI2.Form:CreateEditBox(dialog.inputPanel, {
        width = 400, height = 30, text = "",
        onChange = function(_, value)
            if not Active() then return end
            Cancel(dialog.previewOwner)
            dialog.drafts[dialog.source] = value or ""
            dialog.previewFailed = nil
            dialog:RefreshInput()
            dialog:RefreshStatus()
        end,
    })
    dialog.input:SetPoint("TOPLEFT", 12, -68)
    dialog.input:SetScript("OnEscapePressed", function() dialog:Hide() end)
    dialog.inputStatus = GUI2:CreateText(dialog.inputPanel, "", "font.size.sm", "color.state.error", "LEFT")
    dialog.inputStatus:SetPoint("TOPLEFT", 12, -110)
    dialog.inputStatus:SetSize(400, 44)
    dialog.inputStatus:SetWordWrap(true)
    dialog.inputPreview = GUI2.Form:CreateButton(dialog.inputPanel, {
        text = T("common.preview_sound"), width = 90, height = 28, tone = "default",
        onClick = function()
            if not dialog.inputPreview.gui2Disabled then Preview(dialog.inputSelection) end
        end,
    })
    dialog.inputPreview:SetPoint("TOPLEFT", 12, -166)
    dialog.inputConfirm = GUI2.Form:CreateButton(dialog.inputPanel, {
        text = T("notification.sound.confirm"), width = 100, height = 28,
        onClick = function()
            if not dialog.inputConfirm.gui2Disabled then Select(dialog.inputSelection) end
        end,
    })
    dialog.inputConfirm:SetPoint("LEFT", dialog.inputPreview, "RIGHT", 8, 0)

    function dialog:RefreshStatus()
        local state = self.control and self.control.selectionState
        self.status:SetText(self.previewFailed and T("notification.sound.preview_failed") or (state and Status(state) or ""))
    end
    function dialog:RefreshInput()
        local enabled = self.capabilities.sources[self.source] == true
        self.inputSelection = enabled and Normalize({ kind = self.source, value = self.drafts[self.source] or "" }) or nil
        self.input:SetDisabled(not enabled)
        self.inputPreview:SetDisabled(self.inputSelection == nil or self.control.selectionState.reason == "module-disabled")
        self.inputConfirm:SetDisabled(self.inputSelection == nil)
        local text = self.drafts[self.source] or ""
        self.inputStatus:SetText(not enabled and T("notification.sound.fallback")
            or (text ~= "" and not self.inputSelection and T("notification.sound.invalid") or ""))
    end
    function dialog:RefreshRows()
        local control = self.control
        local total = #self.choices
        self.offset = math.min(self.offset, math.max(0, total - ROW_COUNT))
        for index, row in ipairs(self.rows) do
            local choice = self.choices[self.offset + index]
            row.choice = choice
            row:SetShown(choice ~= nil)
            row.preview:SetShown(choice ~= nil)
            if choice then
                row:SetText((choice.label or choice.value or SourceLabel(choice.kind))
                    .. (choice.available == false and T("notification.sound.saved_unavailable") or ""))
                row:SetSelected(Equal(choice, control.value))
                row:SetDisabled(choice.available == false)
                row.preview:SetDisabled(choice.available == false or control.selectionState.reason == "module-disabled")
            end
        end
        self.empty:SetShown(total == 0)
        self.count:SetText(string.format(T("sound.picker.count"), total > 0 and self.offset + 1 or 0, math.min(total, self.offset + ROW_COUNT), total))
    end
    function dialog:Refresh()
        local control = self.control
        if not control then return end
        local playbackOptions = control.playbackOptions
        self.capabilities = Capabilities()
        self.sourceOptions = {}
        local allowed = {}
        for _, source in ipairs(SOURCE_ORDER) do
            local enabled = self.capabilities.sources[source] == true
            local retained = control.value and control.value.kind == source
            if enabled or retained then
                allowed[source] = true
                self.sourceOptions[#self.sourceOptions + 1] = {
                    value = source, text = SourceLabel(source) .. (not enabled and T("notification.sound.saved_unavailable") or ""),
                }
            end
        end
        if not allowed[self.source] then self.source, self.offset = "native", 0 end
        self.sourceDropdown:SetValue(self.source, true)
        self.sourceDropdown:RefreshOptions()
        local inputMode = self.source == "custom" or self.source == "tts"
        self.inputPanel:SetShown(inputMode)
        self.search:SetShown(not inputMode)
        self.list:SetShown(not inputMode)
        self.count:SetShown(not inputMode)
        if inputMode then
            self.inputHelp:SetText(T(self.source == "tts" and "sound.center.helpTTS" or "sound.picker.custom.help"))
            self.input:SetMaxLetters(self.source == "tts" and 2048 or 153)
            self.input:SetValue(self.drafts[self.source] or "", true)
            self:RefreshInput()
        else
            self.choices = Choices(self.source, self.query, control.value, playbackOptions)
            -- The service intentionally does not add the original selection.
            -- Only this control's unavailable original is retained, without
            -- advertising other resources from an absent provider.
            local current = control.value
            if current and current.kind == self.source and control.selectionState.available == false then
                local found = false
                for _, choice in ipairs(self.choices) do if Equal(choice, current) then found = true; break end end
                if not found then
                    self.choices[#self.choices + 1] = {
                        kind = current.kind, value = current.value,
                        label = current.value or SourceLabel(current.kind), available = false,
                    }
                end
            end
            self:RefreshRows()
        end
        self:RefreshStatus()
    end
    function dialog:Open(control)
        self:Hide()
        self.control = control
        self.source = control.value and control.value.kind or "native"
        self.query, self.offset, self.previewFailed = "", 0, nil
        self.drafts = {}
        if control.value then self.drafts[control.value.kind] = control.value.value end
        self.search:SetValue("", true)
        if YUI.Settings and YUI.Settings.SyncOwnedWindowScale then YUI.Settings:SyncOwnedWindowScale(self, control) end
        self:Refresh()
        self:Show()
        GUI2:ShowModalScrim(self)
    end
    GUI2:EnableEscapeClose(dialog, function() dialog:Hide() end)
    dialog:HookScript("OnHide", function(self)
        Cancel(self.previewOwner)
        self.search:ClearFocus()
        self.input:ClearFocus()
        self.choices, self.drafts = {}, {}
        self.capabilities, self.sourceOptions = nil, {}
        self.query, self.offset = "", 0
        self.control, self.inputSelection, self.previewFailed = nil, nil, nil
        self.input:SetValue("", true)
        self.search:SetValue("", true)
        for _, row in ipairs(self.rows) do row.choice = nil end
        if GUI2.DropdownFrame and GUI2.DropdownFrame.anchor == self.sourceDropdown then GUI2:CloseDropdown(false) end
    end)
    return dialog
end

function GUI2.Form:CreateNotificationSound(parent, opts)
    opts = opts or {}
    local height = opts.height or GUI2:GetMetric("layout.height.control", 26)
    local width = opts.width or GUI2:GetMetric("layout.form.width.wide", 220)
    local gap, previewWidth = 8, 58
    local frame = GUI2:CreateFrame(parent, { width = width, height = height })
    frame.width, frame.height, frame.gui2TopRowHeight = width, height, height
    frame.previewOwner = {}
    local playbackOptions = { nativeSound = opts.nativeSound, defaultChannel = opts.defaultChannel or "Master" }
    frame.playbackOptions = playbackOptions

    local selectorOptions = {
        text = "", width = math.max(1, width - previewWidth - gap), height = height,
        tone = "default", contentAlign = "left", justifyH = "LEFT", tooltip = opts.tooltip,
        onClick = function() frame:OpenSelector() end,
    }
    -- Form's tooltip binding reads this table when hovered, including a label
    -- refreshed after a provider or profile change.
    selectorOptions.tooltip = opts.tooltip or ""
    frame.selector = GUI2.Form:CreateButton(frame, selectorOptions)
    frame.selector:SetPoint("TOPLEFT", 0, 0)
    frame.previewButton = GUI2.Form:CreateButton(frame, {
        text = T("common.preview_sound"), width = previewWidth, height = height, tone = "default",
        onClick = function() return frame:Preview() end,
    })
    frame.previewButton:SetPoint("LEFT", frame.selector, "RIGHT", gap, 0)
    frame.status = GUI2:CreateText(frame, "", "font.size.sm", "color.text.secondary", "LEFT")
    frame.status:SetPoint("TOPLEFT", frame.selector, "BOTTOMLEFT", 0, -4)
    frame.status:SetWidth(width)
    frame.status:SetWordWrap(true)
    if frame.status.SetNonSpaceWrap then frame.status:SetNonSpaceWrap(true) end

    function frame:SetStatus(text)
        self.statusText = text or ""
        self.status:SetText(self.statusText)
        self.status:SetShown(self.statusText ~= "")
        self.status:SetHeight(0)
        local statusHeight = self.statusText ~= "" and math.max(
            GUI2:GetMetric("font.size.sm", 12), self.status:GetStringHeight() or 0) or 0
        self.status:SetHeight(math.max(1, statusHeight))
        local previous = self.height
        self.height = height + (statusHeight > 0 and statusHeight + 4 or 0)
        if previous ~= self.height then
            self:SetHeight(self.height)
            if opts.onHeightChanged then opts.onHeightChanged(self, self.height, previous) end
        end
    end

    function frame:FitLabel()
        local label = (self.fullLabel or ""):gsub("[\r\n]", " ")
        self.selector:SetText(label)
        local region = self.selector.text
        local available = math.max(1, self.selector:GetWidth() - 16)
        if region:GetStringWidth() > available then
            -- Search byte offsets, then back up to a UTF-8 boundary. This keeps
            -- long paths and Chinese titles bounded without splitting a glyph.
            local low, high, best = 0, #label, ""
            while low <= high do
                local middle = math.floor((low + high) / 2)
                local cut = middle
                while cut > 0 and label:byte(cut + 1) and label:byte(cut + 1) >= 128
                    and label:byte(cut + 1) < 192 do cut = cut - 1 end
                local prefix = label:sub(1, cut)
                self.selector:SetText(prefix .. "…")
                if region:GetStringWidth() <= available then
                    best, low = prefix, middle + 1
                else high = middle - 1 end
            end
            self.selector:SetText(best .. "…")
        end
        selectorOptions.tooltip = (self.fullLabel or "") .. (opts.tooltip and opts.tooltip ~= "" and ("\n" .. opts.tooltip) or "")
    end

    function frame:Layout(newWidth)
        self.width = math.max(1, newWidth or self:GetWidth())
        self.selector:SetWidth(math.max(1, self.width - previewWidth - gap))
        self.status:SetWidth(self.width)
        self:FitLabel()
        self:SetStatus(self.statusText)
    end

    function frame:Preview()
        if self.gui2Disabled then return false, "disabled" end
        if self.previewButton.gui2Disabled then return false, self.selectionState.reason end
        if not Visible(self) then return false, "hidden" end
        local service = YUI.NotificationSound
        local played, reason
        if service then played, reason = service:Preview(self.previewOwner, self.value, playbackOptions)
        else played, reason = false, "service-unavailable" end
        self:SetStatus(played == true and Status(self.selectionState) or T("notification.sound.preview_failed"))
        return played, reason
    end
    function frame:CloseSelector()
        if self.dialog and self.dialog.control == self then self.dialog:Hide() end
    end
    function frame:Deactivate()
        self:CloseSelector()
        Cancel(self.previewOwner)
        if YUI.Event then YUI.Event:OffOwner(self) end
        self.listening = nil
    end
    function frame:Activate()
        if self.gui2Disabled or not Visible(self) or self.listening then return end
        if YUI.Event and YUI.Event.On then
            for _, event in ipairs(EVENTS) do YUI.Event:On(event, "OnNotificationSoundChanged", self) end
            self.listening = true
        end
    end
    function frame:Paint()
        self.selectionState = SelectionState(self.value, playbackOptions)
        self.fullLabel = Label(self.value, self.selectionState, playbackOptions)
        self:FitLabel()
        self:SetStatus(Status(self.selectionState))
        self.previewButton:SetDisabled(self.gui2Disabled or self.selectionState.reason == "module-disabled")
        if self.dialog and self.dialog.control == self and self.dialog:IsShown() then self.dialog:Refresh() end
    end
    function frame:GetValue()
        return Normalize(self.value)
    end
    function frame:SetValue(value, silent)
        local normalized, reason = Normalize(value)
        if not normalized then return false, reason end
        local changed = not Equal(self.value, normalized)
        if changed then
            Cancel(self.previewOwner)
            self:CloseSelector()
        end
        self.value = normalized
        if changed and silent ~= true then
            opts.value = normalized
            if opts.set then opts.set(Normalize(normalized)) end
            if opts.onChange then opts.onChange(self, Normalize(normalized)) end
        end
        self:Paint()
        return changed
    end
    function frame:SetDisabled(disabled)
        self.gui2Disabled = disabled == true
        self.selector:SetDisabled(self.gui2Disabled)
        if self.gui2Disabled then self:Deactivate() else self:Activate() end
        self.previewButton:SetDisabled(self.gui2Disabled or (self.selectionState and self.selectionState.reason == "module-disabled"))
        GUI2:SetTextColorKey(self.status, self.gui2Disabled and "color.text.disabled" or "color.text.secondary")
    end
    function frame:Refresh()
        local value
        if opts.get then value = opts.get() else value = opts.value end
        if value == nil then value = opts.default or { kind = "native" } end
        -- Invalid saved data follows playback's native fallback without writing
        -- it back; valid choices from an absent provider remain unchanged.
        value = Normalize(value) or Normalize(opts.default) or { kind = "native" }
        self:SetValue(value, true)
        if type(opts.disabled) == "function" then self:SetDisabled(opts.disabled() == true) end
        self:Activate()
    end
    function frame:OnNotificationSoundChanged()
        Cancel(self.previewOwner)
        if self.dialog and self.dialog.control == self then Cancel(self.dialog.previewOwner) end
        self:Refresh()
    end
    function frame:OpenSelector()
        if self.gui2Disabled or not Visible(self) then return nil end
        self:Refresh()
        if self.gui2Disabled then return nil end
        if not sharedSelector then sharedSelector = CreateSelector() end
        self.dialog = sharedSelector
        self.dialog:Open(self)
        return self.dialog
    end
    function frame:RefreshTheme()
        self.selector:RefreshTheme()
        self.previewButton:RefreshTheme()
        GUI2:SetTextColorKey(self.status, self.gui2Disabled and "color.text.disabled" or "color.text.secondary")
        self:Layout()
    end
    frame:HookScript("OnSizeChanged", function(self, newWidth)
        if newWidth ~= self.width then self:Layout(newWidth) end
    end)
    frame:HookScript("OnHide", function(self) self:Deactivate() end)
    frame:HookScript("OnShow", function(self) self:Refresh() end)
    frame:Refresh()
    frame:SetDisabled(type(opts.disabled) == "function" and opts.disabled() or opts.disabled)
    GUI2:RegisterThemeObject(frame)
    -- Form's opt-in retained contract is shared; only this top-level control
    -- owns the get/set binding, never its popup or internal controls.
    if type(opts.get) == "function" then
        local owner = parent
        for _ = 1, 16 do
            if not owner then break end
            if owner.yuiRetainedBindings then
                owner.yuiRetainedBindings[#owner.yuiRetainedBindings + 1] = { widget = frame, opts = opts }
                break
            end
            owner = owner.GetParent and owner:GetParent() or nil
        end
    end
    return frame
end
