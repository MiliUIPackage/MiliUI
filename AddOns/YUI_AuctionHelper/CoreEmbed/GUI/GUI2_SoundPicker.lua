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

local Picker = GUI2.SoundPicker or {}
GUI2.SoundPicker = Picker

local ROW_COUNT = 9
local CUSTOM_PREFIX = "custom:"
local MAX_CUSTOM_PATH_LENGTH = 153
local SOURCE_TEXT = {
    all = { "sound.picker.source.all", "全部" },
    voice = { "sound.picker.source.voice", "语音包" },
    custom = { "sound.picker.source.custom", "自定义路径" },
    lsm = { "sound.picker.source.lsm", "SharedMedia" },
}

local function T(key, fallback)
    local locale = YUI.Locale and YUI.Locale:Get("Core") or nil
    return locale and locale[key] or fallback or key
end

local function SourceText(source)
    local definition = SOURCE_TEXT[source]
    return definition and T(definition[1], definition[2]) or tostring(source)
end

local function DisplayText(choice)
    if not choice then return T("sound.picker.none", "无") end
    local text = tostring(choice.text or "")
    if choice.available == false then
        text = text .. T("sound.picker.unavailable", "（不可用）")
    end
    return text
end

local function NormalizeCustomReference(path)
    local service = YUI.Sound
    if not (service and service.NormalizeReference) then return nil end
    return service:NormalizeReference(CUSTOM_PREFIX .. tostring(path or ""))
end

