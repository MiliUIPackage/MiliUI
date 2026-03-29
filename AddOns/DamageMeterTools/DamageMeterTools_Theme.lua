if not DamageMeterToolsDB then
    DamageMeterToolsDB = {}
end

DamageMeterTools = DamageMeterTools or {}
DamageMeterToolsTheme = DamageMeterToolsTheme or {}

local T = DamageMeterToolsTheme

T.presets = {
    DARK = {
        bg = {0.07, 0.08, 0.10, 0.96},
        panel = {0.10, 0.11, 0.14, 0.96},
        panel2 = {0.12, 0.13, 0.16, 0.96},
        header = {0.09, 0.10, 0.12, 0.98},
        border = {1.00, 0.82, 0.25, 0.20},
        borderStrong = {1.00, 0.82, 0.25, 0.55},
        accent = {1.00, 0.82, 0.25, 1.00},
        accentSoft = {1.00, 0.82, 0.25, 0.18},
        accentBlue = {0.30, 0.72, 1.00, 1.00},
        accentBlueSoft = {0.30, 0.72, 1.00, 0.18},
        text = {0.92, 0.93, 0.96, 1.00},
        text2 = {0.72, 0.74, 0.80, 1.00},
        textDim = {0.55, 0.57, 0.63, 1.00},
        success = {0.20, 0.85, 0.45, 1.00},
        danger = {0.92, 0.25, 0.25, 1.00},
        darkButton = {0.15, 0.16, 0.20, 1.00},
        darkButtonHover = {0.20, 0.21, 0.26, 1.00},
        darkButtonPress = {0.10, 0.11, 0.14, 1.00},
    },

    GOLD = {
        bg = {0.10, 0.08, 0.04, 0.96},
        panel = {0.12, 0.10, 0.05, 0.96},
        panel2 = {0.15, 0.12, 0.06, 0.96},
        header = {0.16, 0.12, 0.05, 0.98},
        border = {1.00, 0.82, 0.25, 0.25},
        borderStrong = {1.00, 0.85, 0.30, 0.65},
        accent = {1.00, 0.85, 0.30, 1.00},
        accentSoft = {0.35, 0.25, 0.08, 0.35},
        accentBlue = {1.00, 0.85, 0.30, 1.00},
        accentBlueSoft = {0.35, 0.25, 0.08, 0.35},
        text = {0.98, 0.95, 0.88, 1.00},
        text2 = {0.84, 0.78, 0.62, 1.00},
        textDim = {0.58, 0.52, 0.40, 1.00},
        success = {0.20, 0.85, 0.45, 1.00},
        danger = {0.92, 0.25, 0.25, 1.00},
        darkButton = {0.18, 0.14, 0.07, 1.00},
        darkButtonHover = {0.24, 0.18, 0.09, 1.00},
        darkButtonPress = {0.12, 0.10, 0.05, 1.00},
    },

    OCEAN = {
        bg = {0.03, 0.06, 0.10, 0.96},
        panel = {0.05, 0.09, 0.14, 0.96},
        panel2 = {0.07, 0.11, 0.17, 0.96},
        header = {0.04, 0.08, 0.13, 0.98},
        border = {0.30, 0.70, 1.00, 0.22},
        borderStrong = {0.35, 0.78, 1.00, 0.58},
        accent = {0.52, 0.84, 1.00, 1.00},
        accentSoft = {0.16, 0.36, 0.52, 0.30},
        accentBlue = {0.30, 0.72, 1.00, 1.00},
        accentBlueSoft = {0.15, 0.30, 0.46, 0.32},
        text = {0.92, 0.96, 1.00, 1.00},
        text2 = {0.72, 0.82, 0.92, 1.00},
        textDim = {0.50, 0.60, 0.70, 1.00},
        success = {0.20, 0.85, 0.45, 1.00},
        danger = {0.92, 0.25, 0.25, 1.00},
        darkButton = {0.08, 0.13, 0.20, 1.00},
        darkButtonHover = {0.12, 0.18, 0.27, 1.00},
        darkButtonPress = {0.05, 0.10, 0.16, 1.00},
    },
}

