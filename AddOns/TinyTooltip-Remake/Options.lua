
local LibJSON = LibStub:GetLibrary("LibJSON.9000")
local LibEvent = LibStub:GetLibrary("LibEvent.7000")
local LibDropdown = LibStub:GetLibrary("LibDropdown.7000")

local UIDropDownMenu_SetText = LibDropdown.SetText
local UIDropDownMenu_AddButton = LibDropdown.AddButton
local UIDropDownMenu_CreateInfo = LibDropdown.CreateInfo
local UIDropDownMenu_Initialize = LibDropdown.Initialize
local UIDropDownMenu_GetSelectedValue = LibDropdown.GetSelectedValue
local UIDropDownMenu_SetSelectedValue = LibDropdown.SetSelectedValue
local UIDropDownMenuTemplate = "UIDropDownMenuTemplate"

local addonName = ...
local addon = TinyTooltip
local CopyTable = CopyTable
local LAYOUT
local function RoundScale(value)
    return floor(value + 0.5)
end

local function RescaleAnchorOffsets(anchor, ratio)
    if (not anchor) then return end
    if (anchor.x ~= nil) then anchor.x = RoundScale(anchor.x * ratio) end
    if (anchor.y ~= nil) then anchor.y = RoundScale(anchor.y * ratio) end
end

local function RescaleStaticAnchorOffsets(oldScale, newScale)
    if (not addon or not addon.db) then return end
    if (oldScale == 0 or newScale == 0) then return end
    if (oldScale == newScale) then return end
    local ratio = oldScale / newScale
    RescaleAnchorOffsets(addon.db.general and addon.db.general.anchor, ratio)
    RescaleAnchorOffsets(addon.db.unit and addon.db.unit.player and addon.db.unit.player.anchor, ratio)
    RescaleAnchorOffsets(addon.db.unit and addon.db.unit.npc and addon.db.unit.npc.anchor, ratio)
end

-- About/Help page init
function TinyTooltipRemake_About_OnLoad(self)
    local addonName = self.addonName or "TinyTooltip-Remake"
    local L = self.L or (addon and addon.L) or {}

    local function GetText(...)
        for i = 1, select("#", ...) do
            local key = select(i, ...)
            local value = key and L[key]
            if value and value ~= "" then
                return value
            end
        end
        return nil
    end

    local ver = (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(addonName, "Version"))
        or (GetAddOnMetadata and GetAddOnMetadata(addonName, "Version"))
        or ""

    if self.Title then self.Title:SetText(addonName) end

    if self.Tagline then
        if self.Tagline.SetJustifyH then self.Tagline:SetJustifyH("LEFT") end
        self.Tagline:SetText(GetText("about.desc") or "")
    end

    if self.VersionText then
        self.VersionText:SetText(GetText("about.version.label") or "Version")
    end
    if self.Version then self.Version:SetText(ver) end

    if self.AuthorText then
        self.AuthorText:SetText(GetText("about.author.label") or "Author")
    end
    if self.Author then
        local author = GetText("about.author.name") or ""
        self.Author:SetText(author)
    end

    if self.HelpText then
        self.HelpText:SetText(GetText("about.help.title")or "Help")
    end

    if self.HelpURL then
        self.HelpURL.url = GetText("about.help.url") or ""
        self.HelpURL:SetText(self.HelpURL.url)
    end

    if self.CreditsText then
        self.CreditsText:SetText(GetText("about.credits.title") or "Credits")
    end
    
    if self.Credits then
        if self.Credits.SetJustifyH then self.Credits:SetJustifyH("LEFT") end
        self.Credits:SetText(GetText("about.credits.content") or "")
    end
end



