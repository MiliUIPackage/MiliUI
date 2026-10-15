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

local Picker = {}
GUI2.ColorPicker = Picker
local LIMIT, UNDO_LIMIT = 10, 30
local floor, min, max = math.floor, math.min, math.max
local unpack = unpack or table.unpack

local function T(key)
    return YUI.Locale:Get("Core")[key]
end

local function Clamp(value, upper)
    value = tonumber(value) or 0
    if value ~= value then value = 0 end
    return max(0, min(upper or 1, value))
end

local function Copy(c)
    return { c[1], c[2], c[3], c[4] }
end

local function Color(r, g, b, a)
    return { Clamp(r), Clamp(g), Clamp(b), a == nil and 1 or Clamp(a) }
end

local function Byte(value)
    return floor(Clamp(value) * 255 + 0.5)
end

local function Hex(c)
    return string.format("%02X%02X%02X", Byte(c[1]), Byte(c[2]), Byte(c[3]))
end

local function Same(a, b, hasAlpha)
    return Hex(a) == Hex(b) and (hasAlpha == false
        or floor(a[4] * 100 + 0.5) == floor(b[4] * 100 + 0.5))
end

local function RGBToHSV(r, g, b, previousHue)
    local hi, lo = max(r, g, b), min(r, g, b)
    local delta, h = hi - lo, previousHue or 0
    if delta > 0 then
        if hi == r then h = ((g - b) / delta) % 6
        elseif hi == g then h = (b - r) / delta + 2
        else h = (r - g) / delta + 4 end
        h = h / 6
    end
    return h, hi == 0 and 0 or delta / hi, hi
end

local function HSVToRGB(h, s, v)
    h = (h % 1) * 6
    local segment, f = floor(h), h % 1
    local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    if segment == 0 then return v, t, p end
    if segment == 1 then return q, v, p end
    if segment == 2 then return p, v, t end
    if segment == 3 then return p, q, v end
    if segment == 4 then return t, p, v end
    return v, p, q
end

local function ParseHex(text, a)
    text = tostring(text or ""):match("^%s*#?(%x%x%x%x%x%x)%s*$")
    if not text then return nil end
    return Color(tonumber(text:sub(1, 2), 16) / 255,
        tonumber(text:sub(3, 4), 16) / 255, tonumber(text:sub(5, 6), 16) / 255, a)
end

local function Valid(c)
    if type(c) ~= "table" then return false end
    for i = 1, 4 do
        if type(c[i]) ~= "number" or c[i] ~= c[i] or c[i] < 0 or c[i] > 1 then return false end
    end
    return true
end