T.colors = T.colors or {}

local function CopyColorTable(src, dst)
    wipe(dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = { v[1], v[2], v[3], v[4] }
        else
            dst[k] = v
        end
    end
end

function T:GetStyleKey()
    DamageMeterToolsDB.theme = DamageMeterToolsDB.theme or {}

    if not DamageMeterToolsDB.theme.style then
        if DamageMeterToolsDB.contextMenu and DamageMeterToolsDB.contextMenu.style then
            DamageMeterToolsDB.theme.style = DamageMeterToolsDB.contextMenu.style
        else
            DamageMeterToolsDB.theme.style = "OCEAN"
        end
    end

    return tostring(DamageMeterToolsDB.theme.style):upper()
end

function T:SetStyleKey(key)
    key = tostring(key or "OCEAN"):upper()
    if not self.presets[key] then
        key = "OCEAN"
    end

    DamageMeterToolsDB.theme = DamageMeterToolsDB.theme or {}
    DamageMeterToolsDB.theme.style = key

    self:ApplyStyle(key)
end

function T:ApplyStyle(key)
    key = tostring(key or self:GetStyleKey() or "OCEAN"):upper()
    local preset = self.presets[key] or self.presets.OCEAN
    CopyColorTable(preset, self.colors)
end

function T:GetColor(key)
    return unpack(self.colors[key] or self.colors.text)
end

function T:ApplyBackdrop(frame, bgKey, borderKey)
    if not frame then return end
    if not frame.SetBackdrop then return end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })

    local bg = self.colors[bgKey or "panel"] or self.colors.panel
    local bd = self.colors[borderKey or "border"] or self.colors.border

    frame:SetBackdropColor(bg[1], bg[2], bg[3], bg[4])
    frame:SetBackdropBorderColor(bd[1], bd[2], bd[3], bd[4])
end

function T:CreateTitle(parent, text, sizeName)
    local fs = parent:CreateFontString(nil, "OVERLAY", sizeName or "GameFontNormalLarge")
    fs:SetText(text or "")
    fs:SetTextColor(self:GetColor("accent"))
    return fs
end

function T:CreateText(parent, text, template, colorKey)
    local fs = parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
    fs:SetText(text or "")
    local r, g, b, a = self:GetColor(colorKey or "text")
    fs:SetTextColor(r, g, b, a)
    return fs
end