addon.L = addon.L or {}
setmetatable(addon.L, { __index = function(self, k)
    local s = {strsplit(".", k)}
    return rawget(self,s[#s]) or (s[#s]:gsub("([a-z])([A-Z])", "%1 %2"):gsub("^(%a)", strupper))
end})
local L = addon.L

local function CallTrigger(keystring, value)
    for _, tip in pairs(addon.tooltips) do
        if (not tip) then
        elseif (keystring == "general.mask") then
            LibEvent:trigger("tooltip.style.mask", tip, value)
        elseif (keystring == "general.scale") then
            local oldScale = addon._lastScale or value
            if (oldScale ~= value) then
                RescaleStaticAnchorOffsets(oldScale, value)
            end
            addon._lastScale = value
            LibEvent:trigger("tooltip.scale", tip, value)
        elseif (keystring == "general.background") then
            LibEvent:trigger("tooltip.style.background", tip, unpack(value))
        elseif (keystring == "general.borderColor") then
            LibEvent:trigger("tooltip.style.border.color", tip, unpack(value))
        elseif (keystring == "general.borderSize") then
            LibEvent:trigger("tooltip.style.border.size", tip, value)
        elseif (keystring == "general.borderCorner") then
            LibEvent:trigger("tooltip.style.border.corner", tip, value)
            if (value == "angular") then
                LibEvent:trigger("tooltip.style.border.size", tip, addon.db.general.borderSize)
            end
        elseif (keystring == "general.bgfile") then
            LibEvent:trigger("tooltip.style.bgfile", tip, value)
        end
    end
    if (keystring == "general.statusbarText") then
        LibEvent:trigger("tooltip.statusbar.text", value)
    elseif (keystring == "general.statusbarPercent") then
        LibEvent:trigger("tooltip.statusbar.text", addon.db.general.statusbarText)
        if (GameTooltipStatusBar and GameTooltipStatusBar.GetScript) then
            local fn = GameTooltipStatusBar:GetScript("OnValueChanged")
            if (fn) then
                pcall(fn, GameTooltipStatusBar, GameTooltipStatusBar:GetValue())
            end
        end
    elseif (keystring == "general.statusbarHide") then
        LibEvent:trigger("tooltip.statusbar.visible", value)
    elseif (keystring == "general.statusbarHeight") then
        LibEvent:trigger("tooltip.statusbar.height", value)
    elseif (keystring == "general.statusbarTexture") then
        LibEvent:trigger("tooltip.statusbar.texture", value)
    elseif (strfind(keystring, "general.statusbarFont")) then
        LibEvent:trigger("tooltip.statusbar.font", addon.db.general.statusbarFont, addon.db.general.statusbarFontSize, addon.db.general.statusbarFontFlag)
    elseif (strfind(keystring, "general.headerFont")) then
        LibEvent:trigger("tooltip.style.font.header", tip, addon.db.general.headerFont, addon.db.general.headerFontSize, addon.db.general.headerFontFlag)
    elseif (strfind(keystring, "general.bodyFont")) then
        LibEvent:trigger("tooltip.style.font.body", tip, addon.db.general.bodyFont, addon.db.general.bodyFontSize, addon.db.general.bodyFontFlag)
    end
end

local function GetVariable(keystring, tbl)
    if (keystring == "general.SavedVariablesPerCharacter") then
        return TinyTooltipRemakeDB.general.SavedVariablesPerCharacter
    end
    local keys = {strsplit(".", keystring)}
    local value = tbl or addon.db
    for i, key in ipairs(keys) do
        if (value[key] == nil) then return end
        value = value[key]
    end
    return value
end

local function SetVariable(keystring, value, tbl)
    local keys = {strsplit(".", keystring)}
    local num = #keys
    local tab = tbl or addon.db
    local lastKey
    for i, key in ipairs(keys) do
        if (i < num) then
            if (not tab[key]) then tab[key] = {} end
            tab = tab[key]
        elseif (i == num) then
            lastKey = key
        end
    end
    tab[lastKey] = value
    CallTrigger(keystring, value)
    LibEvent:trigger("tooltip:variable:changed", keystring, value)
end

local widgets = {}

local function IsInList(list, value)
    for _, v in ipairs(list) do
        if (v == value) then
            return true
        end
    end
    return false
end

local function GetDefaultValue(keystring)
    local defaults = addon.defaults or addon.db
    local keys = {strsplit(".", keystring)}
    local value = defaults
    for _, key in ipairs(keys) do
        if (value == nil) then return end
        value = value[key]
    end
    if (type(value) == "table") then
        return CopyTable(value)
    end
    return value
end

local function RefreshDropdown(dropdown, value)
    UIDropDownMenu_SetSelectedValue(dropdown, value)
    if (value ~= nil) then
        local text = L["dropdown."..tostring(value)] or tostring(value)
        UIDropDownMenu_SetText(dropdown, text)
        if (dropdown.selectedFunc) then
            dropdown.selectedFunc(dropdown, value, text)
        end
    end
end

local function RefreshColorPick(pick, value)
    local r, g, b, a = 1, 1, 1, 1
    if (pick.colortype == "hex") then
        r, g, b = addon:GetRGBColor(value)
    elseif (type(value) == "table") then
        r, g, b, a = unpack(value)
    end
    pick:GetNormalTexture():SetVertexColor(r or 1, g or 1, b or 1, a or 1)
end

local function RefreshWidget(widget, config)
    local t = config.type
    if (t == "checkbox") then
        widget:SetChecked(GetVariable(config.keystring))
    elseif (t == "slider") then
        local v = GetVariable(config.keystring) or 0
        widget:SetValue(v)
        if (widget.High) then widget.High:SetText(v) end
        if (widget.editbox) then widget.editbox:SetText(v) end
    elseif (t == "editbox") then
        widget:SetText(GetVariable(config.keystring) or "")
        widget:SetCursorPosition(0)
    elseif (t == "colorpick") then
        RefreshColorPick(widget, GetVariable(config.keystring))
    elseif (t == "dropdown") then
        RefreshDropdown(widget, GetVariable(config.keystring))
    elseif (t == "dropdownslider") then
        RefreshDropdown(widget.dropdown, GetVariable(config.keystring..".colorfunc"))
        local v = GetVariable(config.keystring..".alpha") or 0
        widget.slider:SetValue(v)
        if (widget.slider.High) then widget.slider.High:SetText(v) end
    elseif (t == "anchor") then
        RefreshDropdown(widget.dropdown, GetVariable(config.keystring..".position"))
        widget.checkbox1:SetChecked(GetVariable(config.keystring..".hiddenInCombat"))
        widget.checkbox2:SetChecked(GetVariable(config.keystring..".returnInCombat"))
        widget.checkbox3:SetChecked(GetVariable(config.keystring..".returnOnUnitFrame"))
        if (widget._updateAnchorOptions) then
            widget._updateAnchorOptions()
        end
    elseif (t == "element") then
        widget.checkbox:SetChecked(GetVariable(config.keystring..".enable"))
        if (widget.colorpick) then
            local color = GetVariable(config.keystring..".color")
            RefreshColorPick(widget.colorpick, color)
            if (widget.colordropdown) then
                local dropdata = widget.colorDropdata or widgets.colorDropdata
                if (IsInList(dropdata, color)) then
                    RefreshDropdown(widget.colordropdown, color)
                else
                    UIDropDownMenu_SetSelectedValue(widget.colordropdown, nil)
                    UIDropDownMenu_SetText(widget.colordropdown, VIDEO_QUALITY_LABEL6)
                end
            end
        end
        if (widget.editbox) then
            widget.editbox:SetText(GetVariable(config.keystring..".wildcard") or "")
            widget.editbox:SetCursorPosition(0)
        end
        if (widget.filterdropdown) then
            RefreshDropdown(widget.filterdropdown, GetVariable(config.keystring..".filter"))
        end
    end
end

local function RefreshOptions(parent)
    if (not parent or not parent.optionWidgets) then return end
    for _, widget in ipairs(parent.optionWidgets) do
        if (widget._config) then
            RefreshWidget(widget, widget._config)
        end
    end
end

local function RelayoutOptions(parent)
    if (not parent or not parent.optionWidgets or not parent.anchor) then return end
    local totalHeight = 0
    for _, element in ipairs(parent.optionWidgets) do
        local config = element._config
        local height = element:GetHeight() or (LAYOUT and LAYOUT.ROW_HEIGHT) or 30
        if (LAYOUT and height < LAYOUT.ROW_HEIGHT) then
            height = LAYOUT.ROW_HEIGHT
        end
        totalHeight = totalHeight + height
        local offsetX = (LAYOUT and config and LAYOUT.OFFSET_X[config.type]) or 0
        element:ClearAllPoints()
        element:SetPoint("TOPLEFT", parent.anchor, "BOTTOMLEFT", offsetX, -totalHeight)
    end
    parent.__optionsHeight = totalHeight
    if (parent.__autoSize and parent.SetSize and LAYOUT and SettingsPanel and SettingsPanel.Container) then
        parent:SetSize(SettingsPanel.Container:GetWidth() - LAYOUT.PANEL_PADDING, totalHeight)
    end
end

function widgets:checkbox(parent, config, labelText)
    local frame = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
    frame.keystring = config.keystring
    frame.tooltipText = labelText or L[config.keystring]
    frame.Text:SetWidth(0)
    frame.Text:SetText(labelText or L[config.keystring])
    frame:SetChecked(GetVariable(config.keystring))
    frame:SetScript("OnClick", function(self) SetVariable(self.keystring, self:GetChecked()) end)
    return frame
end

local function NormalizeSliderValue(slider, value)
    if (value == nil) then return nil end
    value = tonumber(value)
    if (value == nil) then return nil end
    local minValue, maxValue = slider:GetMinMaxValues()
    if (minValue and value < minValue) then value = minValue end
    if (maxValue and value > maxValue) then value = maxValue end
    local step = slider:GetValueStep() or 1
    if (step < 0.1) then
        value = tonumber(format("%.2f", value))
    elseif (step < 1) then
        value = tonumber(format("%.1f", value))
    else
        value = floor(value + 0.2)
    end
    return value
end

local function CommitSliderEdit(editbox)
    local slider = editbox and editbox.slider
    if (not slider) then return end
    local value = NormalizeSliderValue(slider, editbox:GetText())
    if (value == nil) then
        editbox:SetText(slider:GetValue() or "")
        return
    end
    slider._fromEdit = true
    slider:SetValue(value)
    slider._fromEdit = false
    editbox:SetText(value)
end

function widgets:slider(parent, config)
    local frame = CreateFrame("Slider", nil, parent, "OptionsSliderTemplate")
    frame:SetWidth(118)
    frame.Text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.Text:SetPoint("LEFT", frame, "RIGHT", 8, 0)
    frame.keystring = config.keystring
    frame.Low:SetText("")
    frame.High:SetTextColor(1, 0.82, 0)
    frame.High:ClearAllPoints()
    frame.High:SetPoint("RIGHT", frame, "LEFT", -1, 0)
    frame.Text:SetText(L[config.keystring])
    frame.High:SetText(GetVariable(config.keystring))
    frame:SetMinMaxValues(config.min, config.max)
    frame:SetValueStep(config.step)
    frame:SetValue(GetVariable(config.keystring))

    if (config.input) then
        local editbox = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        editbox:SetAutoFocus(false)
        editbox:SetSize(48, 18)
        editbox:SetPoint("LEFT", frame, "RIGHT", 6, -1)
        editbox:SetText(GetVariable(config.keystring))
        editbox:SetCursorPosition(0)
        editbox.slider = frame
        editbox:SetScript("OnEnterPressed", function(self)
            self._skipFocusLost = true
            CommitSliderEdit(self)
            self:ClearFocus()
        end)
        editbox:SetScript("OnEditFocusLost", function(self)
            if (self._skipFocusLost) then
                self._skipFocusLost = false
                return
            end
            CommitSliderEdit(self)
        end)
        frame.editbox = editbox
        frame.Text:ClearAllPoints()
        frame.Text:SetPoint("LEFT", editbox, "RIGHT", 6, 0)
    end

    frame:SetScript("OnValueChanged", function(self, value)
        if (self._fromEdit) then
            self._fromEdit = false
        end
        local normalized = NormalizeSliderValue(self, value)
        if (normalized == nil) then return end
        if (self:GetValue() ~= normalized) then
            self._fromEdit = true
            self:SetValue(normalized)
            self._fromEdit = false
        end
        if (GetVariable(self.keystring) ~= normalized) then
            SetVariable(self.keystring, normalized)
        end
        self.High:SetText(normalized)
        if (self.editbox and not self.editbox:HasFocus()) then
            self.editbox:SetText(normalized)
        end
    end)
    return frame
end

function widgets:editbox(parent, config)
    local frame = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    frame.keystring = config.keystring
    frame:SetAutoFocus(false)
    frame:SetSize(88, 14)
    frame:SetText(GetVariable(config.keystring) or "")
    frame:SetCursorPosition(0)
    frame:SetScript("OnEnterPressed", function(self)
        SetVariable(self.keystring, self:GetText())
        self:ClearFocus()
    end)
    return frame
end

function widgets:colorpick(parent, config)
    local a, r, g, b = 1
    if (config.colortype == "hex") then
        r, g, b = addon:GetRGBColor(GetVariable(config.keystring))
    else
        r, g, b, a = unpack(GetVariable(config.keystring))
    end
    local frame = CreateFrame("Button", nil, parent)
    frame.keystring = config.keystring
    frame.colortype = config.colortype
    frame.hasopacity = config.hasopacity
    frame:SetSize(16, 16)
    frame:SetNormalTexture("Interface\\ChatFrame\\ChatFrameColorSwatch")
    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetColorTexture(1, 1, 1)
    frame.bg:SetSize(14, 14)
    frame.bg:SetPoint("CENTER")
    frame.Text = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    frame.Text:SetPoint("LEFT", frame, "RIGHT", 5, 0)
    frame.Text:SetText(L[config.keystring])
    frame.Text:SetShown(not config.hidetitle)
    frame:GetNormalTexture():SetVertexColor(r, g, b)
    frame:SetScript("OnClick", function(self)
        local r, g, b, a = self:GetNormalTexture():GetVertexColor()
        local prevR, prevG, prevB, prevA = r, g, b, a
        local tipframe = self

        local function GetAlpha()
            -- Modern (10.2.5+ / 11.x / 12.x) API
            if ColorPickerFrame.GetColorAlpha then
                local ca = ColorPickerFrame:GetColorAlpha()
                if type(ca) == "number" then
                    return tonumber(format("%.2f", ca))
                end
            end
            -- Fallback inside the ColorPickerFrame itself 
            local op = ColorPickerFrame.opacity
            if type(op) == "number" then
                return tonumber(format("%.2f", 1 - op))
            end
            return prevA or 1
        end

        local function ApplyColor(rr, gg, bb, aa)
            rr = tonumber(format("%.4f", rr))
            gg = tonumber(format("%.4f", gg))
            bb = tonumber(format("%.4f", bb))

            tipframe:GetNormalTexture():SetVertexColor(rr, gg, bb, aa)

            if (tipframe.colortype == "hex") then
                SetVariable(tipframe.keystring, addon:GetHexColor(rr, gg, bb))
            else
                SetVariable(tipframe.keystring, {rr, gg, bb, aa})
            end

            -- for element color
            local parent = tipframe:GetParent()
            if parent and parent.colordropdown then
                UIDropDownMenu_SetText(parent.colordropdown, VIDEO_QUALITY_LABEL6)
            end
        end

        local info = {
            r = r, g = g, b = b,
            hasOpacity = tipframe.hasopacity,
            opacity = tipframe.hasopacity and (1 - a) or nil,

            swatchFunc = function()
                local rr, gg, bb = ColorPickerFrame:GetColorRGB()
                ApplyColor(rr, gg, bb, GetAlpha())
            end,

            opacityFunc = tipframe.hasopacity and function()
                local rr, gg, bb = ColorPickerFrame:GetColorRGB()
                local aa = GetAlpha()
                local curA = select(4, tipframe:GetNormalTexture():GetVertexColor())
                if (aa ~= curA) then
                    ApplyColor(rr, gg, bb, aa)
                end
            end or nil,

            cancelFunc = function()
                ApplyColor(prevR, prevG, prevB, prevA)
            end,
        }

        ColorPickerFrame:SetupColorPickerAndShow(info)
    end)
    return frame
end

function widgets:dropdown(parent, config, labelText)
    local frame = CreateFrame("Frame", tostring(config), parent, UIDropDownMenuTemplate)
    frame.keystring = config.keystring
    frame.dropdata = config.dropdata
    if (frame.Text) then frame.Text:SetWidth(90) end
    frame.Label = frame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	frame.Label:SetPoint("LEFT", _G[frame:GetName().."Button"], "RIGHT", 6, 0)
	UIDropDownMenu_Initialize(frame, function(self)
        local keystring = self.keystring
        local selectedValue = UIDropDownMenu_GetSelectedValue(self)
        local info
        for _, v in ipairs(self.dropdata) do
            info = UIDropDownMenu_CreateInfo()
            info.text  = L["dropdown."..v]
            info.value = v
            info.arg1  = self
            info.checked = selectedValue == v
            info.func = function(self, dropdown)
                SetVariable(dropdown.keystring, self.value)
                UIDropDownMenu_SetSelectedValue(dropdown, self.value)
            end
            if (strfind(keystring, ".+Font$")) then
                info.font = addon:GetFont(v)
            elseif (strfind(keystring, ".+Texture$")) then
                info.texture = addon:GetBarFile(v)
                info.staticWidth = 168
            end
            UIDropDownMenu_AddButton(info)
        end
    end, config.displayMode)
    frame.selectedFunc = function(self, value, text)
        local parent = self:GetParent()
        if (not parent or not parent.anchorbutton) then return end
        if (value == "static" or value == "cursor") then
            parent.anchorbutton:Show()
            self.Label:Hide()
        else
            parent.anchorbutton:Hide()
            self.Label:Show()
        end
    end
    UIDropDownMenu_SetSelectedValue(frame, GetVariable(config.keystring))
    frame.Label:SetText(labelText or L[config.keystring])
    return frame
end

local grid = CreateFrame("Frame", nil, UIParent)
grid:SetFrameStrata("DIALOG")
grid:SetAllPoints()
grid:Hide()
do
    local width, height = GetScreenWidth(), GetScreenHeight()
    local w, h, size = 0, 0, 16
    local line
    w = w + floor((width%size)/2)
    while (w < width) do
        w = w + size
        line = grid:CreateTexture(nil, "BACKGROUND")
        line:SetSize(1, height)
        line:SetColorTexture(0, 0, 0, 0.32)
        line:SetPoint("TOPLEFT", w, 0)
    end
    h = h + floor((height%size)/2)
    while (h < height) do
        h = h + size
        line = grid:CreateTexture(nil, "BACKGROUND")
        line:SetSize(width, 1)
        line:SetColorTexture(0, 0, 0, 0.32)
        line:SetPoint("TOPLEFT", 0, -h)
    end
    line = grid:CreateTexture(nil, "BACKGROUND")
    line:SetSize(width, 2)
    line:SetColorTexture(1, 0, 0, 0.6)
    line:SetPoint("CENTER")
    line = grid:CreateTexture(nil, "BACKGROUND")
    line:SetSize(2, height)
    line:SetColorTexture(1, 0, 0, 0.6)
    line:SetPoint("CENTER")
end

local function Round(value)
    return floor(value + 0.5)
end

local function StaticFrameOnDragStop(self)
    self:StopMovingOrSizing()
    local screenWidth = UIParent:GetWidth()
    local screenHeight = UIParent:GetHeight()
    local p = GetVariable(self.cp) or "BOTTOMRIGHT"
    local left, right, top, bottom = self:GetLeft(), self:GetRight(), self:GetTop(), self:GetBottom()
    local tooltipScale = (addon and addon.db and addon.db.general and addon.db.general.scale) or 1
    if (tooltipScale == 0) then tooltipScale = 1 end
    local function SaveOffsets(rawX, rawY)
        self.ax_value = Round(rawX)
        self.ay_value = Round(rawY)
        SetVariable(self.kx, Round(rawX / tooltipScale))
        SetVariable(self.ky, Round(rawY / tooltipScale))
    end
    if (p == "BOTTOMRIGHT") then
        SaveOffsets(right - screenWidth, bottom)
    elseif (p == "BOTTOMLEFT") then
        SaveOffsets(left, bottom)
    elseif (p == "TOPLEFT") then
        SaveOffsets(left, top - screenHeight)
    elseif (p == "TOPRIGHT") then
        SaveOffsets(right - screenWidth, top - screenHeight)
    elseif (p == "TOP") then
        SaveOffsets(left - screenWidth/2 + 100, top - screenHeight)
    elseif (p == "BOTTOM") then
        SaveOffsets(left - screenWidth/2 + 100, bottom)
    end
end

local function ApplyStaticAnchor(frame)
    if (not frame or not frame.kx or not frame.ky or not frame.cp) then return end
    local point = GetVariable(frame.cp) or "BOTTOMRIGHT"
    local x = frame.ax_value or GetVariable(frame.kx) or -CONTAINER_OFFSET_X
    local y = frame.ay_value or GetVariable(frame.ky) or CONTAINER_OFFSET_Y
    if (frame.ax_value == nil and frame.ay_value == nil) then
        local tooltipScale = (addon and addon.db and addon.db.general and addon.db.general.scale) or 1
        if (tooltipScale == 0) then tooltipScale = 1 end
        x = x * tooltipScale
        y = y * tooltipScale
    end
    frame:ClearAllPoints()
    frame:SetPoint(point, UIParent, point, x, y)
end

local UpdateCursorAnchorControls
local function CreateAnchorButton(frame, anchorPoint)
    local button = CreateFrame("Button", nil, frame)
    button.cp = anchorPoint
    button:SetNormalTexture("Interface\\Buttons\\WHITE8X8")
    button:SetSize(20, 20)
    button:SetPoint(anchorPoint)
    button:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        local cp = GetVariable(parent.cp)
        if (parent[cp]) then
            parent[cp]:GetNormalTexture():SetVertexColor(1, 1, 1)
        end
        SetVariable(parent.cp, self.cp)
        self:GetNormalTexture():SetVertexColor(1, 0.2, 0.1)
        if (frame and frame.kx and frame.ky and frame.cp) then
            StaticFrameOnDragStop(frame)
            ApplyStaticAnchor(frame)
        end
        if (parent == caframe and UpdateCursorAnchorControls) then
            UpdateCursorAnchorControls()
        end
    end)
    frame[anchorPoint] = button
end
local function CreateAnchorInput(frame, k, labelText)
    local box = CreateFrame("EditBox", nil, frame, "NumericInputSpinnerTemplate")
    box:SetNumeric(false)
    if (box.SetValueStep) then
        box:SetValueStep(1)
    end
    if (box.SetNumber) then
        box:SetNumber(0)
    end
    box:SetAutoFocus(false)
    box:SetSize(40, 20)
    box:SetScript("OnEnterPressed", function(self)
        local parent = self:GetParent()
        local num = tonumber(self:GetText()) or 0
        if (self.GetMinMaxValues) then
            local minValue, maxValue = self:GetMinMaxValues()
            if (minValue and num < minValue) then
                num = minValue
            elseif (maxValue and num > maxValue) then
                num = maxValue
            end
        end
        if (self.SetNumber) then
            self:SetNumber(num)
        else
            self:SetText(tostring(num))
        end
        SetVariable(parent[k], num)
        self:ClearFocus()
    end)
    box:HookScript("OnEnter", function(self)
        if (self:IsEnabled()) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["anchor.offset.locked"] or "Offset is disabled when anchor point is Bottom.")
        GameTooltip:Show()
    end)
    box:HookScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    if (labelText) then
        box.label = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        box.label:SetText(labelText)
        box.label:SetPoint("RIGHT", box, "LEFT", -34, 0)
    end
    return box