local function CustomPathFromReference(reference)
    local normalized = NormalizeCustomReference(
        type(reference) == "string"
            and string.sub(reference, 1, #CUSTOM_PREFIX) == CUSTOM_PREFIX
            and string.sub(reference, #CUSTOM_PREFIX + 1) or ""
    )
    return normalized and string.sub(normalized, #CUSTOM_PREFIX + 1) or ""
end

local function CreateDialog()
    local dialog = GUI2:CreatePanel(UIParent, {
        width = 460,
        height = 486,
        surface = "color.surface.popup",
        border = "color.popup.border",
        shadow = true,
        shadowKey = "shadow.popup.size",
        hidden = true,
    })
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    dialog:SetFrameStrata("FULLSCREEN_DIALOG")
    dialog:SetFrameLevel(760)
    if dialog.SetToplevel then dialog:SetToplevel(true) end
    dialog:EnableMouse(true)

    dialog.title = GUI2:CreateText(
        dialog,
        T("sound.picker.title", "选择声音"),
        "font.size.lg",
        "color.text.heading",
        "LEFT"
    )
    dialog.title:SetPoint("TOPLEFT", 18, -16)

    dialog.close = GUI2:CreateCloseButton(dialog, function() dialog:Hide() end)
    dialog.close:SetPoint("TOPRIGHT", -14, -14)

    dialog.source = "all"
    dialog.offset = 0
    dialog.sourceButtons = {}
    local function CloseFromEditBox(editBox)
        if editBox and editBox.ClearFocus then editBox:ClearFocus() end
        dialog:Hide()
    end
    local previous
    for _, source in ipairs({ "all", "voice", "custom", "lsm" }) do
        local sourceKey = source
        local button = GUI2.Form:CreateButton(dialog, {
            text = SourceText(sourceKey),
            width = sourceKey == "lsm" and 112
                or sourceKey == "custom" and 108 or 76,
            height = 26,
            onClick = function()
                dialog.source = sourceKey
                dialog.offset = 0
                dialog:Refresh()
                local input = sourceKey == "custom"
                    and dialog.customInput or dialog.search
                if input and input.SetFocus then input:SetFocus() end
            end,
        })
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 6, 0)
        else
            button:SetPoint("TOPLEFT", 18, -52)
        end
        dialog.sourceButtons[sourceKey] = button
        previous = button
    end

    dialog.search = GUI2.Form:CreateEditBox(dialog, {
        placeholder = T("sound.center.search", "搜索"), searchPlaceholder = true,
        width = 424,
        height = 28,
        text = "",
        onChange = function(_, value)
            dialog.query = value or ""
            dialog.offset = 0
            dialog:Refresh()
        end,
    })
    dialog.search:SetPoint("TOPLEFT", 18, -88)
    dialog.search:SetScript("OnEscapePressed", CloseFromEditBox)

    dialog.list = GUI2:CreatePanel(dialog, {
        width = 424,
        height = 306,
        surface = "color.surface.panel",
        border = "color.border.default",
    })
    dialog.list:SetPoint("TOPLEFT", 18, -126)
    dialog.list:EnableMouseWheel(true)
    dialog.list:SetScript("OnMouseWheel", function(_, delta)
        local maximum = math.max(0, #dialog.choices - ROW_COUNT)
        dialog.offset = math.max(0, math.min(maximum, dialog.offset - delta * 3))
        dialog:RefreshRows()
    end)

    dialog.customPanel = GUI2:CreatePanel(dialog, {
        width = 424,
        height = 306,
        surface = "color.surface.panel",
        border = "color.border.default",
    })
    dialog.customPanel:SetPoint("TOPLEFT", 18, -126)
    dialog.customPanel:Hide()

    dialog.customHelp = GUI2:CreateText(
        dialog.customPanel,
        T(
            "sound.picker.custom.help",
            "输入游戏可访问的音频路径，例如 Interface\\AddOns\\MyAddon\\sound.ogg"
        ),
        "font.size.sm",
        "color.text.secondary",
        "LEFT"
    )
    dialog.customHelp:SetPoint("TOPLEFT", 12, -14)
    dialog.customHelp:SetWidth(400)

    dialog.customPath = ""
    dialog.customInput = GUI2.Form:CreateEditBox(dialog.customPanel, {
        width = 400,
        height = 30,
        text = "",
        onChange = function(_, value)
            dialog.customPath = value or ""
            dialog.customPreviewFailed = nil
            dialog:RefreshCustom()
        end,
    })
    dialog.customInput:SetPoint("TOPLEFT", 12, -52)
    dialog.customInput:SetMaxLetters(MAX_CUSTOM_PATH_LENGTH)
    dialog.customInput:SetScript("OnEscapePressed", CloseFromEditBox)

    dialog.customStatus = GUI2:CreateText(
        dialog.customPanel,
        "",
        "font.size.sm",
        "color.state.error",
        "LEFT"
    )
    dialog.customStatus:SetPoint("TOPLEFT", 12, -92)
    dialog.customStatus:SetWidth(400)

    dialog.customPreview = GUI2.Form:CreateButton(dialog.customPanel, {
        text = T("sound.settings.preview", "试听"),
        width = 90,
        height = 28,
        onClick = function()
            local reference = NormalizeCustomReference(dialog.customPath)
            local service = YUI.Sound
            if not (reference and service and service.Play) then return end
            local played = service:Play(reference, nil, 0)
            dialog.customPreviewFailed = played ~= true
            dialog:RefreshCustom()
        end,
    })
    dialog.customPreview:SetPoint("TOPLEFT", 12, -124)

    dialog.customConfirm = GUI2.Form:CreateButton(dialog.customPanel, {
        text = T("sound.picker.custom.confirm", "确认选择"),
        width = 100,
        height = 28,
        onClick = function()
            local reference = NormalizeCustomReference(dialog.customPath)
            if not reference then return end
            local options = dialog.options
            if options and options.onSelect then
                options.onSelect(reference, {
                    value = reference,
                    text = CustomPathFromReference(reference),
                    source = "custom",
                    available = true,
                })
            end
            dialog:Hide()
        end,
    })
    dialog.customConfirm:SetPoint("LEFT", dialog.customPreview, "RIGHT", 8, 0)
    dialog.customPreview:SetDisabled(true, true)
    dialog.customConfirm:SetDisabled(true, true)

    dialog.rows = {}
    for index = 1, ROW_COUNT do
        local rowIndex = index
        local row = GUI2.Form:CreateButton(dialog.list, {
            text = "",
            width = 346,
            height = 28,
            contentAlign = "left",
            justifyH = "LEFT",
            onClick = function()
                local choice = dialog.rows[rowIndex].choice
                if not (choice and choice.available ~= false) then return end
                local options = dialog.options
                if options and options.onSelect then
                    options.onSelect(choice.value, choice)
                end
                dialog:Hide()
            end,
        })
        row:SetPoint("TOPLEFT", 8, -8 - (index - 1) * 33)
        row:EnableMouseWheel(true)
        row:SetScript("OnMouseWheel", function(_, delta)
            local maximum = math.max(0, #dialog.choices - ROW_COUNT)
            dialog.offset = math.max(0, math.min(maximum, dialog.offset - delta * 3))
            dialog:RefreshRows()
        end)
        row.preview = GUI2.Form:CreateButton(dialog.list, {
            text = T("sound.settings.preview", "试听"),
            width = 54,
            height = 28,
            onClick = function()
                local choice = dialog.rows[rowIndex].choice
                if choice and choice.available ~= false and YUI.Sound then
                    YUI.Sound:Play(choice.value, nil, 0)
                end
            end,
        })
        row.preview:SetPoint("LEFT", row, "RIGHT", 8, 0)
        dialog.rows[rowIndex] = row
    end

    dialog.count = GUI2:CreateText(
        dialog,
        "0",
        "font.size.sm",
        "color.text.secondary",
        "LEFT"
    )
    dialog.count:SetPoint("BOTTOMLEFT", 18, 18)

    dialog.none = GUI2.Form:CreateButton(dialog, {
        text = T("sound.picker.clear", "清除选择"),
        width = 90,
        height = 26,
        onClick = function()
            local options = dialog.options
            if options and options.onSelect then options.onSelect(nil, nil) end
            dialog:Hide()
        end,
    })
    dialog.none:SetPoint("BOTTOMRIGHT", -18, 12)

    function dialog:RefreshRows()
        local total = #self.choices
        local maximum = math.max(0, total - ROW_COUNT)
        self.offset = math.max(0, math.min(maximum, self.offset or 0))
        for index = 1, ROW_COUNT do
            local row = self.rows[index]
            local choice = self.choices[self.offset + index]
            row.choice = choice
            if choice then
                row:SetText(DisplayText(choice))
                row:SetDisabled(choice.available == false, true)
                row.preview:SetDisabled(choice.available == false, true)
                row:Show()
                row.preview:Show()
            else
                row.choice = nil
                row:Hide()
                row.preview:Hide()
            end
        end
        local first = total > 0 and self.offset + 1 or 0
        local last = math.min(total, self.offset + ROW_COUNT)
        self.count:SetText(string.format(
            T("sound.picker.count", "%d–%d / %d"),
            first,
            last,
            total
        ))
    end

    function dialog:RefreshCustom()
        local reference = NormalizeCustomReference(self.customPath)
        self.customPreview:SetDisabled(reference == nil, true)
        self.customConfirm:SetDisabled(reference == nil, true)

        local hasText = string.find(tostring(self.customPath or ""), "%S") ~= nil
        local message = ""
        if hasText and not reference then
            message = T("sound.picker.custom.invalid", "请输入游戏内可访问的相对路径。")
        elseif self.customPreviewFailed then
            message = T(
                "sound.settings.preview_failed",
                "无法播放所选声音。"
            )
        end
        self.customStatus:SetText(message)
    end

    function dialog:Refresh()
        for source, button in pairs(self.sourceButtons) do
            button:SetSelected(source == self.source)
        end
        if self.options and self.options.allowNone == true then
            self.none:Show()
        else
            self.none:Hide()
        end

        if self.source == "custom" then
            self.search:Hide()
            self.list:Hide()
            self.count:Hide()
            self.customPanel:Show()
            self.choices = {}
            self:RefreshCustom()
            return
        end

        self.customPanel:Hide()
        self.search:Show()
        self.list:Show()
        self.count:Show()
        local service = YUI.Sound
        local choices = service and service.GetSoundChoices
            and service:GetSoundChoices({
                source = self.source,
                query = self.query,
                current = self.options and self.options.value,
            }) or {}
        self.choices = {}
        for index = 1, #choices do
            local choice = choices[index]
            if choice.source ~= "system" and choice.source ~= "custom" then
                self.choices[#self.choices + 1] = choice
            end
        end
        self:RefreshRows()
    end

    GUI2:EnableEscapeClose(dialog, function(self) self:Hide() end)
    dialog:HookScript("OnHide", function(self)
        self.options = nil
        self.query = ""
        self.offset = 0
        self.customPath = ""
        self.customPreviewFailed = nil
        if self.search then self.search:SetValue("", true) end
        if self.customInput then
            self.customInput:SetValue("", true)
            if self.customInput.ClearFocus then self.customInput:ClearFocus() end
        end
        if self.search and self.search.ClearFocus then self.search:ClearFocus() end
        if self.customStatus then self.customStatus:SetText("") end
    end)
    dialog:HookScript("OnShow", function(self)
        if self.options then self:Refresh() end
    end)
    -- CreatePanel 当前不处理 hidden 选项；显式隐藏，保证首次 Open 也走 OnShow 初始化。
    dialog:Hide()
    return dialog
end

function Picker:Open(options)
    if not self.dialog then self.dialog = CreateDialog() end
    local dialog = self.dialog
    dialog.options = type(options) == "table" and options or {}
    local requestedSource = dialog.options.source
    dialog.source = SOURCE_TEXT[requestedSource] and requestedSource or "all"
    dialog.query = ""
    dialog.offset = 0
    dialog.customPath = CustomPathFromReference(dialog.options.value)
    dialog.customPreviewFailed = nil
    dialog.search:SetValue("", true)
    dialog.customInput:SetValue(dialog.customPath, true)
    dialog.customStatus:SetText("")
    GUI2:ShowModalScrim(dialog)
    dialog:Show()
    if dialog.Raise then dialog:Raise() end
    if dialog.search.SetFocus then dialog.search:SetFocus() end
    return dialog
end

function Picker:Close()
    local dialog = self.dialog
    if not (dialog and dialog.IsShown and dialog:IsShown()) then
        return false
    end
    dialog:Hide()
    return true
end

function Picker:CreateSelector(parent, options)
    options = type(options) == "table" and options or {}
    local selector = GUI2.Form:CreateButton(parent, {
        text = T("sound.picker.none", "无"),
        width = options.width or 220,
        height = options.height or 28,
        contentAlign = "left",
        justifyH = "LEFT",
    })
    function selector:GetValue()
        return options.get and options.get() or self.value
    end
    function selector:SetValue(value, silent)
        self.value = value
        if not silent and options.set then options.set(value) end
        self:Refresh()
    end
    function selector:Refresh()
        local value = self:GetValue()
        local service = YUI.Sound
        local choice = value and service and service.GetSoundChoice
            and service:GetSoundChoice(value) or nil
        self:SetText(DisplayText(choice))
    end
    selector:SetScript("OnClick", function(self)
        Picker:Open({
            value = self:GetValue(),
            allowNone = options.allowNone == true,
            onSelect = function(value)
                self:SetValue(value, false)
            end,
        })
    end)
    selector:Refresh()
    return selector
end