function T:CreateButton(parent, text, width, height, onClick, style)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 120, height or 24)

    self:ApplyBackdrop(b, "darkButton", "border")

    b.LeftAccent = b:CreateTexture(nil, "ARTWORK")
    b.LeftAccent:SetPoint("TOPLEFT", 0, 0)
    b.LeftAccent:SetPoint("BOTTOMLEFT", 0, 0)
    b.LeftAccent:SetWidth(3)
    b.LeftAccent:SetColorTexture(0.30, 0.72, 1.00, 0.18)

    b.TopLine = b:CreateTexture(nil, "OVERLAY")
    b.TopLine:SetPoint("TOPLEFT", 1, -1)
    b.TopLine:SetPoint("TOPRIGHT", -1, -1)
    b.TopLine:SetHeight(1)
    b.TopLine:SetColorTexture(1, 1, 1, 0.06)

    b.Text = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.Text:SetPoint("CENTER")
    b.Text:SetText(text or "")
    b.Text:SetTextColor(self:GetColor("text"))

    b._style = style or "DARK"

    local function ApplyNormal(selfBtn)
        if selfBtn._style == "ACCENT" then
            selfBtn:SetBackdropColor(T:GetColor("accentSoft"))
            selfBtn:SetBackdropBorderColor(T:GetColor("borderStrong"))
            selfBtn.LeftAccent:SetColorTexture(T:GetColor("accentBlue"))
            selfBtn.Text:SetTextColor(T:GetColor("accent"))
        elseif selfBtn._style == "BLUE" then
            selfBtn:SetBackdropColor(T:GetColor("accentBlueSoft"))
            selfBtn:SetBackdropBorderColor(T:GetColor("accentBlue"))
            selfBtn.LeftAccent:SetColorTexture(T:GetColor("accentBlue"))
            selfBtn.Text:SetTextColor(T:GetColor("text"))
        elseif selfBtn._style == "DANGER" then
            selfBtn:SetBackdropColor(0.30, 0.10, 0.10, 0.92)
            selfBtn:SetBackdropBorderColor(0.90, 0.28, 0.28, 0.55)
            selfBtn.LeftAccent:SetColorTexture(1.00, 0.35, 0.35, 0.85)
            selfBtn.Text:SetTextColor(1, 0.92, 0.92, 1)
        else
            selfBtn:SetBackdropColor(T:GetColor("darkButton"))
            selfBtn:SetBackdropBorderColor(T:GetColor("border"))
            selfBtn.LeftAccent:SetColorTexture(0.30, 0.72, 1.00, 0.18)
            selfBtn.Text:SetTextColor(T:GetColor("text"))
        end
    end

    local function ApplyHover(selfBtn)
        if selfBtn._style == "ACCENT" then
            selfBtn:SetBackdropColor(T:GetColor("accentBlueSoft"))
            selfBtn:SetBackdropBorderColor(T:GetColor("borderStrong"))
            selfBtn.LeftAccent:SetColorTexture(1.00, 1.00, 1.00, 0.95)
            selfBtn.Text:SetTextColor(1, 1, 1, 1)
        elseif selfBtn._style == "BLUE" then
            selfBtn:SetBackdropColor(0.18, 0.32, 0.48, 0.95)
            selfBtn:SetBackdropBorderColor(T:GetColor("accentBlue"))
            selfBtn.LeftAccent:SetColorTexture(1.00, 1.00, 1.00, 0.95)
            selfBtn.Text:SetTextColor(1, 1, 1, 1)
        elseif selfBtn._style == "DANGER" then
            selfBtn:SetBackdropColor(0.45, 0.12, 0.12, 0.95)
            selfBtn:SetBackdropBorderColor(1, 0.35, 0.35, 0.80)
            selfBtn.LeftAccent:SetColorTexture(1.00, 1.00, 1.00, 0.95)
            selfBtn.Text:SetTextColor(1, 1, 1, 1)
        else
            selfBtn:SetBackdropColor(T:GetColor("darkButtonHover"))
            selfBtn:SetBackdropBorderColor(T:GetColor("borderStrong"))
            selfBtn.LeftAccent:SetColorTexture(T:GetColor("accentBlue"))
            selfBtn.Text:SetTextColor(1, 1, 1, 1)
        end
    end

    ApplyNormal(b)

    b:SetScript("OnEnter", function(selfBtn)
        ApplyHover(selfBtn)
    end)

    b:SetScript("OnLeave", function(selfBtn)
        ApplyNormal(selfBtn)
    end)

    b:SetScript("OnMouseDown", function(selfBtn)
        selfBtn:SetBackdropColor(T:GetColor("darkButtonPress"))
    end)

    b:SetScript("OnMouseUp", function(selfBtn)
        ApplyHover(selfBtn)
    end)

    if onClick then
        b:SetScript("OnClick", onClick)
    end

    return b
end

function T:CreateSection(parent, titleText, width)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(width or 660, 30)

    f.accent = f:CreateTexture(nil, "ARTWORK")
    f.accent:SetPoint("LEFT", 0, 0)
    f.accent:SetSize(3, 16)
    f.accent:SetColorTexture(self:GetColor("accentBlue"))

    f.title = self:CreateText(f, titleText or "", "GameFontNormalLarge", "accent")
    f.title:SetPoint("LEFT", f.accent, "RIGHT", 8, 0)

    f.line = f:CreateTexture(nil, "ARTWORK")
    f.line:SetPoint("LEFT", f.title, "RIGHT", 8, 0)
    f.line:SetPoint("RIGHT", 0, 0)
    f.line:SetHeight(1)
    local r, g, b = self:GetColor("accentBlue")
    f.line:SetColorTexture(r, g, b, 0.25)

    return f