end

local saframe = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
-- ThinBorderTemplate is not available in some clients; use a simple backdrop instead.
if (saframe.SetBackdrop) then
    saframe:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false, edgeSize = 1,
        insets = {left = 1, right = 1, top = 1, bottom = 1},
    })
    saframe:SetBackdropColor(0, 0, 0, 0.75)
    saframe:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
end
saframe:Hide()
saframe:SetFrameStrata("DIALOG")
saframe.close = CreateFrame("Button", nil, saframe, "UIPanelCloseButton")
saframe.close:SetPoint("CENTER")
saframe:SetClampedToScreen(true)
saframe:EnableMouse(true)
saframe:SetMovable(true)
saframe:SetSize(200, 80)
saframe:RegisterForDrag("LeftButton")
saframe:SetScript("OnDragStart", function(self) self:StartMoving() end)
saframe:SetScript("OnDragStop", StaticFrameOnDragStop)
CreateAnchorButton(saframe, "TOPLEFT")
CreateAnchorButton(saframe, "BOTTOMLEFT")
CreateAnchorButton(saframe, "TOPRIGHT")
CreateAnchorButton(saframe, "BOTTOMRIGHT")
CreateAnchorButton(saframe, "TOP")
CreateAnchorButton(saframe, "BOTTOM")
saframe:SetScript("OnShow", function() grid:Show() end)
saframe:SetScript("OnHide", function() grid:Hide() end)

local caframe = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
caframe:Hide()
caframe:SetFrameStrata("DIALOG")
caframe:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 8, edgeSize = 16,
    insets = {left = 4, right = 4, top = 4, bottom = 4}
})
caframe:SetBackdropColor(0.2,0.2,0.2,0.85)
caframe:SetSize(200, 200)
caframe:SetPoint("CENTER")
caframe:SetClampedToScreen(true)
caframe:EnableMouse(true)
caframe:SetMovable(true)
caframe:RegisterForDrag("LeftButton")
caframe:SetScript("OnDragStart", function(self) self:StartMoving() end)
caframe:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
local function UpdateCursorAnchorLimits()
    local width = (UIParent and UIParent.GetWidth and UIParent:GetWidth()) or GetScreenWidth() or 0
    local height = (UIParent and UIParent.GetHeight and UIParent:GetHeight()) or GetScreenHeight() or 0
    width = floor(width)
    height = floor(height)
    if (caframe.inputx and caframe.inputx.SetMinMaxValues) then
        caframe.inputx:SetMinMaxValues(-width, width)
    end
    if (caframe.inputy and caframe.inputy.SetMinMaxValues) then
        caframe.inputy:SetMinMaxValues(-height, height)
    end
    if (caframe.inputx and caframe.inputx.SetMaxLetters) then
        local digits = strlen(tostring(abs(width)))
        caframe.inputx:SetMaxLetters(digits + 1)
    end
    if (caframe.inputy and caframe.inputy.SetMaxLetters) then
        local digits = strlen(tostring(abs(height)))
        caframe.inputy:SetMaxLetters(digits + 1)
    end
end
local function SetAnchorInputValue(box, value)
    if (box and box.SetNumber) then
        box:SetNumber(tonumber(value) or 0)
    elseif (box) then
        box:SetText(tostring(tonumber(value) or 0))
    end
end
local function UpdateCursorAnchorInputs()
    if (not caframe or not caframe.cx or not caframe.cy) then return end
    SetAnchorInputValue(caframe.inputx, GetVariable(caframe.cx))
    SetAnchorInputValue(caframe.inputy, GetVariable(caframe.cy))
end
local function SetSpinnerEnabled(box, enabled)
    if (not box) then return end
    box:SetEnabled(enabled)
    box:SetAlpha(enabled and 1 or 0.5)
    if (box.DecrementButton) then
        box.DecrementButton:SetEnabled(enabled)
        box.DecrementButton:SetAlpha(enabled and 1 or 0.5)
    elseif (box.DecButton) then
        box.DecButton:SetEnabled(enabled)
        box.DecButton:SetAlpha(enabled and 1 or 0.5)
    end
    if (box.IncrementButton) then
        box.IncrementButton:SetEnabled(enabled)
        box.IncrementButton:SetAlpha(enabled and 1 or 0.5)
    elseif (box.IncButton) then
        box.IncButton:SetEnabled(enabled)
        box.IncButton:SetAlpha(enabled and 1 or 0.5)
    end