-- This account-level library belongs to the loaded core, never to a profile.
function Picker:GetLibrary()
    local global = YUI.DB and YUI.DB:GetGlobal(YUI.CoreMode == "suite" and "suite" or YUI.ProductId)
    if not global then return nil end
    if type(global.colorPicker) ~= "table" then global.colorPicker = {} end
    local library = global.colorPicker
    if library ~= self.library then
        for _, field in ipairs({ "favorites", "recent", "removed" }) do
            local source, clean = library[field], {}
            if type(source) == "table" then
                local limit = field == "removed" and UNDO_LIMIT or LIMIT
                for _, c in ipairs(source) do
                    if Valid(c) and #clean < limit then
                        local copy = Copy(c)
                        if field == "removed" then copy.index = max(1, floor(Clamp(c.index or 1, LIMIT))) end
                        clean[#clean + 1] = copy
                    end
                end
            end
            library[field] = clean
        end
        self.library = library
    end
    return library
end

function Picker:AddFavorite(c)
    local db = self:GetLibrary()
    if not db then return false end
    for _, old in ipairs(db.favorites) do if Same(old, c, self.hasAlpha) then return false end end
    if #db.favorites >= LIMIT then return false end
    db.favorites[#db.favorites + 1] = Copy(c)
    return true
end

function Picker:RemoveFavorite(index)
    local db = self:GetLibrary()
    if not db or not db.favorites[index] then return false end
    local c = table.remove(db.favorites, index)
    c.index = index
    db.removed[#db.removed + 1] = c
    if #db.removed > UNDO_LIMIT then table.remove(db.removed, 1) end
    return true
end

function Picker:UndoRemove()
    local db = self:GetLibrary()
    local c = db and db.removed[#db.removed]
    if not c then return false end
    for _, old in ipairs(db.favorites) do
        if Same(old, c, true) then table.remove(db.removed); return true end
    end
    if #db.favorites >= LIMIT then return false, "full" end
    table.remove(db.removed)
    table.insert(db.favorites, min(c.index or (#db.favorites + 1), #db.favorites + 1), Copy(c))
    return true
end

function Picker:RecordRecent(c)
    local db = self:GetLibrary()
    if not db then return end
    for i = #db.recent, 1, -1 do
        if Same(db.recent[i], c, true) then table.remove(db.recent, i) end
    end
    table.insert(db.recent, 1, Copy(c))
    if #db.recent > LIMIT then table.remove(db.recent) end
end

function Picker:IsShown()
    return self.owner ~= nil
end

-- Keep the originating controls alive while their live setters update the view.
-- At most one rebuild per settings container; no polling timer is needed.
function Picker:DeferRefresh(container, refresh)
    if not container then return false end
    local parent = self.owner or self.closingOwner
    while parent do
        if parent == container then
            self.deferredRefresh = self.deferredRefresh or {}
            self.deferredRefresh[container] = refresh
            return true
        end
        parent = parent.GetParent and parent:GetParent()
    end
    return false
end

function Picker:SetSample(r, g, b, a, keepHSV)
    if not self.owner then return end
    r, g, b = Clamp(r), Clamp(g), Clamp(b)
    a = self.hasAlpha and Clamp(a == nil and self.value[4] or a) or 1
    local c = self.value
    local changed = c[1] ~= r or c[2] ~= g or c[3] ~= b or c[4] ~= a
    c[1], c[2], c[3], c[4] = r, g, b, a
    if not keepHSV then self.h, self.s, self.v = RGBToHSV(r, g, b, self.h) end
    if self.frame then self:Refresh() end
    if changed and self.preview then self.preview(r, g, b, a) end
end

function Picker:Close(action)
    if not self.owner then return false end
    if action == "confirm" and self.frame and not self:FlushInputs() then return false end
    local callback = action == "confirm" and self.commit
        or action ~= "abandon" and self.cancel or nil
    local owner, c = self.owner, self.value
    self.closingOwner = owner
    self.owner, self.preview, self.commit, self.cancel = nil, nil, nil, nil
    self.drag = nil
    if self.frame then
        self.frame:SetScript("OnUpdate", nil)
        self.frame:StopMovingOrSizing()
        self.frame:Hide()
    end
    if action == "confirm" then self:RecordRecent(c) end
    if action == "abandon" then owner.gui2ColorPreviewActive = false end
    if callback then callback() end
    local deferred = self.deferredRefresh
    self.deferredRefresh, self.closingOwner = nil, nil
    if action ~= "abandon" and deferred then
        for container, refresh in pairs(deferred) do
            if container:IsVisible() then refresh() end
        end
    end
    return true
end

local function Texture(parent, layer)
    return GUI2:CreateTexture(parent, { layer = layer or "ARTWORK" })
end

local function Gradient(texture, direction, r1, g1, b1, a1, r2, g2, b2, a2)
    texture:SetColorTexture(1, 1, 1, 1)
    texture:SetGradient(direction, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
end

local function Label(parent, text, x, y)
    local label = GUI2:CreateText(parent, text, "font.size.sm", "color.text.secondary")
    label:SetPoint("TOPLEFT", x, -y)
    return label
end

local function Hint(frame, key)
    frame:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(T(key), 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Checker(parent, width, height)
    local cells = {}
    -- A fixed, bounded grid; created once and reused with the popup.
    for y = 0, math.ceil(height / 8) - 1 do
        for x = 0, math.ceil(width / 8) - 1 do
            local t = Texture(parent, "BACKGROUND")
            t:SetPoint("TOPLEFT", x * 8, -y * 8)
            t:SetSize(min(8, width - x * 8), min(8, height - y * 8))
            GUI2:SetTexturePaintKey(t, (x + y) % 2 == 0 and "color.control.bg" or "color.border.default")
            cells[#cells + 1] = t
        end
    end
    return cells
end

local function Button(parent, text, x, y, width, callback, tone)
    local b = GUI2.Form:CreateButton(parent, { text = text, width = width, height = 26, tone = tone or "default", onClick = callback })
    b:SetPoint("TOPLEFT", x, -y)
    return b
end

function Picker:ApplyInput(input)
    if not self.owner or self.refreshing or not input.dirty then return true end
    local c
    if input.channel == "hex" then
        c = ParseHex(input:GetText(), self.value[4])
    else
        local n = tonumber(input:GetText())
        local upper = input.channel == 4 and 100 or 255
        if n and n == n and n >= 0 and n <= upper then
            c = Copy(self.value)
            c[input.channel] = n / upper
        end
    end
    if not c then
        GUI2:SetBorderColor(input.gui2Bg, "color.border.accent")
        self:SetMessage(T("color.picker.invalid"))
        return false
    end
    input.dirty = nil
    self:SetMessage("")
    self:SetSample(unpack(c))
    return true
end

function Picker:FlushInputs()
    for _, input in ipairs(self.frame.inputs) do
        if not self:ApplyInput(input) then input:SetFocus(); return false end
    end
    return true
end

function Picker:SampleCursor()
    local target = self.drag
    if not target or not self.owner then return end
    local x, y = GetCursorPosition()
    local scale = target:GetEffectiveScale()
    x = Clamp((x / scale - target:GetLeft()) / target:GetWidth())
    y = Clamp((y / scale - target:GetBottom()) / target:GetHeight())
    if target.channel == "sv" then self.s, self.v = x, y
    elseif target.channel == "hue" then self.h = min(1 - y, 0.999999)
    else
        self:SetSample(self.value[1], self.value[2], self.value[3], x, true)
        return
    end
    local r, g, b = HSVToRGB(self.h, self.s, self.v)
    self:SetSample(r, g, b, self.value[4], true)
end

function Picker:GetFrame()
    if self.frame then return self.frame end
    local frame = GUI2:CreatePanel(UIParent, { width = 360, height = 370,
        surface = "color.surface.popup", border = "color.popup.border", hidden = true })
    self.frame = frame
    frame:SetFrameStrata("TOOLTIP")
    frame:SetFrameLevel(9800)
    frame:SetToplevel(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    local title = GUI2:CreateButtonFrame(frame, { width = 315, height = 34 })
    title:SetPoint("TOPLEFT", 0, 0)
    title:RegisterForDrag("LeftButton")
    title:SetScript("OnDragStart", function() frame:StartMoving() end)
    title:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    frame.title = GUI2:CreateText(title, T("color.picker.title"), "font.size.md", "color.text.accent")
    frame.title:SetPoint("TOPLEFT", 14, -10)
    frame.close = GUI2:CreateCloseButton(frame, function() self:Close("cancel") end)
    frame.close:SetPoint("TOPRIGHT", -8, -8)
    GUI2:EnableEscapeClose(frame, function() self:Close("cancel") end)
    frame:SetScript("OnHide", function()
        self:Close("cancel")
        GameTooltip:Hide()
    end)

    local function Pad(channel, x, y, width, height)
        local pad = GUI2:CreateButtonFrame(frame, { width = width, height = height })
        pad.channel = channel
        pad:SetPoint("TOPLEFT", x, -y)
        pad:SetScript("OnMouseDown", function(_, button)
            if button ~= "LeftButton" or not self:FlushInputs() then return end
            for _, input in ipairs(frame.inputs) do input:ClearFocus() end
            self.drag = pad
            self:SampleCursor()
            frame:SetScript("OnUpdate", function()
                if not self.owner or not IsMouseButtonDown("LeftButton") then
                    self.drag = nil
                    frame:SetScript("OnUpdate", nil)
                    return
                end
                self:SampleCursor()
            end)
        end)
        pad:SetScript("OnMouseUp", function()
            self.drag = nil
            frame:SetScript("OnUpdate", nil)
        end)
        return pad
    end

    frame.sv = Pad("sv", 14, 38, 180, 132)
    frame.hue = Pad("hue", 202, 38, 14, 132)
    frame.alpha = Pad("alpha", 14, 232, 332, 12)
    Checker(frame.alpha, 332, 12)
    frame.alpha.texture = Texture(frame.alpha)
    frame.alpha.texture:SetAllPoints()
    Hint(frame.alpha, "color.picker.alpha_hint")
    frame.sv.texture = Texture(frame.sv, "BACKGROUND")
    frame.sv.texture:SetAllPoints()
    local white = Texture(frame.sv)
    white:SetAllPoints()
    Gradient(white, "HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 0)
    local black = Texture(frame.sv, "OVERLAY")
    black:SetAllPoints()
    Gradient(black, "VERTICAL", 0, 0, 0, 1, 0, 0, 0, 0)
    for i = 0, 5 do
        local strip = Texture(frame.hue)
        strip:SetPoint("TOPLEFT", 0, -i * 22)
        strip:SetSize(14, 22)
        local r1, g1, b1 = HSVToRGB((i + 1) / 6, 1, 1)
        local r2, g2, b2 = HSVToRGB(i / 6, 1, 1)
        Gradient(strip, "VERTICAL", r1, g1, b1, 1, r2, g2, b2, 1)
    end
    for _, pad in ipairs({ frame.sv, frame.hue, frame.alpha }) do
        local marker = GUI2:CreateButtonFrame(pad, { width = pad == frame.sv and 9 or pad == frame.hue and 22 or 5,
            height = pad == frame.sv and 9 or pad == frame.hue and 4 or 18 })
        GUI2:CreateBorder(marker, "color.text.primary")
        marker:SetFrameLevel(pad:GetFrameLevel() + 3)
        marker:EnableMouse(false)
        pad.marker = marker
    end

    frame.originalLabel = Label(frame, T("color.picker.original"), 228, 38)
    frame.newLabel = Label(frame, T("color.picker.new"), 290, 38)
    for index, x in ipairs({ 228, 290 }) do
        local sample = GUI2:CreateButtonFrame(frame, { width = 56, height = 34 })
        sample:SetPoint("TOPLEFT", x, -58)
        Checker(sample, 56, 34)
        sample.texture = Texture(sample)
        sample.texture:SetAllPoints()
        if index == 1 then
            frame.original = sample
            sample:SetScript("OnClick", function() self:ChooseColor(self.original) end)
            Hint(sample, "color.picker.restore_original")
        else frame.current = sample end
    end
    frame.inputs, frame.channels, frame.channelLabels = {}, {}, {}
    local function Input(channel, label, x, y, width)
        local labelFrame = Label(frame, label, x, y)
        local edit = GUI2.Form:CreateEditBox(frame, { width = width, height = 27 })
        edit.channel = channel
        edit:SetPoint("TOPLEFT", x, -y - 18)
        edit:SetJustifyH("CENTER")
        edit:SetMaxLetters(channel == "hex" and 7 or 5)
        edit:HookScript("OnTextChanged", function(_, userInput)
            if userInput and not self.refreshing then edit.dirty = true end
        end)
        edit:HookScript("OnEditFocusLost", function() self:ApplyInput(edit) end)
        edit:SetScript("OnEnterPressed", function()
            if self:ApplyInput(edit) then edit:ClearFocus() end
        end)
        edit:SetScript("OnEscapePressed", function() self:Close("cancel") end)
        frame.inputs[#frame.inputs + 1] = edit
        return edit, labelFrame
    end
    frame.hex = Input("hex", "HEX", 228, 110, 118)
    for i, text in ipairs({ "R", "G", "B", "A (%)" }) do
        frame.channels[i], frame.channelLabels[i] = Input(i, text, 14 + (i - 1) * 85, 182, 77)
    end
    Hint(frame.channels[4], "color.picker.alpha_hint")
    frame.favoriteLabel = Label(frame, T("color.picker.favorites"), 14, 250)
    frame.recentLabel = Label(frame, T("color.picker.recent"), 14, 300)
    frame.undo = GUI2:CreateButtonFrame(frame, { width = 110, height = 20 })
    frame.undo.text = GUI2:CreateText(frame.undo, T("color.picker.undo"), "font.size.sm", "color.text.accent")
    frame.undo.text:SetPoint("RIGHT", 0, 0)
    frame.undo:SetScript("OnEnter", function() GUI2:SetTextColorKey(frame.undo.text, "color.text.primary") end)
    frame.undo:SetScript("OnLeave", function() GUI2:SetTextColorKey(frame.undo.text, "color.text.accent") end)
    frame.undo:SetScript("OnClick", function()
        local _, reason = self:UndoRemove()
        self:SetMessage(reason == "full" and T("color.picker.full") or "")
        self:RefreshLibrary()
    end)
    frame.rows = { favorites = {}, recent = {} }
    for name, row in pairs(frame.rows) do
        for i = 1, LIMIT do
            local b = GUI2:CreateButtonFrame(frame, { width = 26, height = 24 })
            GUI2:CreateBorder(b, "color.border.default")
            b:SetPoint("TOPLEFT", 14 + (i - 1) * 34, name == "favorites" and -264 or -314)
            b.checker = Checker(b, 26, 24)
            b.texture = Texture(b)
            b.texture:SetAllPoints()
            b.selection = GUI2:CreateText(b, "+", "font.size.lg", "color.text.primary")
            b.selection:SetPoint("CENTER")
            b:SetScript("OnClick", function(_, mouseButton)
                if b.add then self:AddFavorite(self.value)
                elseif name == "favorites" and mouseButton == "RightButton" then self:RemoveFavorite(b.index)
                elseif b.color then self:ChooseColor(b.color) end
                self:RefreshLibrary()
            end)
            b:SetScript("OnEnter", function()
                GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                if b.add then GameTooltip:SetText(T("color.picker.add"))
                elseif b.color then
                    GameTooltip:SetText("#" .. Hex(b.color))
                    if self.hasAlpha then GameTooltip:AddLine("A: " .. floor(b.color[4] * 100 + 0.5) .. "%") end
                    if name == "favorites" then GameTooltip:AddLine(T("color.picker.remove_hint")) end
                end
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            row[i] = b
        end
    end
    frame.message = Label(frame, "", 14, 350)
    frame.message:SetWidth(332)
    frame.message:SetWordWrap(false)
    frame.reset = GUI2.Form:CreateTextLink(frame, {
        text = T("color.picker.default"), width = 116, height = 26,
        colorKey = "color.text.secondary", hoverColorKey = "color.text.primary",
        onClick = function() if self.default then self:ChooseColor(self.default) end end,
    })
    frame.reset.text:ClearAllPoints()
    frame.reset.text:SetPoint("LEFT", 0, 0)
    frame.reset.underline:Hide()
    frame.cancel = Button(frame, T("common.cancel"), 198, 350, 68, function() self:Close("cancel") end)
    frame.confirm = Button(frame, T("common.confirm"), 274, 350, 72, function()
        if self:FlushInputs() then self:Close("confirm") end
    end, "accent")
    GUI2.Form:StyleDialogPrimary(frame.confirm)
    frame.confirm:SetHeight(26)
    return frame
end

function Picker:LayoutFooter()
    local frame = self.frame
    local db = self:GetLibrary()
    local hasRecent = db and #db.recent > 0
    frame.recentLabel:SetShown(hasRecent)
    local y = 348 - (self.hasAlpha and -12 or 24) - (hasRecent and 0 or 50)
    frame.message:ClearAllPoints()
    frame.message:SetPoint("TOPLEFT", 14, -y)
    local hasMessage = frame.message:GetText() ~= ""
    frame.message:SetShown(hasMessage)
    if hasMessage then y = y + 20 end
    for _, spec in ipairs({ {frame.reset,14}, {frame.cancel,198}, {frame.confirm,274} }) do
        spec[1]:ClearAllPoints(); spec[1]:SetPoint("TOPLEFT", spec[2], -y)
    end
    frame:SetHeight(y + 38)
end

function Picker:SetMessage(text)
    self.frame.message:SetText(text)
    self:LayoutFooter()
end

function Picker:RefreshLibrary()
    local frame, db = self.frame, self:GetLibrary()
    if not frame or not db then return end
    local already = false
    for _, c in ipairs(db.favorites) do if Same(c, self.value, self.hasAlpha) then already = true end end
    for name, row in pairs(frame.rows) do
        local data, visible = db[name], 0
        local seen = {}
        for index, c in ipairs(data) do
            local key = Hex(c)
            if self.hasAlpha or not seen[key] then
                seen[key] = true
                visible = visible + 1
                local b = row[visible]
                b.add, b.color, b.index = false, c, index
                b.texture:SetColorTexture(c[1], c[2], c[3], self.hasAlpha and c[4] or 1)
                b.texture:Show()
                b.selection:SetText("")
                for _, cell in ipairs(b.checker) do cell:Show() end
                b:SetAlpha(1)
                b:Enable()
                b:Show()
            end
        end
        if name == "favorites" and #data < LIMIT then
            visible = visible + 1
            local b = row[visible]
            b.add, b.color = true, nil
            b.texture:Hide()
            for _, cell in ipairs(b.checker) do cell:Hide() end
            b.selection:SetText("+")
            if already then b:Disable() else b:Enable() end
            b:SetAlpha(already and 0.35 or 1)
            b:Show()
        end
        for i = visible + 1, LIMIT do
            row[i].add, row[i].color, row[i].index = nil, nil, nil
            row[i]:Hide()
        end
    end
    frame.undo:SetShown(#db.removed > 0)
    self:RefreshSelection()
    self:LayoutFooter()
end

function Picker:RefreshSelection()
    local frame, already = self.frame, false
    for _, button in ipairs(frame.rows.favorites) do
        if button.color and Same(button.color, self.value, self.hasAlpha) then already = true end
    end
    for _, row in pairs(frame.rows) do
        for _, button in ipairs(row) do
            if button:IsShown() then
                if button.add then
                    GUI2:SetBorderColor(button, "color.border.default")
                    if already then button:Disable() else button:Enable() end
                    button:SetAlpha(already and 0.35 or 1)
                else
                    button.selection:SetText("")
                    GUI2:SetBorderColor(button, button.color and Same(button.color, self.value, self.hasAlpha)
                        and "color.text.primary" or "color.border.default")
                end
            end
        end
    end
end

function Picker:ChooseColor(c)
    for _, input in ipairs(self.frame.inputs) do input.dirty = nil end
    self:SetMessage("")
    self:SetSample(unpack(c))
end

function Picker:Refresh()
    local frame, c = self.frame, self.value
    self.refreshing = true
    local r, g, b = HSVToRGB(self.h, 1, 1)
    frame.sv.texture:SetColorTexture(r, g, b, 1)
    frame.sv.marker:ClearAllPoints()
    frame.sv.marker:SetPoint("CENTER", frame.sv, "BOTTOMLEFT", self.s * frame.sv:GetWidth(), self.v * frame.sv:GetHeight())
    frame.hue.marker:ClearAllPoints()
    frame.hue.marker:SetPoint("CENTER", frame.hue, "TOP", 0, -self.h * frame.hue:GetHeight())
    frame.alpha.marker:ClearAllPoints()
    frame.alpha.marker:SetPoint("CENTER", frame.alpha, "LEFT", c[4] * frame.alpha:GetWidth(), 0)
    Gradient(frame.alpha.texture, "HORIZONTAL", c[1], c[2], c[3], 0, c[1], c[2], c[3], 1)
    frame.original.texture:SetColorTexture(unpack(self.original))
    frame.current.texture:SetColorTexture(unpack(c))
    if not frame.hex.dirty then frame.hex:SetText("#" .. Hex(c)) end
    for i, edit in ipairs(frame.channels) do
        if not edit.dirty then edit:SetText(i == 4 and floor(c[4] * 100 + 0.5) or Byte(c[i])) end
    end
    self:RefreshSelection()
    self.refreshing = false
end

function Picker:Open(owner, options)
    self:Close("cancel")
    local frame = self:GetFrame()
    self.owner, self.hasAlpha = owner, options.hasAlpha ~= false
    self.value = Color(options.r, options.g, options.b, self.hasAlpha and options.a or 1)
    self.original = Copy(self.value)
    self.default = options.default
    self.preview, self.commit, self.cancel = options.preview, options.commit, options.cancel
    self.h, self.s, self.v = RGBToHSV(self.value[1], self.value[2], self.value[3])
    frame.alpha:SetShown(self.hasAlpha)
    frame.channels[4]:SetShown(self.hasAlpha)
    frame.channelLabels[4]:SetShown(self.hasAlpha)
    local count = self.hasAlpha and 4 or 3
    local width = (332 - (count - 1) * 8) / count
    for i = 1, count do
        local edit, label = frame.channels[i], frame.channelLabels[i]
        edit:ClearAllPoints(); label:ClearAllPoints()
        edit:SetWidth(width)
        label:SetPoint("TOPLEFT", 14 + (i - 1) * (width + 8), -182)
        edit:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -5)
    end
    local offset = self.hasAlpha and -12 or 24
    frame.favoriteLabel:ClearAllPoints(); frame.favoriteLabel:SetPoint("TOPLEFT", 14, -250 + offset)
    frame.recentLabel:ClearAllPoints(); frame.recentLabel:SetPoint("TOPLEFT", 14, -300 + offset)
    frame.undo:ClearAllPoints(); frame.undo:SetPoint("TOPRIGHT", -14, -246 + offset)
    for name, row in pairs(frame.rows) do
        for i, button in ipairs(row) do
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", 14 + (i - 1) * 34, (name == "favorites" and -264 or -314) + offset)
        end
    end
    frame.reset:SetShown(self.default ~= nil)
    frame.message:SetText("")
    for _, input in ipairs(frame.inputs) do input.dirty = nil; input:ClearFocus() end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -6)
    self:RefreshLibrary()
    self:Refresh()
    frame:Show()
    frame:Raise()
end

-- Pure conversions are also used by the focused Lua regression harness.
Picker.Model = { Color = Color, Hex = Hex, ParseHex = ParseHex, RGBToHSV = RGBToHSV, HSVToRGB = HSVToRGB }