end

function T:CreateCard(parent, width, height)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(width or 320, height or 120)
    self:ApplyBackdrop(f, "panel", "border")
    return f
end

function T:StyleScrollBar(scrollFrame)
    if not scrollFrame or not scrollFrame.ScrollBar then return end
    local sb = scrollFrame.ScrollBar
    if sb._dmtStyled then return end
    sb._dmtStyled = true

    if sb.Track and sb.Track.SetAlpha then
        sb.Track:SetAlpha(0.15)
    end
    if sb.Back and sb.Back.SetAlpha then
        sb.Back:SetAlpha(0.30)
    end
    if sb.Forward and sb.Forward.SetAlpha then
        sb.Forward:SetAlpha(0.30)
    end
    if sb.ThumbTexture and sb.ThumbTexture.SetVertexColor then
        sb.ThumbTexture:SetVertexColor(self:GetColor("accentBlue"))
    end
end

function T:CreateCheckButton(parent, labelText)
    local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    cb:SetSize(280, 24)

    cb.box = CreateFrame("Frame", nil, cb, "BackdropTemplate")
    cb.box:SetSize(16, 16)
    cb.box:SetPoint("LEFT", 0, 0)
    self:ApplyBackdrop(cb.box, "darkButton", "border")

    cb.check = cb.box:CreateTexture(nil, "OVERLAY")
    cb.check:SetPoint("TOPLEFT", 3, -3)
    cb.check:SetPoint("BOTTOMRIGHT", -3, 3)
    cb.check:SetColorTexture(self:GetColor("accentBlue"))
    cb.check:Hide()

    cb.label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    cb.label:SetPoint("LEFT", cb.box, "RIGHT", 8, 0)
    cb.label:SetJustifyH("LEFT")
    cb.label:SetText(labelText or "")
    cb.label:SetTextColor(self:GetColor("text"))

    function cb:RefreshVisual()
        if self:GetChecked() then
            self.box:SetBackdropColor(T:GetColor("accentBlueSoft"))
            self.box:SetBackdropBorderColor(T:GetColor("accentBlue"))
            self.check:Show()
            self.label:SetTextColor(T:GetColor("text"))
        else
            self.box:SetBackdropColor(T:GetColor("darkButton"))
            self.box:SetBackdropBorderColor(T:GetColor("border"))
            self.check:Hide()
            self.label:SetTextColor(T:GetColor("text"))
        end
    end

    cb:SetScript("OnEnter", function(selfBtn)
        selfBtn.box:SetBackdropBorderColor(T:GetColor("accentBlue"))
        selfBtn.label:SetTextColor(1, 1, 1, 1)
    end)

    cb:SetScript("OnLeave", function(selfBtn)
        selfBtn:RefreshVisual()
    end)

    cb:SetScript("OnShow", function(selfBtn)
        selfBtn:RefreshVisual()
    end)

    return cb
end

function T:SetEnabled(widget, enabled)
    if not widget then return end
    enabled = enabled and true or false

    if widget.Enable then
        if enabled then widget:Enable() end
    end

    if widget.Disable and not enabled then
        widget:Disable()
    end

    if widget.SetEnabled then
        widget:SetEnabled(enabled)
    end

    if widget.SetAlpha then
        widget:SetAlpha(enabled and 1 or 0.45)
    end

    if widget.Text and widget.Text.SetTextColor then
        if enabled then
            widget.Text:SetTextColor(self:GetColor("text"))
        else
            widget.Text:SetTextColor(self:GetColor("textDim"))
        end
    end

    if widget.label and widget.label.SetTextColor then
        if enabled then
            widget.label:SetTextColor(self:GetColor("text"))
        else
            widget.label:SetTextColor(self:GetColor("textDim"))
        end
    end
end

T:ApplyStyle(T:GetStyleKey())