end
UpdateCursorAnchorControls = function()
    if (not caframe or not caframe.cp) then return end
    local cp = GetVariable(caframe.cp) or "BOTTOM"
    local enabled = cp ~= "BOTTOM"
    if (not enabled) then
        SetVariable(caframe.cx, 0)
        SetVariable(caframe.cy, 0)
        SetAnchorInputValue(caframe.inputx, 0)
        SetAnchorInputValue(caframe.inputy, 0)
    end
    SetSpinnerEnabled(caframe.inputx, enabled)
    SetSpinnerEnabled(caframe.inputy, enabled)
end
caframe.inputx = CreateAnchorInput(caframe, "cx", "X")
caframe.inputx:SetPoint("CENTER", 0, 40)
caframe.inputy = CreateAnchorInput(caframe, "cy", "Y")
caframe.inputy:SetPoint("CENTER", 0, 10)
caframe:HookScript("OnShow", function()
    UpdateCursorAnchorLimits()
    UpdateCursorAnchorInputs()
    UpdateCursorAnchorControls()
end)
LibEvent:attachTrigger("tooltip:variable:changed", function(self, keystring, value)
    if (not caframe or not caframe.IsShown or not caframe:IsShown()) then return end
    if (keystring == caframe.cp) then
        UpdateCursorAnchorControls()
    end
end)
caframe.ok = CreateFrame("Button", nil, caframe, "UIPanelButtonTemplate")
caframe.ok:SetText(SAVE)
caframe.ok:SetSize(68, 20)
caframe.ok:SetPoint("CENTER", 0, -20)
caframe.ok:SetScript("OnClick", function(self)
    local parent = self:GetParent()
    SetVariable(parent.cx, tonumber(parent.inputx:GetText()) or 0)
    SetVariable(parent.cy, tonumber(parent.inputy:GetText()) or 0)
end)
caframe.close = CreateFrame("Button", nil, caframe, "UIPanelCloseButton")
caframe.close:SetPoint("CENTER", 0, -50)
CreateAnchorButton(caframe, "TOPLEFT")
CreateAnchorButton(caframe, "LEFT")
CreateAnchorButton(caframe, "BOTTOMLEFT")
CreateAnchorButton(caframe, "TOP")
CreateAnchorButton(caframe, "BOTTOM")
CreateAnchorButton(caframe, "TOPRIGHT")
CreateAnchorButton(caframe, "RIGHT")
CreateAnchorButton(caframe, "BOTTOMRIGHT")

function widgets:anchorbutton(parent, config)
    local frame = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    frame.keystring = config.keystring
    frame:SetSize(70, 22)
    frame.Text:SetFontObject("GameFontHighlightSmall")
    frame:SetText(L.Anchor)
    frame:SetScript("OnClick", function(self)
        local parent = self:GetParent()
        if saframe:IsShown() then return saframe:Hide() end
        if caframe:IsShown() then return caframe:Hide() end
        if (not parent.dropdown) then return end
        local value = UIDropDownMenu_GetSelectedValue(parent.dropdown)
        if (value == "static") then
            saframe.kx = self.keystring .. ".x"
            saframe.ky = self.keystring .. ".y"
            saframe.cp = self.keystring .. ".p"
            saframe[GetVariable(saframe.cp) or "BOTTOMRIGHT"]:GetNormalTexture():SetVertexColor(1, 0.2, 0.1)
            ApplyStaticAnchor(saframe)
            saframe:Show()
        elseif (value == "cursor") then
            caframe.cx = self.keystring .. ".cx"
            caframe.cy = self.keystring .. ".cy"
            caframe.cp = self.keystring .. ".cp"
            UpdateCursorAnchorInputs()
            caframe[GetVariable(caframe.cp) or "BOTTOM"]:GetNormalTexture():SetVertexColor(1, 0.2, 0.1)
            UpdateCursorAnchorControls()
            caframe:Show()
        end
    end)
    return frame
end

function widgets:element(parent, config)
    local frame = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame:SetSize(560, 30)
    frame:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        insets   = {left = 4, right = 4, top = 4, bottom = 4},
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
    })
    frame:SetBackdropColor(0, 0, 0.1, 0.8)
    frame:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.6)
    frame.checkbox = self:checkbox(frame, {keystring=config.keystring..".enable"}, L[config.keystring])
    frame.checkbox:SetPoint("LEFT", 5, 0)
    if (config.color) then
        local colorDropdata = config.numeric and self.numericColorDropdata or self.colorDropdata
        frame.colorDropdata = colorDropdata
        frame.colorpick = self:colorpick(frame, {keystring=config.keystring..".color",colortype="hex",hidetitle=true})
        frame.colorpick:SetPoint("LEFT", 285, 0)
        frame.colordropdown = self:dropdown(frame, {keystring=config.keystring..".color",dropdata=colorDropdata,displayMode="MENU"}, "")
        frame.colordropdown:SetScale(0.87)
        frame.colordropdown:SetPoint("LEFT", 200, -1)
    end
    if (config.wildcard) then
        frame.editbox = self:editbox(frame, {keystring=config.keystring..".wildcard"})
        frame.editbox:SetPoint("LEFT", 330, 0)
        frame.editbox:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L["wildcard.help"] or "Format: use %s to insert the value.")
            if (config.keystring and config.keystring:find("moveSpeed")) then
                GameTooltip:AddLine(L["wildcard.help.moveSpeed"] or "Example: %d%%", 0.8, 0.8, 0.8, true)
            else
                GameTooltip:AddLine(L["wildcard.help.example"] or "Example: (%s) or [%s]", 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        frame.editbox:HookScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    if (config.filter) then
        frame.filterdropdown = self:dropdown(frame, {keystring=config.keystring..".filter",dropdata=self.filterDropdata}, "")
        frame.filterdropdown:SetScale(0.87)
        frame.filterdropdown:SetPoint("LEFT", 490, -1)
    end
    return frame
end

function widgets:anchor(parent, config)
    local frame = CreateFrame("Frame", nil, parent)
    local parentWidth = parent and parent.anchor and parent.anchor:GetWidth()
    frame:SetSize(parentWidth or 400, LAYOUT.ROW_HEIGHT)
    frame.anchorbutton = self:anchorbutton(frame, config)
    frame.dropdown = self:dropdown(frame, {keystring=config.keystring..".position",dropdata=config.dropdata})
    frame.dropdown:SetPoint("LEFT", 0, 0)
    frame.anchorbutton:SetPoint("LEFT", frame.dropdown.Label, "LEFT", 1, 0)

    frame.optionButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.optionButton:SetSize(220, 22)
    frame.optionButton:SetPoint("RIGHT", frame, "RIGHT", -10, -1)
    if (frame.optionButton.Text) then
        frame.optionButton.Text:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
        frame.optionButton.Text:ClearAllPoints()
        frame.optionButton.Text:SetPoint("LEFT", 10, 0)
        frame.optionButton.Text:SetPoint("RIGHT", -22, 0)
        frame.optionButton.Text:SetJustifyH("LEFT")
    end
    frame.optionButton.arrow = frame.optionButton:CreateTexture(nil, "ARTWORK")
    frame.optionButton.arrow:SetSize(16, 16)
    frame.optionButton.arrow:SetPoint("RIGHT", -6, 0)
    frame.optionButton.arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    frame.optionButton.arrow:SetTexCoord(0, 1, 0, 1)

    frame.optionPanel = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
    frame.optionPanel:SetBackdrop({
        bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 12,
        insets   = {left = 4, right = 4, top = 4, bottom = 4},
    })
    frame.optionPanel:SetBackdropColor(0, 0, 0, 0.85)
    frame.optionPanel:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.8)
    frame.optionPanel:SetPoint("TOPLEFT", frame.optionButton, "BOTTOMLEFT", 0, -2)
    frame.optionPanel:SetPoint("TOPRIGHT", frame.optionButton, "BOTTOMRIGHT", 0, -2)
    frame.optionPanel:SetFrameStrata("DIALOG")
    frame.optionPanel:SetFrameLevel(frame:GetFrameLevel() + 10)
    frame.optionPanel:Hide()

    frame.checkbox1 = self:checkbox(frame.optionPanel, {keystring=config.keystring..".hiddenInCombat"})
    frame.checkbox2 = self:checkbox(frame.optionPanel, {keystring=config.keystring..".returnInCombat"})
    frame.checkbox3 = self:checkbox(frame.optionPanel, {keystring=config.keystring..".returnOnUnitFrame"})
    if (frame.checkbox2) then
        frame.checkbox2.tooltipText = L["hint.anchor.returnInCombat"] or frame.checkbox2.tooltipText
    end
    if (frame.checkbox3) then
        frame.checkbox3.tooltipText = L["hint.anchor.returnOnUnitFrame"] or frame.checkbox3.tooltipText
    end
    local function HookCheckboxTooltip(box)
        if (not box) then return end
        box:HookScript("OnEnter", function(self)
            if (self.tooltipText and self.tooltipText ~= "") then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetText(self.tooltipText, 1, 1, 1, 1)
                GameTooltip:Show()
            end
        end)
        box:HookScript("OnLeave", function()
            GameTooltip:Hide()
        end)
    end
    HookCheckboxTooltip(frame.checkbox2)
    HookCheckboxTooltip(frame.checkbox3)
    frame.checkbox1:SetPoint("TOPLEFT", 8, -6)
    frame.checkbox2:SetPoint("TOPLEFT", frame.checkbox1, "BOTTOMLEFT", 0, -6)
    frame.checkbox3:SetPoint("TOPLEFT", frame.checkbox2, "BOTTOMLEFT", 0, -6)

    local function UpdateOptionSummary()
        local selections = {}
        if (frame.checkbox1:GetChecked()) then
            tinsert(selections, L[config.keystring..".hiddenInCombat"])
        end
        if (frame.checkbox2:GetChecked()) then
            tinsert(selections, L[config.keystring..".returnInCombat"])
        end
        if (frame.checkbox3:GetChecked()) then
            tinsert(selections, L[config.keystring..".returnOnUnitFrame"])
        end
        local summary
        if (#selections == 0) then
            summary = L["anchor.none"] or "None"
        else
            summary = table.concat(selections, ", ")
        end
        local text = summary
        local fontString = frame.optionButton.Text
        if (fontString and frame.optionButton.GetWidth) then
            local maxWidth = frame.optionButton:GetWidth() - 36
            if (maxWidth < 40) then maxWidth = 40 end
            local function TruncateToFit(value)
                fontString:SetText(value)
                if (fontString:GetStringWidth() <= maxWidth) then
                    return value
                end
                local ellipsis = "..."
                local low, high = 0, #value
                while (low < high) do
                    local mid = math.floor((low + high) / 2)
                    local candidate = value:sub(1, mid) .. ellipsis
                    fontString:SetText(candidate)
                    if (fontString:GetStringWidth() <= maxWidth) then
                        low = mid + 1
                    else
                        high = mid
                    end
                end
                local finalLen = math.max(0, low - 1)
                return value:sub(1, finalLen) .. ellipsis
            end
            text = TruncateToFit(text)
        end
        frame.optionButton:SetText(text)
    end

    local function UpdatePanelLayout()
        UpdateOptionSummary()
        local panelHeight = (LAYOUT.ROW_HEIGHT * 3) + 12
        local panelWidth = frame.optionButton:GetWidth()
        frame.optionPanel:SetHeight(panelHeight)
        frame.optionPanel:SetWidth(panelWidth)

        frame:SetHeight(LAYOUT.ROW_HEIGHT)
    end

    frame.checkbox1:HookScript("OnClick", function(self)
        if (self:GetChecked()) then
            frame.checkbox2:SetChecked(false)
            SetVariable(config.keystring..".returnInCombat", false)
        end
        UpdatePanelLayout()
    end)
    frame.checkbox2:HookScript("OnClick", function(self)
        if (self:GetChecked()) then
            frame.checkbox1:SetChecked(false)
            SetVariable(config.keystring..".hiddenInCombat", false)
        end
        UpdatePanelLayout()
    end)
    frame.checkbox3:HookScript("OnClick", UpdatePanelLayout)

    frame.optionButton:SetScript("OnClick", function()
        frame.optionPanel:SetShown(not frame.optionPanel:IsShown())
        UpdatePanelLayout()
    end)

    local baseSelectedFunc = frame.dropdown.selectedFunc
    frame.dropdown.selectedFunc = function(self, value, text)
        if (baseSelectedFunc) then
            baseSelectedFunc(self, value, text)
        end
        UpdatePanelLayout()
    end

    frame:HookScript("OnShow", UpdatePanelLayout)
    frame._updateAnchorOptions = UpdatePanelLayout
    UpdatePanelLayout()
    return frame
end

function widgets:dropdownslider(parent, config)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(500, 30)
    frame.dropdown = self:dropdown(frame, {keystring=config.keystring..".colorfunc",dropdata=config.dropdata}, L[config.keystring])
    frame.dropdown:SetPoint("LEFT", 0, 0)
    frame.slider = self:slider(frame, {keystring=config.keystring..".alpha",min=config.min,max=config.max,step=config.step})
    frame.slider:SetPoint("LEFT", frame.dropdown.Label, "RIGHT", 36, 0)
    frame.slider:SetWidth(100)
    return frame
end

widgets.filterDropdata = {"none","ininstance","incombat","inraid","samerealm","samecrossrealm","inpvp","inarena","reaction5","reaction6","not ininstance","not incombat","not inraid","not samerealm","not samecrossrealm","not inpvp","not inarena","not reaction5","not reaction6",}
widgets.colorDropdata = {"default","class","level","reaction","itemQuality","selection","faction",}
widgets.numericColorDropdata = {"default","class","level","reaction","itemQuality","selection","faction","itemLevel",}
widgets.bgfileDropdata = {"gradual","dark","alpha","rock","marble",}
widgets.borderDropdata = {"default","angular","none",}
widgets.fontDropdata = {"default", "ChatFontNormal", "GameFontNormal", "QuestFont", "CombatLogFont",}
widgets.barDropdata = {"Interface\\AddOns\\"..addonName.."\\texture\\StatusBar",}

LibEvent:attachEvent("VARIABLES_LOADED", function()
    local LibMedia = LibStub:GetLibrary("LibSharedMedia-3.0", true)
    local MergeTable = function(a,b)
        for _, v in pairs(b) do tinsert(a, v) end
        return a
    end
    if (LibMedia) then
        widgets.bgfileDropdata = MergeTable(widgets.bgfileDropdata, LibMedia:List("background"))
        widgets.borderDropdata = MergeTable(widgets.borderDropdata, LibMedia:List("border"))
        widgets.fontDropdata = MergeTable(widgets.fontDropdata, LibMedia:List("font"))
        widgets.barDropdata = MergeTable(widgets.barDropdata, LibMedia:List("statusbar"))
    end
end)

-- 布局常量
LAYOUT = {
    ROW_HEIGHT    = 30,
    ANCHOR_OFFSET = 32,
    ANCHOR_TOP    = -16,
    TITLE_LEFT    = 18,
    PANEL_PADDING = 64,
    RESET_OFFSET_X = -28,
    RESET_OFFSET_Y = -12,
    OFFSET_X = {
        checkbox = 0, colorpick = 5, slider = 15,
        dropdown = -15, dropdownslider = -15, anchor = -15,
        element = 0,
    },
    -- Variables / DIY 面板
    DIY_LINE_HEIGHT    = 24,
    DIY_LINE_SPACING   = 25,
    DIY_FIRST_LINE_Y   = 13,   -- -(i*SPACING)+13 首行 Y 偏移
    DIY_PANEL_PADDING_H = 28,
    DIY_PANEL_PADDING_V = 36,
    DIY_ELEMENT_GAP    = 16,
    DIY_LEFT           = 14,
    DIY_LINE_DEFAULT_W = 300,
    DIY_BIG_FACTION_EXTRA = 48,
    DIY_PREVIEW_OFFSET_X = 332,
    DIY_PREVIEW_OFFSET_Y = -100,
    DIY_FRAME_WIDTH    = 300,
    DIY_FRAME_HEIGHT   = 100,
    DIY_ARROW_SIZE_W   = 32,
    DIY_ARROW_SIZE_H   = 48,
    DIY_ARROW_OFFSET_X = 35,
    DIY_ARROW_OFFSET_Y = -60,
}

local options = {
    general = {
        { keystring = "general.mask",               type = "checkbox" },
        { keystring = "general.skinMoreFrames",     type = "checkbox" },
        { keystring = "general.background",         type = "colorpick", hasopacity = true },
        { keystring = "general.borderColor",        type = "colorpick", hasopacity = true },
        { keystring = "general.scale",              type = "slider", min = 0.5, max = 4, step = 0.1, input = true },
        { keystring = "general.borderSize",         type = "slider", min = 1, max = 6, step = 1, input = true },
        { keystring = "general.borderCorner",       type = "dropdown", dropdata = widgets.borderDropdata },
        { keystring = "general.bgfile",             type = "dropdown", dropdata = widgets.bgfileDropdata },
        { keystring = "general.anchor",             type = "anchor", dropdata = {"default","cursorRight","cursor","static"} },
        { keystring = "item.coloredItemBorder",     type = "checkbox" },
        { keystring = "item.showItemIcon",          type = "checkbox" },
        { keystring = "quest.coloredQuestBorder",   type = "checkbox" },
        { keystring = "general.alwaysShowIdInfo",   type = "checkbox" },
        { keystring = "general.SavedVariablesPerCharacter",   type = "checkbox" },
        { keystring = "general.hideUnitFrameHint",  type = "checkbox" },
    },
    pc = {
        { keystring = "unit.player.showTarget",           type = "checkbox" },
        { keystring = "unit.player.showTargetBy",         type = "checkbox" },
        { keystring = "unit.player.showModel",            type = "checkbox" },
        { keystring = "unit.player.grayForDead",          type = "checkbox" },
        { keystring = "unit.player.coloredBorder",        type = "dropdown", dropdata = widgets.colorDropdata },
        { keystring = "unit.player.background",           type = "dropdownslider", dropdata = widgets.colorDropdata, min = 0, max = 1, step = 0.01 },
        { keystring = "unit.player.anchor",               type = "anchor", dropdata = {"inherit", "default","cursorRight","cursor","static"} },
        { keystring = "unit.player.elements.factionBig",  type = "element", filter = false,},
        { keystring = "unit.player.elements.raidIcon",    type = "element", filter = true, },
        { keystring = "unit.player.elements.roleIcon",    type = "element", filter = true, },
        { keystring = "unit.player.elements.pvpIcon",     type = "element", filter = true, },
        { keystring = "unit.player.elements.factionIcon", type = "element", filter = true, },
        { keystring = "unit.player.elements.classIcon",   type = "element", filter = true, },
        { keystring = "unit.player.elements.friendIcon",  type = "element", filter = true, },
        { keystring = "unit.player.elements.title",       type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.name",        type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.realm",       type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.statusAFK",   type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.statusDND",   type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.statusDC",    type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.guildName",   type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.guildIndex",  type = "element", color = true, wildcard = true, filter = true, numeric = true, },
        { keystring = "unit.player.elements.guildRank",   type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.guildRealm",  type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.levelValue",  type = "element", color = true, wildcard = true, filter = true, numeric = true, },
        { keystring = "unit.player.elements.itemLevel",   type = "element", color = true, wildcard = true, filter = true, numeric = true, },
        { keystring = "unit.player.elements.achievementPoints", type = "element", color = true, wildcard = true, filter = true, numeric = true, },
        { keystring = "unit.player.elements.factionName", type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.gender",      type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.raceName",    type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.className",   type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.isPlayer",    type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.role",        type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.moveSpeed",   type = "element", color = true, wildcard = true, filter = true, numeric = true, },
        { keystring = "unit.player.elements.mplusScore",  type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.zone",        type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.player.elements.mount",       type = "element", color = true, wildcard = true, filter = true, },
    },
    npc = {
        { keystring = "unit.npc.showTarget",            type = "checkbox" },
        { keystring = "unit.npc.showTargetBy",          type = "checkbox" },
        { keystring = "unit.npc.showModel",             type = "checkbox" },
        { keystring = "unit.npc.grayForDead",           type = "checkbox" },
        { keystring = "unit.npc.coloredBorder",         type = "dropdown", dropdata = widgets.colorDropdata },
        { keystring = "unit.npc.background",            type = "dropdownslider", dropdata = widgets.colorDropdata, min = 0, max = 1, step = 0.01 },
        { keystring = "unit.npc.anchor",                type = "anchor", dropdata = {"inherit","default","cursorRight","cursor","static"} },
        { keystring = "unit.npc.elements.factionBig",   type = "element", filter = false,},
        { keystring = "unit.npc.elements.raidIcon",     type = "element", filter = true, },
        { keystring = "unit.npc.elements.classIcon",    type = "element", filter = true, },
        { keystring = "unit.npc.elements.questIcon",    type = "element", filter = true, },
        { keystring = "unit.npc.elements.npcTitle",     type = "element", color = true, wildcard = true, },
        { keystring = "unit.npc.elements.name",         type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.npc.elements.levelValue",   type = "element", color = true, wildcard = true, filter = true, numeric = true, },
        { keystring = "unit.npc.elements.classifBoss",  type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.npc.elements.classifElite", type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.npc.elements.classifRare",  type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.npc.elements.creature",     type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.npc.elements.reactionName", type = "element", color = true, wildcard = true, filter = true, },
        { keystring = "unit.npc.elements.moveSpeed",    type = "element", color = true, wildcard = true, filter = true, numeric = true, },
    },
    statusbar = {
        { keystring = "general.statusbarText",      type = "checkbox" },
        { keystring = "general.statusbarPercent",   type = "checkbox" },
        { keystring = "general.statusbarHide",      type = "checkbox" },
        { keystring = "general.statusbarHeight",    type = "slider", min = 0, max = 24, step = 1 },
        { keystring = "general.statusbarOffsetX",   type = "slider", min = -50, max = 50, step = 1 },
        { keystring = "general.statusbarOffsetY",   type = "slider", min = -50, max = 50, step = 1 },
        { keystring = "general.statusbarFontSize",  type = "slider", min = 6, max = 30, step = 1 },
        { keystring = "general.statusbarFont",      type = "dropdown", dropdata = widgets.fontDropdata },
        { keystring = "general.statusbarFontFlag",  type = "dropdown", dropdata = {"default", "NORMAL", "OUTLINE", "THINOUTLINE"} },
        { keystring = "general.statusbarTexture",   type = "dropdown", dropdata = widgets.barDropdata },
        { keystring = "general.statusbarPosition",  type = "dropdown", dropdata = {"default","bottom","top"} },
        { keystring = "general.statusbarColor",     type = "dropdown", dropdata = {"default","auto","smooth"} },
    },
    spell = {
        { keystring = "spell.showIcon",             type = "checkbox" },
        { keystring = "spell.background",           type = "colorpick", hasopacity = true },
        { keystring = "spell.borderColor",          type = "colorpick", hasopacity = true },
    },
    font = {
        { keystring = "general.headerFont",         type = "dropdown", dropdata = widgets.fontDropdata },
        { keystring = "general.headerFontSize",     type = "dropdown", dropdata = {"default", 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24 } },
        { keystring = "general.headerFontFlag",     type = "dropdown", dropdata = {"default", "NORMAL", "OUTLINE", "THINOUTLINE"} },
        { keystring = "general.bodyFont",           type = "dropdown", dropdata = widgets.fontDropdata },
        { keystring = "general.bodyFontSize",       type = "dropdown", dropdata = {"default", 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24 } },
        { keystring = "general.bodyFontFlag",       type = "dropdown", dropdata = {"default", "NORMAL", "OUTLINE", "THINOUTLINE"} },
    },
}


local frameRoot = CreateFrame("Frame", nil, SettingsPanel.Container)
frameRoot:SetAllPoints()
frameRoot:Hide()
frameRoot.anchor = CreateFrame("Frame", nil, frameRoot)
frameRoot.anchor:SetPoint("TOPLEFT", LAYOUT.ANCHOR_OFFSET, LAYOUT.ANCHOR_TOP)
frameRoot.anchor:SetSize(SettingsPanel.Container:GetWidth() - LAYOUT.PANEL_PADDING, 1)

frameRoot.title = frameRoot:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frameRoot.title:SetPoint("TOPLEFT", LAYOUT.TITLE_LEFT, LAYOUT.ANCHOR_TOP)
frameRoot.title:SetText(addonName)

-- About / Help page 

do
    -- 1) 创建 XML 模板实例，挂到 frameRoot 上
    local about = CreateFrame("Frame", nil, frameRoot, "TinyTooltipRemakeAboutTemplate")

    -- 2) 覆盖整个页面区域
    about:SetPoint("TOPLEFT", frameRoot, "TOPLEFT", 0, 0)
    about:SetPoint("BOTTOMRIGHT", frameRoot, "BOTTOMRIGHT", 0, 0)
    -- 3) 把需要的数据塞给它，OnLoad 会用到
    about.addonName = addonName
    about.L = L
    TinyTooltipRemake_About_OnLoad(about)

    if frameRoot.title then
        frameRoot.title:Hide()
    end
end


frameRoot.name = addonName

local resetSectionText = L["button.resetSection"] or RESET or "Reset"
local resetAllText = L["button.resetAll"] or resetSectionText

local frame = CreateFrame("Frame", nil, UIParent)
frame.anchor = CreateFrame("Frame", nil, frame)
frame.anchor:SetPoint("TOPLEFT", LAYOUT.ANCHOR_OFFSET, LAYOUT.ANCHOR_TOP)
frame.anchor:SetSize(SettingsPanel.Container:GetWidth() - LAYOUT.PANEL_PADDING, 1)
frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.title:SetPoint("TOPLEFT", LAYOUT.TITLE_LEFT, LAYOUT.ANCHOR_TOP)
frame.title:SetText(format("%s |cff33eeff%s|r", addonName, L["menu.general"]))
frame.name = L["menu.general"]

local framePC = CreateFrame("Frame", nil, UIParent)
framePC.anchor = CreateFrame("Frame", nil, framePC)
framePC.anchor:SetPoint("TOPLEFT", LAYOUT.ANCHOR_OFFSET, LAYOUT.ANCHOR_TOP)
framePC.anchor:SetSize(SettingsPanel.Container:GetWidth() - LAYOUT.PANEL_PADDING, 1)
framePC.title = framePC:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
framePC.title:SetPoint("TOPLEFT", LAYOUT.TITLE_LEFT, LAYOUT.ANCHOR_TOP)
framePC.title:SetText(format("%s |cff33eeff%s|r", addonName, L["menu.player"]))
framePC.parent = addonName
framePC.name = L["menu.player"]

framePC.diy = CreateFrame("Button", nil, framePC)
framePC.diy:SetSize(400, 67)
framePC.diy:SetScale(0.68)
framePC.diy:SetPoint("TOPLEFT", LAYOUT.DIY_PREVIEW_OFFSET_X, LAYOUT.DIY_PREVIEW_OFFSET_Y)
framePC.diy:SetNormalTexture("Interface\\LevelUp\\MinorTalents")
framePC.diy:GetNormalTexture():SetTexCoord(0, 400/512, 341/512, 407/512)
framePC.diy:GetNormalTexture():SetVertexColor(1, 1, 1, 0.8)
framePC.diy:SetScript("OnClick", function() LibEvent:trigger("tinytooltip:diy:player", "player", true, true) end)
framePC.diy.text = framePC.diy:CreateFontString(nil, "OVERLAY", "GameFont_Gigantic")
framePC.diy.text:SetPoint("CENTER", 0, 2)
framePC.diy.text:SetText(L.DIY.." "..(SETTINGS or ""))

framePC:SetSize(SettingsPanel.Container:GetWidth() - LAYOUT.PANEL_PADDING, #options.pc * LAYOUT.ROW_HEIGHT)
local framePCScrollFrame = CreateFrame("ScrollFrame", nil, UIParent, "UIPanelScrollFrameTemplate")
framePCScrollFrame.ScrollBar:Hide()
framePCScrollFrame.ScrollBar:ClearAllPoints()
framePCScrollFrame.ScrollBar:SetPoint("TOPLEFT", framePCScrollFrame, "TOPRIGHT", -20, -22)
framePCScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", framePCScrollFrame, "BOTTOMRIGHT", -20, 26)
framePCScrollFrame:HookScript("OnScrollRangeChanged", function(self, xrange, yrange)
    self.ScrollBar:SetShown(floor(yrange) ~= 0)
end)
framePCScrollFrame:SetScrollChild(framePC)
framePCScrollFrame.parent = addonName
framePCScrollFrame.name =  L["menu.player"]
framePCScrollFrame:Hide()


local frameNPC = CreateFrame("Frame", nil, UIParent)
frameNPC.anchor = CreateFrame("Frame", nil, frameNPC)
frameNPC.anchor:SetPoint("TOPLEFT", LAYOUT.ANCHOR_OFFSET, LAYOUT.ANCHOR_TOP)
frameNPC.anchor:SetSize(SettingsPanel.Container:GetWidth() - LAYOUT.PANEL_PADDING, 1)
frameNPC.title = frameNPC:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frameNPC.title:SetPoint("TOPLEFT", LAYOUT.TITLE_LEFT, LAYOUT.ANCHOR_TOP)
frameNPC.title:SetText(format("%s |cff33eeff%s|r", addonName, L["menu.npc"]))
frameNPC.parent = addonName
frameNPC.name = L["menu.npc"]

frameNPC:SetSize(SettingsPanel.Container:GetWidth() - LAYOUT.PANEL_PADDING, #options.npc * LAYOUT.ROW_HEIGHT)
local frameNPCScrollFrame = CreateFrame("ScrollFrame", nil, UIParent, "UIPanelScrollFrameTemplate")
frameNPCScrollFrame.ScrollBar:Hide()
frameNPCScrollFrame.ScrollBar:ClearAllPoints()
frameNPCScrollFrame.ScrollBar:SetPoint("TOPLEFT", frameNPCScrollFrame, "TOPRIGHT", -20, -22)
frameNPCScrollFrame.ScrollBar:SetPoint("BOTTOMLEFT", frameNPCScrollFrame, "BOTTOMRIGHT", -20, 26)
frameNPCScrollFrame:HookScript("OnScrollRangeChanged", function(self, xrange, yrange)
    self.ScrollBar:SetShown(floor(yrange) ~= 0)
end)
frameNPCScrollFrame:SetScrollChild(frameNPC)
frameNPCScrollFrame.parent = addonName
frameNPCScrollFrame.name = L["menu.npc"]

local frameStatusbar = CreateFrame("Frame", nil, UIParent)
frameStatusbar.anchor = CreateFrame("Frame", nil, frameStatusbar)
frameStatusbar.anchor:SetPoint("TOPLEFT", LAYOUT.ANCHOR_OFFSET, LAYOUT.ANCHOR_TOP)
frameStatusbar.anchor:SetSize(SettingsPanel.Container:GetWidth() - LAYOUT.PANEL_PADDING, 1)
frameStatusbar.title = frameStatusbar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frameStatusbar.title:SetPoint("TOPLEFT", LAYOUT.TITLE_LEFT, LAYOUT.ANCHOR_TOP)
frameStatusbar.title:SetText(format("%s |cff33eeff%s|r", addonName, L["menu.statusbar"]))
frameStatusbar.parent = addonName
frameStatusbar.name = L["menu.statusbar"]

local frameSpell = CreateFrame("Frame", nil, UIParent)
frameSpell.anchor = CreateFrame("Frame", nil, frameSpell)
frameSpell.anchor:SetPoint("TOPLEFT", LAYOUT.ANCHOR_OFFSET, LAYOUT.ANCHOR_TOP)
frameSpell.anchor:SetSize(SettingsPanel.Container:GetWidth() - LAYOUT.PANEL_PADDING, 1)
frameSpell.title = frameSpell:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frameSpell.title:SetPoint("TOPLEFT", LAYOUT.TITLE_LEFT, LAYOUT.ANCHOR_TOP)
frameSpell.title:SetText(format("%s |cff33eeff%s|r", addonName, L["menu.spell"]))
frameSpell.parent = addonName
frameSpell.name = L["menu.spell"]

local frameFont = CreateFrame("Frame", nil, UIParent)
frameFont.anchor = CreateFrame("Frame", nil, frameFont)
frameFont.anchor:SetPoint("TOPLEFT", LAYOUT.ANCHOR_OFFSET, LAYOUT.ANCHOR_TOP)
frameFont.anchor:SetSize(SettingsPanel.Container:GetWidth() - LAYOUT.PANEL_PADDING, 1)
frameFont.title = frameFont:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frameFont.title:SetPoint("TOPLEFT", LAYOUT.TITLE_LEFT, LAYOUT.ANCHOR_TOP)
frameFont.title:SetText(format("%s |cff33eeff%s|r", addonName, L["menu.font"]))
frameFont.parent = addonName
frameFont.name = L["menu.font"]

local frameVariables = CreateFrame("Frame", nil, UIParent)
frameVariables.anchor = CreateFrame("Frame", nil, frameVariables)
frameVariables.anchor:SetPoint("TOPLEFT", LAYOUT.ANCHOR_OFFSET, LAYOUT.ANCHOR_TOP)
frameVariables.anchor:SetSize(SettingsPanel.Container:GetWidth() - LAYOUT.PANEL_PADDING, 1)
frameVariables.title = frameVariables:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frameVariables.title:SetPoint("TOPLEFT", LAYOUT.TITLE_LEFT, LAYOUT.ANCHOR_TOP)
frameVariables.title:SetText(format("%s |cff33eeff%s|r", addonName, L["menu.variables"]))
frameVariables.parent = addonName
frameVariables.name = L["menu.variables"]

local function InitVariablesFrame()
    frameVariables.panel = CreateFrame("Frame", nil, frameVariables, "TinyTooltipVariablesTemplate")
    frameVariables.panel:SetPoint("CENTER", 0, -20)
    frameVariables.panel.export:SetScript("OnClick", function()
        local json = LibJSON:encode_wow(addon.db)
        frameVariables.panel.textarea.text:SetText(json)
        frameVariables.panel.textarea.text:SetFocus(true)
        frameVariables.panel.textarea.text:HighlightText()
    end)
    LibJSON.assert = function() end
    frameVariables.panel.import:SetScript("OnClick", function()
        local text = frameVariables.panel.textarea.text:GetText()
        local data, errormsg = LibJSON:decode_wow(text)
        if (data and type(data) == "table") then
            addon:FixNumericKey(data)
            local db = addon:MergeVariable(TinyTooltipRemakeDB, data)
            TinyTooltipRemakeDB = db
            addon.db = db
            frameVariables.panel.textarea.text:SetText("")
            LibEvent:trigger("TINYTOOLTIP_GENERAL_INIT")
            print("|cffFFE4E1[TinyTooltip]|r|cff00FFFF variables has been imported successfully. |r")
        else
            print("|cffFFE4E1[TinyTooltip]|r|cffFF3333 unvalidated variables. |r")
        end
    end)
end

local function CreateResetButton(parent, text, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(150, 22)
    button:SetText(text)
    -- 锚定到 parent.anchor 右端，与左侧布局统一；anchor 宽度 = 内容区，各页面一致
    local anchor = parent.anchor or parent
    button:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", LAYOUT.RESET_OFFSET_X, LAYOUT.RESET_OFFSET_Y)
    button:SetScript("OnClick", onClick)
    return button
end

local function ResetUnitSection(sectionKey, parent)
    if (not addon.defaults or not addon.defaults.unit or not addon.defaults.unit[sectionKey]) then return end
    addon.db.unit[sectionKey] = CopyTable(addon.defaults.unit[sectionKey])
    LibEvent:trigger("tooltip:variables:loaded")
    RefreshOptions(parent)
    if (sectionKey == "player") then
        LibEvent:trigger("tinytooltip:diy:player", "player", true)
    end
end

local function ResetStatusbarSection()
    for _, v in ipairs(options.statusbar) do
        local value = GetDefaultValue(v.keystring)
        if (value ~= nil) then
            SetVariable(v.keystring, value)
        end
    end
    RefreshOptions(frameStatusbar)
end

local function ResetAllSettings()
    if (not addon.defaults) then return end
    TinyTooltipRemakeDB = CopyTable(addon.defaults)
    TinyTooltipRemakeCharacterDB = {}
    addon.db = TinyTooltipRemakeDB
    LibEvent:trigger("tooltip:variables:loaded")
    LibEvent:trigger("TINYTOOLTIP_GENERAL_INIT")
    RefreshOptions(frame)
    RefreshOptions(framePC)
    RefreshOptions(frameNPC)
    RefreshOptions(frameStatusbar)
    RefreshOptions(frameSpell)
    RefreshOptions(frameFont)
    LibEvent:trigger("tinytooltip:diy:player", "player", true)
end

frame.reset = CreateResetButton(frame, resetAllText, ResetAllSettings)
framePC.reset = CreateResetButton(framePC, resetSectionText, function() ResetUnitSection("player", framePC) end)
frameNPC.reset = CreateResetButton(frameNPC, resetSectionText, function() ResetUnitSection("npc", frameNPC) end)
frameStatusbar.reset = CreateResetButton(frameStatusbar, resetSectionText, ResetStatusbarSection)

local function InitOptions(list, parent)
    local element, offsetX
    for i, v in ipairs(list) do
        if (widgets[v.type]) then
            offsetX = LAYOUT.OFFSET_X[v.type] or 0
            element = widgets[v.type](widgets, parent, v)
            parent.optionWidgets = parent.optionWidgets or {}
            element._config = v
            tinsert(parent.optionWidgets, element)
            element:SetPoint("TOPLEFT", parent.anchor, "BOTTOMLEFT", offsetX, -(i * LAYOUT.ROW_HEIGHT))
        end
    end
end

LibEvent:attachEvent("VARIABLES_LOADED", function()
    InitOptions(options.general, frame)
    InitOptions(options.pc, framePC)
    InitOptions(options.npc, frameNPC)
    InitOptions(options.statusbar, frameStatusbar)
    InitOptions(options.spell, frameSpell)
    InitOptions(options.font, frameFont)
    InitVariablesFrame()
end)

local function RegisterAddOnCategory(frame, parent)
    local category
    if InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(frame)
    elseif Settings then
        if (parent) then
            category = Settings.RegisterCanvasLayoutSubcategory(parent.category, frame, frame.name)
            frame.category = category
        else
            category = Settings.RegisterCanvasLayoutCategory(frame, frame.name)
            frame.category = category
            Settings.RegisterAddOnCategory(category)
        end
    end
end

local function OpenToCategory(frame)
    if InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(frame)
    elseif Settings then
        Settings.OpenToCategory(frame.category.ID)
    end
end

RegisterAddOnCategory(frameRoot)
RegisterAddOnCategory(frame, frameRoot)
RegisterAddOnCategory(framePCScrollFrame, frameRoot)
RegisterAddOnCategory(frameNPCScrollFrame, frameRoot)
RegisterAddOnCategory(frameStatusbar, frameRoot)
RegisterAddOnCategory(frameSpell, frameRoot)
RegisterAddOnCategory(frameFont, frameRoot)
RegisterAddOnCategory(frameVariables, frameRoot)

SLASH_TinyTooltip1 = "/tinytooltip"
SLASH_TinyTooltip2 = "/tt"
SLASH_TinyTooltip3 = "/tip"
function SlashCmdList.TinyTooltip(msg, editbox)
    if (msg == "reset") then
        TinyTooltipRemakeDB = {}
    elseif (msg == "npc") then
        OpenToCategory(frameNPCScrollFrame)
    elseif (msg == "player") then
        OpenToCategory(framePCScrollFrame)
    elseif (msg == "spell") then
        OpenToCategory(frameSpell)
    elseif (msg == "statusbar") then
        OpenToCategory(frameStatusbar)
    elseif (msg == "general" or msg == "settings" or msg == "cfg") then
        OpenToCategory(frame)
    else
        -- default: open Help/About page (root)
        OpenToCategory(frameRoot)
    end
end


----------------
-- DIY Frame 
----------------

local diytable, diyPlayerTable = {}, {}

local frameDIY = CreateFrame("Frame", nil, framePCScrollFrame, BackdropTemplateMixin and "BackdropTemplate" or nil)
tinsert(addon.tooltips, frameDIY)
frameDIY:Show()
frameDIY:SetFrameStrata("DIALOG")
frameDIY:SetClampedToScreen(true)
frameDIY:EnableMouse(true)
frameDIY:SetMovable(true)
frameDIY:SetSize(LAYOUT.DIY_FRAME_WIDTH, LAYOUT.DIY_FRAME_HEIGHT)
frameDIY:SetPoint("BOTTOM", framePCScrollFrame, "TOP", LAYOUT.PANEL_PADDING, 0)
frameDIY:RegisterForDrag("LeftButton")
frameDIY:SetScript("OnDragStart", function(self) self:StartMoving() end)
frameDIY:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
frameDIY.lines, frameDIY.elements, frameDIY.identity = {}, {}, "diy"
frameDIY.close = CreateFrame("Button", nil, frameDIY, "UIPanelCloseButton")
frameDIY.close:SetSize(14, 14)
frameDIY.close:SetPoint("TOPRIGHT", -2, -2)
frameDIY.close:SetNormalTexture("Interface\\\Buttons\\UI-StopButton")
frameDIY.close:SetPushedTexture("Interface\\\Buttons\\UI-StopButton")
frameDIY.close:GetNormalTexture():SetVertexColor(0.9, 0.6, 0)
frameDIY.close:Hide()
frameDIY.tips = frameDIY:CreateFontString(nil, "ARTWORK", "GameFontNormalLargeOutline")
frameDIY.tips:SetPoint("BOTTOM", 0, 6)
frameDIY.tips:SetFont(frameDIY.tips:GetFont(), 12, "NONE")
frameDIY.tips:SetText(L["<Drag element to customize the style>"])
frameDIY.arrow = frameDIY:CreateTexture(nil, "OVERLAY")
frameDIY.arrow:SetSize(LAYOUT.DIY_ARROW_SIZE_W, LAYOUT.DIY_ARROW_SIZE_H)
frameDIY.arrow:SetTexture("Interface\\Buttons\\JumpUpArrow")
frameDIY.arrow:SetPoint("BOTTOM", framePC, "TOP", LAYOUT.DIY_ARROW_OFFSET_X, LAYOUT.DIY_ARROW_OFFSET_Y)
frameDIY:HookScript("OnShow", function() LibEvent:trigger("tinytooltip:diy:player", "player", true) end)

local DraggingButton, OverButton, OverLine

local function OnDragStart(self)
    DraggingButton = self
    local cursorX, cursorY = GetCursorPosition()
    local uiScale = UIParent:GetScale()
    self:StartMoving()
    self:ClearAllPoints()
    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cursorX/uiScale, cursorY/uiScale)
end

local function OnDragStop(self)
    DraggingButton = false
    self:StopMovingOrSizing()
    if (OverButton) then
        OverButton.vbar:Hide()
        for _, v in ipairs(diytable) do
            for i = #v, 1, -1 do
                if (v[i] == self.key) then
                    tremove(v, i)
                end
            end
            for i = #v, 1, -1 do
                if (v[i] == OverButton.key) then
                    tinsert(v, i, self.key)
                end
            end
        end
        OverButton = false
    end
    if (OverLine) then
        OverLine.border:SetAlpha(0)
        for _, v in ipairs(diytable) do
            for i = #v, 1, -1 do
                if (v[i] == self.key) then
                    tremove(v, i)
                end
            end
        end
        if (not diytable[OverLine.line]) then diytable[OverLine.line] = {} end
        tinsert(diytable[OverLine.line], self.key)
        OverLine = false
    end
    for _, f in ipairs(frameDIY.lines) do
        f.border:SetAlpha(0)
    end
    for i = #diytable, 1, -1 do
        if (#diytable[i] == 0) then tremove(diytable, i) end
    end
    LibEvent:trigger("tinytooltip:diy:player", "player", true)
end

local function OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L[self.key])
    GameTooltip:Show()
end

local function OnLeave(self)
    GameTooltip:Hide()
end

local function CreateElement(parent, key)
    if (not parent.elements[key]) then
        local button = CreateFrame("Button", nil, parent)
        button.key = key
        button:SetSize(40, 20)
        button:SetMovable(true)
        button.text = button:CreateFontString(nil, "ARTWORK", "GameTooltipText")
        button.text:SetPoint("LEFT")
        button.vbar = button:CreateTexture(nil, "OVERLAY")
        button.vbar:SetPoint("TOPLEFT", 0, 0)
        button.vbar:SetPoint("BOTTOMLEFT", 2, 0)
        button.vbar:SetColorTexture(1, 0.8, 0)
        button.vbar:Hide()
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnDragStart", OnDragStart)
        button:SetScript("OnDragStop", OnDragStop)
        button:SetScript("OnEnter", OnEnter)
        button:SetScript("OnLeave", OnLeave)
        button.SetText = function(self, text)
            self.text:SetText(text)
            self:SetWidth(self.text:GetWidth()+4)
        end
        parent.elements[key] = button
    end
    return parent.elements[key]
end

local function CreateLine(parent, lineNumber)
    if (not parent.lines[lineNumber]) then
        local line = CreateFrame("Frame", nil, parent)
        line:SetSize(LAYOUT.DIY_LINE_DEFAULT_W, LAYOUT.DIY_LINE_HEIGHT)
        line.line = lineNumber
        line.border = CreateFrame("Frame", nil, line, BackdropTemplateMixin and "BackdropTemplate")
        line.border:SetAllPoints()
        line.border:SetBackdrop({edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1})
        line.border:SetBackdropBorderColor(1, 0.9, 0.1)
        line.border:SetAlpha(0)
        parent.lines[lineNumber] = line
    end
    return parent.lines[lineNumber]
end

frameDIY:SetScript("OnUpdate", function(self, elapsed)
    if (not DraggingButton) then return end
    self.timer = (self.timer or 0) + elapsed
    if (self.timer < 0.15) then return end
    self.timer = 0
    local hasoverbtn = false
    for i, v in ipairs(diytable) do
        for ii, e in ipairs(v) do
            if (self.elements[e].key ~= DraggingButton.key and self.elements[e]:IsMouseOver()) then
                OverButton = self.elements[e]
                OverButton.vbar:Show()
                hasoverbtn = true
            else
                self.elements[e].vbar:Hide()
            end
        end
    end
    if (not hasoverbtn) then
        for i, f in ipairs(self.lines) do
            if (f:IsMouseOver()) then
                OverLine = f
                f.border:SetAlpha(1)
            else
                f.border:SetAlpha(0.2)
            end
        end
    elseif (OverLine) then
        OverLine.border:SetAlpha(0)
        OverLine = false
    end
end)


local placeholder = {
    statusAFK = "AFK",
    statusDND = "DND",
    statusDC  = "DC",
    friendIcon = addon.icons.friend,
    pvpIcon    = addon.icons.pvp,
    roleIcon   = addon.icons.DAMAGER,
    raidIcon   = ICON_LIST[8] .. "0|t",
    mount      = L["mount"] or "mount",
    achievementPoints = 12345,
}
setmetatable(placeholder, {__index = function(_, k) return k end})

LibEvent:attachTrigger("tinytooltip:diy:player", function(self, unit, skipDisable, toggleVisible)
    if (toggleVisible and frameDIY:IsShown()) then
        return frameDIY:Hide()
    end
    LibEvent:trigger("tooltip.style.init", frameDIY)
    LibEvent:trigger("tooltip.style.mask", frameDIY, addon.db.general.mask)
    LibEvent:trigger("tooltip.style.bgfile", frameDIY, addon.db.general.bgfile)
    LibEvent:trigger("tooltip.style.border.corner", frameDIY, addon.db.general.borderCorner)
    LibEvent:trigger("tooltip.style.border.size", frameDIY, addon.db.general.borderSize)
    LibEvent:trigger("tooltip.style.background", frameDIY, unpack(addon.db.general.background))
    local raw = addon:GetUnitInfo(unit)
    local frameWidth, lineWidth, totalLines = 0, 0, 0
    local config, value
    for i, v in ipairs(diytable) do
        lineWidth = 0
        CreateLine(frameDIY, i)
        for ii, e in ipairs(v) do
            CreateElement(frameDIY, e)
            config = addon.db.unit.player.elements[e]
            if (skipDisable and not config.enable) then
                frameDIY.elements[e]:Hide()
            else
                value = raw[e] or placeholder[e]
                local handled = false
                if (e == "itemLevel") then
                    local label = (L and L.ItemLevel) or "ItemLevel"
                    local ilvl = raw.itemLevel or value or "??"
                    local valuePart
                    if (config.color and config.wildcard) then
                        valuePart = addon:FormatData(ilvl, config, raw, ilvl)
                    else
                        valuePart = tostring(ilvl)
                    end
                    value = format("|cffffd100%s:|r %s", label, valuePart)
                    handled = true
                elseif (e == "achievementPoints") then
                    local label = (L and L.Achievement) or "Achievement"
                    local points = raw.achievementPoints or value or "??"
                    local valuePart
                    if (config.color and config.wildcard) then
                        valuePart = addon:FormatData(points, config, raw, points)
                    else
                        valuePart = tostring(points)
                    end
                    value = format("|cffffd100%s:|r %s", label, valuePart)
                    handled = true
                end
                if (not handled and config.color and config.wildcard) then
                    value = addon:FormatData(value, config, raw, value)
                end
                frameDIY.elements[e]:Show()
                frameDIY.elements[e]:SetText(value)
                frameDIY.elements[e]:ClearAllPoints()
                frameDIY.elements[e]:SetPoint("LEFT", frameDIY.lines[i], "LEFT", lineWidth, 0)
                lineWidth = lineWidth + frameDIY.elements[e]:GetWidth()
            end
        end
        if (lineWidth > frameWidth) then
            frameWidth = lineWidth + LAYOUT.DIY_ELEMENT_GAP
        end
        totalLines = i
    end
    totalLines = totalLines + 1
    local padH = (diytable.factionBig and diytable.factionBig.enable) and LAYOUT.DIY_BIG_FACTION_EXTRA or LAYOUT.DIY_PANEL_PADDING_H
    frameDIY:SetWidth(frameWidth + padH)
    frameDIY:SetHeight(totalLines * LAYOUT.DIY_LINE_HEIGHT + LAYOUT.DIY_PANEL_PADDING_V)
    for i = 1, totalLines do
        local line = CreateLine(frameDIY, i)
        line:Show()
        line:SetWidth(frameWidth)
        line:SetPoint("TOPLEFT", frameDIY, "TOPLEFT", LAYOUT.DIY_LEFT, -(i * LAYOUT.DIY_LINE_SPACING) + LAYOUT.DIY_FIRST_LINE_Y)
    end
    local k = totalLines + 1
    while (frameDIY.lines[k]) do
        frameDIY.lines[k]:Hide()
        k = k + 1
    end
    if (diytable.factionBig and diytable.factionBig.enable) then
        frameDIY.BigFactionIcon:SetTexture("Interface\\Timer\\".. raw.factionGroup .."-Logo")
        frameDIY.BigFactionIcon:Show()
    else
        frameDIY.BigFactionIcon:Hide()
    end
    addon.ColorUnitBorder(frameDIY, diyPlayerTable, raw)
    addon.ColorUnitBackground(frameDIY, diyPlayerTable, raw)
    LibEvent:trigger("tooltip.style.border.corner", frameDIY, addon.db.general.borderCorner)
    if (addon.db.general.borderCorner == "angular") then
        LibEvent:trigger("tooltip.style.border.size", frameDIY, addon.db.general.borderSize)
    end
    frameDIY:Show()
end)

LibEvent:attachTrigger("tooltip:variables:loaded", function()
    diytable = addon.db.unit.player.elements
    diyPlayerTable = addon.db.unit.player
end)

LibEvent:attachTrigger("tooltip:variable:changed", function(self, keystring, value)
    if (frameDIY:IsShown()) then
        LibEvent:trigger("tinytooltip:diy:player", "player", true)
    end
    if (keystring == "general.SavedVariablesPerCharacter") then
        TinyTooltipRemakeDB.general.SavedVariablesPerCharacter = value
        if (value) then
            local db = CopyTable(addon.db)
            addon.db = addon:MergeVariable(db, TinyTooltipRemakeCharacterDB)
        else
            addon.db = TinyTooltipRemakeDB
        end
        LibEvent:trigger("tooltip:variables:loaded")
        LibEvent:trigger("TINYTOOLTIP_GENERAL_INIT")
    end
end)
