local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs

-------------------------------------------------
-- click-casting hints
-------------------------------------------------
--! A read-only reminder bar: every Click-Casting whose type is "spell" shows up
--! as an icon carrying its key combo and its cooldown. Nothing here touches a
--! unit token -- the spell ids come straight out of CellDB and the cooldown is
--! the player's own -- so the 12.1 secret-value rules mostly do not apply. The
--! one place they do is the cooldown itself: it is armed from the engine's own
--! duration object instead of a start/duration pair, which keeps working while
--! the player is in combat. See .claude/notes/wow-121-duration-objects.md.
--!
--! The bar is deliberately mouse-transparent. It sits in the middle of the
--! screen next to the raid frames and swallowing clicks there would be worse
--! than the tooltip it gives up.

local GetSpellCooldownDuration = C_Spell and C_Spell.GetSpellCooldownDuration

local ceil, floor, max, min = math.ceil, math.floor, math.max, math.min

local MOVER_MIN_WIDTH, MOVER_MIN_HEIGHT = 60, 20

-------------------------------------------------
-- frame
-------------------------------------------------
local hintsFrame = CreateFrame("Frame", "CellClickCastingHintsFrame", Cell.frames.mainFrame, "BackdropTemplate")
Cell.frames.clickCastingHintsFrame = hintsFrame
P.Size(hintsFrame, 100, 24)
PixelUtil.SetPoint(hintsFrame, "TOPLEFT", CellParent, "CENTER", 1, -1)
hintsFrame:SetClampedToScreen(true)
hintsFrame:SetMovable(true)
hintsFrame:RegisterForDrag("LeftButton")
hintsFrame:EnableMouse(false)
hintsFrame:Hide()

hintsFrame:SetScript("OnDragStart", function()
    hintsFrame:StartMoving()
    hintsFrame:SetUserPlaced(false)
end)
hintsFrame:SetScript("OnDragStop", function()
    hintsFrame:StopMovingOrSizing()
    P.SavePosition(hintsFrame, CellDB["tools"]["clickCastingHints"]["position"])
end)

-- the label floats above the bar so the frame stays exactly as big as the icons
hintsFrame.moverText = hintsFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
hintsFrame.moverText:SetPoint("BOTTOM", hintsFrame, "TOP", 0, 2)
hintsFrame.moverText:SetText(L["Mover"])
hintsFrame.moverText:Hide()

-------------------------------------------------
-- key abbreviations
-------------------------------------------------
--! bindKey comes from Cell.CreateBindingButton: mouse buttons are "Left" /
--! "Right" / "Middle" / "ButtonN", the wheel is "ScrollUp" / "ScrollDown" and
--! everything else is a raw WoW key name ("F", "1", "F1", "NUMPAD1", "SPACE").
--! Mouse "Left" and arrow key "LEFT" only differ in case, so the table below
--! must stay case-sensitive.
local KEY_ABBR = {
    ["Left"] = "L",
    ["Right"] = "R",
    ["Middle"] = "M",
    ["ScrollUp"] = "WU",
    ["ScrollDown"] = "WD",

    ["SPACE"] = "SP",
    ["TAB"] = "TAB",
    ["ESCAPE"] = "ESC",
    ["ENTER"] = "EN",
    ["BACKSPACE"] = "BS",
    ["CAPSLOCK"] = "CAP",
    ["INSERT"] = "INS",
    ["DELETE"] = "DEL",
    ["HOME"] = "HM",
    ["END"] = "ED",
    ["PAGEUP"] = "PU",
    ["PAGEDOWN"] = "PD",
    ["UP"] = "↑",
    ["DOWN"] = "↓",
    ["LEFT"] = "←",
    ["RIGHT"] = "→",
}

local function AbbrevKey(key)
    if KEY_ABBR[key] then return KEY_ABBR[key] end

    local n = strmatch(key, "^Button(%d+)$")
    if n then return "B" .. n end

    n = strmatch(key, "^NUMPAD(.+)$")
    if n then return "N" .. n end

    return key
end

--! Modifiers are greyed so the key itself still reads at 24px.
local function GetKeyDisplay(modifier, key)
    local mods = ""
    if strfind(modifier, "alt") then mods = mods .. "A" end
    if strfind(modifier, "ctrl") then mods = mods .. "C" end
    if strfind(modifier, "shift") then mods = mods .. "S" end
    if strfind(modifier, "meta") then mods = mods .. "M" end

    if mods == "" then
        return AbbrevKey(key)
    end
    return "|cff909090" .. mods .. "|r" .. AbbrevKey(key)
end

-------------------------------------------------
-- icons
-------------------------------------------------
local icons = {}
local shown = 0

local function CreateHintIcon()
    local icon = CreateFrame("Frame", nil, hintsFrame, "BackdropTemplate")
    icon:SetFrameLevel(hintsFrame:GetFrameLevel() + 1)
    icon:SetBackdrop({edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(1)})
    icon:SetBackdropBorderColor(0, 0, 0, 1)

    icon.tex = icon:CreateTexture(nil, "ARTWORK")
    P.Point(icon.tex, "TOPLEFT", icon, "TOPLEFT", 1, -1)
    P.Point(icon.tex, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", -1, 1)
    icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    icon.cooldown = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
    icon.cooldown:SetAllPoints(icon.tex)
    icon.cooldown:SetFrameLevel(icon:GetFrameLevel() + 1)
    icon.cooldown:SetDrawEdge(false)
    icon.cooldown:SetDrawBling(false)
    icon.cooldown:SetHideCountdownNumbers(false)

    --! The key text lives on its own frame stacked above the cooldown: a child
    --! frame always draws over the parent's layers, so a FontString on `icon`
    --! would end up underneath the swipe no matter which draw layer it used.
    icon.overlay = CreateFrame("Frame", nil, icon)
    icon.overlay:SetAllPoints(icon)
    icon.overlay:SetFrameLevel(icon.cooldown:GetFrameLevel() + 1)

    icon.keyText = icon.overlay:CreateFontString(nil, "OVERLAY")
    icon.keyText:SetFont(GameFontNormal:GetFont(), 10, "OUTLINE") -- resized in Layout()
    icon.keyText:SetJustifyH("RIGHT")
    icon.keyText:SetWordWrap(false)
    icon.keyText:SetShadowColor(0, 0, 0, 1)
    icon.keyText:SetShadowOffset(0, 0)
    P.Point(icon.keyText, "TOPLEFT", icon, "TOPLEFT", 1, -1)
    P.Point(icon.keyText, "TOPRIGHT", icon, "TOPRIGHT", -1, -1)

    function icon:UpdatePixelPerfect()
        P.Resize(icon)
        P.Repoint(icon)
        icon:SetBackdrop({edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(1)})
        icon:SetBackdropBorderColor(0, 0, 0, 1)
        P.Repoint(icon.tex)
        P.Repoint(icon.keyText)
    end

    return icon
end

local function ArmCooldown(icon)
    local cd = icon.cooldown
    local spellId = icon.spellId
    if not spellId then
        cd:Clear()
        return
    end

    if GetSpellCooldownDuration then
        --! ignoreGCD = true, otherwise every single global cooldown repaints
        --! the whole bar. Never test the object (IsZero() returns a secret) --
        --! just hand it over and let the engine draw whatever is left.
        local duration = GetSpellCooldownDuration(spellId, true)
        if duration then
            cd:SetCooldownFromDurationObject(duration)
        else
            cd:Clear()
        end
    else
        local start, duration = F.GetSpellCooldown(spellId)
        local _, gcd = F.GetSpellCooldown(61304)
        if start and duration and duration > 0 and duration ~= gcd then
            cd:SetCooldown(start, duration)
        else
            cd:Clear()
        end
    end
end

-------------------------------------------------
-- build
-------------------------------------------------
--! Returns the spell bindings of the click-casting profile that is actually in
--! use, in the order the player arranged them.
local function CollectBindings()
    local t = {}

    local bindings = F.GetActiveClickCastings()
    if type(bindings) ~= "table" then return t end

    for _, entry in ipairs(bindings) do
        local modifier, bindKey, bindType, bindAction = F.DecodeClickCastingDB(entry)
        if bindType == "spell" and bindKey ~= "notBound" and bindAction and bindAction ~= "" then
            local name, texture = F.GetSpellInfo(bindAction)
            --! classic writes "spellId:rank"; the cooldown APIs want the bare id
            local spellId = tonumber(bindAction)
            if not spellId and type(bindAction) == "string" then
                spellId = tonumber((strsplit(":", bindAction))) --! extra parens: strsplit's 2nd return would become tonumber's base
            end

            if name and texture and spellId then
                tinsert(t, {
                    spellId = spellId,
                    texture = texture,
                    key = GetKeyDisplay(modifier, bindKey),
                })
            end
        end
    end

    return t
end

local Layout

local function Build()
    local list = CollectBindings()
    shown = #list

    for i, info in ipairs(list) do
        if not icons[i] then icons[i] = CreateHintIcon() end
        local icon = icons[i]
        icon.spellId = info.spellId
        icon.tex:SetTexture(info.texture)
        icon.keyText:SetText(info.key)
        ArmCooldown(icon)
        icon:Show()
    end

    for i = shown + 1, #icons do
        icons[i].spellId = nil
        icons[i].cooldown:Clear()
        icons[i]:Hide()
    end

    Layout()
end

-------------------------------------------------
-- layout
-------------------------------------------------
Layout = function()
    local db = CellDB["tools"]["clickCastingHints"]
    local size, spacing, perLine = db["size"], db["spacing"], db["perRow"]
    local orientation = db["orientation"]
    local isHorizontal = orientation == "left-to-right" or orientation == "right-to-left"

    local fontSize = max(8, floor(size * 0.42))

    local point, stepX, stepY, lineX, lineY
    if orientation == "left-to-right" then
        point = "TOPLEFT"
        stepX, stepY = size + spacing, 0
        lineX, lineY = 0, -(size + spacing)
    elseif orientation == "right-to-left" then
        point = "TOPRIGHT"
        stepX, stepY = -(size + spacing), 0
        lineX, lineY = 0, -(size + spacing)
    elseif orientation == "top-to-bottom" then
        point = "TOPLEFT"
        stepX, stepY = 0, -(size + spacing)
        lineX, lineY = size + spacing, 0
    else -- bottom-to-top
        point = "BOTTOMLEFT"
        stepX, stepY = 0, size + spacing
        lineX, lineY = size + spacing, 0
    end

    for i = 1, shown do
        local index = i - 1
        local line = floor(index / perLine)
        local pos = index % perLine

        local icon = icons[i]
        P.Size(icon, size, size)
        P.ClearPoints(icon)
        P.Point(icon, point, hintsFrame, point, pos * stepX + line * lineX, pos * stepY + line * lineY)
        icon.keyText:SetFont(GameFontNormal:GetFont(), fontSize, "OUTLINE")
    end

    local lines = shown == 0 and 0 or ceil(shown / perLine)
    local inLine = min(shown, perLine)

    local width, height
    if isHorizontal then
        width = inLine * size + max(inLine - 1, 0) * spacing
        height = lines * size + max(lines - 1, 0) * spacing
    else
        width = lines * size + max(lines - 1, 0) * spacing
        height = inLine * size + max(inLine - 1, 0) * spacing
    end

    -- keep something grabbable while the mover is out
    if hintsFrame.moverText:IsShown() then
        width = max(width, MOVER_MIN_WIDTH)
        height = max(height, MOVER_MIN_HEIGHT)
    end

    P.Size(hintsFrame, max(width, 1), max(height, 1))
end

-------------------------------------------------
-- cooldowns
-------------------------------------------------
--! SPELL_UPDATE_COOLDOWN fires several times per global cooldown, so coalesce.
local cdPending
local function RefreshCooldowns()
    if cdPending then return end
    cdPending = true
    C_Timer.After(0.05, function()
        cdPending = nil
        if not hintsFrame:IsShown() then return end
        -- the bar may have been rebuilt shorter while this was queued
        for i = 1, shown do
            if icons[i] then ArmCooldown(icons[i]) end
        end
    end)
end

hintsFrame:SetScript("OnEvent", function(self, event)
    if event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_CHARGES" then
        RefreshCooldowns()
    else -- PLAYER_ENTERING_WORLD: spell info may not have been cached at login
        Build()
    end
end)

-------------------------------------------------
-- show / hide
-------------------------------------------------
local function UpdateVisibility()
    local db = CellDB["tools"]["clickCastingHints"]

    if not db["enabled"] then
        hintsFrame:UnregisterAllEvents()
        hintsFrame:Hide()
        return
    end

    hintsFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    hintsFrame:RegisterEvent("SPELL_UPDATE_CHARGES")
    hintsFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

    Build()

    -- nothing bound to a spell: stay out of the way unless the player is placing it
    if shown == 0 and not hintsFrame.moverText:IsShown() then
        hintsFrame:Hide()
    else
        hintsFrame:Show()
    end
end

local function ShowMover(show)
    if show then
        if not CellDB["tools"]["clickCastingHints"]["enabled"] then return end
        hintsFrame:EnableMouse(true)
        hintsFrame.moverText:Show()
        Cell.StylizeFrame(hintsFrame, {0, 1, 0, 0.4}, {0, 0, 0, 0})
        Layout()
        hintsFrame:Show()
    else
        hintsFrame:EnableMouse(false)
        hintsFrame.moverText:Hide()
        Cell.StylizeFrame(hintsFrame, {0, 0, 0, 0}, {0, 0, 0, 0})
        Layout()
        if shown == 0 then hintsFrame:Hide() end
    end
end
Cell.RegisterCallback("ShowMover", "ClickCastingHints_ShowMover", ShowMover)

-------------------------------------------------
-- callbacks
-------------------------------------------------
local function UpdateTools(which)
    if not which or which == "clickCastingHints" then
        UpdateVisibility()
        ShowMover(Cell.vars.showMover and CellDB["tools"]["clickCastingHints"]["enabled"])
    end

    if not which then -- position
        P.LoadPosition(hintsFrame, CellDB["tools"]["clickCastingHints"]["position"])
    end
end
Cell.RegisterCallback("UpdateTools", "ClickCastingHints_UpdateTools", UpdateTools)

Cell.RegisterCallback("UpdateClickCastings", "ClickCastingHints_UpdateClickCastings", function()
    if CellDB["tools"]["clickCastingHints"]["enabled"] then
        UpdateVisibility()
    end
end)

Cell.RegisterCallback("SpecChanged", "ClickCastingHints_SpecChanged", function()
    if CellDB["tools"]["clickCastingHints"]["enabled"] then
        UpdateVisibility()
    end
end)

local function UpdatePixelPerfect()
    P.Resize(hintsFrame)
    P.Repoint(hintsFrame)
    for _, icon in pairs(icons) do
        icon:UpdatePixelPerfect()
    end
    Layout()
end
Cell.RegisterCallback("UpdatePixelPerfect", "ClickCastingHints_UpdatePixelPerfect", UpdatePixelPerfect)

-------------------------------------------------
-- settings pane
-------------------------------------------------
local LCG = LibStub("LibCustomGlow-1.0")

local cchPane, unlockBtn, enabledCB, sizeSlider, orientationDD, perLineSlider, spacingSlider

--! Dragging a slider fires once per step, so only "enabled" takes the full
--! rebuild path -- everything else is pure geometry and Layout() covers it.
local function Save(key, value)
    CellDB["tools"]["clickCastingHints"][key] = value
    if key == "enabled" then
        Cell.Fire("UpdateTools", "clickCastingHints")
    else
        Layout()
    end
end

local function UpdatePerLineLabel(orientation)
    if strfind(orientation, "top") or strfind(orientation, "bottom") then
        perLineSlider:SetLabel(L["Rows"])
    else
        perLineSlider:SetLabel(L["Columns"])
    end
end

local function CreatePane()
    cchPane = Cell.CreateTitledPane(Cell.frames.utilitiesTab, L["Click-Casting Hints"], 422, 190)
    cchPane:SetPoint("TOPLEFT", 5, -5)
    cchPane:SetPoint("BOTTOMRIGHT", -5, 5)

    -- unlock ---------------------------------------------------------------------------
    unlockBtn = Cell.CreateButton(cchPane, L["Unlock"], "accent", {77, 17})
    unlockBtn:SetPoint("TOPRIGHT", cchPane)
    unlockBtn.locked = true
    unlockBtn:SetScript("OnClick", function(self)
        if self.locked then
            self:SetText(L["Lock"])
            self.locked = false
            Cell.vars.showMover = true
            LCG.PixelGlow_Start(self, {0, 1, 0, 1}, 9, 0.25, 8, 1)
        else
            self:SetText(L["Unlock"])
            self.locked = true
            Cell.vars.showMover = false
            LCG.PixelGlow_Stop(self)
        end
        Cell.Fire("ShowMover", Cell.vars.showMover)
    end)

    -- enabled --------------------------------------------------------------------------
    enabledCB = Cell.CreateCheckButton(cchPane, L["Click-Casting Hints"], function(checked)
        Cell.SetEnabled(checked, sizeSlider, orientationDD, perLineSlider, spacingSlider)
        Save("enabled", checked)
    end, L["Click-Casting Hints"], L["CLICK_CASTING_HINTS_TIPS"])
    enabledCB:SetPoint("TOPLEFT", cchPane, "TOPLEFT", 5, -27)
    Cell.RegisterForCloseDropdown(enabledCB)

    -- size -----------------------------------------------------------------------------
    sizeSlider = Cell.CreateSlider(L["Size"], cchPane, 12, 64, 120, 1, function(value)
        Save("size", value)
    end)
    sizeSlider:SetPoint("TOPLEFT", enabledCB, 0, -55)

    -- orientation ----------------------------------------------------------------------
    orientationDD = Cell.CreateDropdown(cchPane, 120)
    orientationDD:SetPoint("TOPLEFT", sizeSlider, 146, 0)

    local orientations = {"left-to-right", "right-to-left", "top-to-bottom", "bottom-to-top"}
    local items = {}
    for _, orientation in ipairs(orientations) do
        tinsert(items, {
            ["text"] = L[orientation],
            ["value"] = orientation,
            ["onClick"] = function()
                UpdatePerLineLabel(orientation)
                Save("orientation", orientation)
            end,
        })
    end
    orientationDD:SetItems(items)

    local orientationText = cchPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    orientationText:SetText(L["Orientation"])
    orientationText:SetPoint("BOTTOMLEFT", orientationDD, "TOPLEFT", 0, 1)

    -- icons per line -------------------------------------------------------------------
    perLineSlider = Cell.CreateSlider(L["Columns"], cchPane, 1, 20, 120, 1, function(value)
        Save("perRow", value)
    end)
    perLineSlider:SetPoint("TOPLEFT", orientationDD, 146, 0)

    -- spacing --------------------------------------------------------------------------
    spacingSlider = Cell.CreateSlider(L["Spacing"], cchPane, 0, 20, 120, 1, function(value)
        Save("spacing", value)
    end)
    spacingSlider:SetPoint("TOPLEFT", sizeSlider, 0, -55)

    -- tips -----------------------------------------------------------------------------
    local tips = cchPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    tips:SetText("|cffababab" .. L["Only Click-Castings of the Spell type are shown"])
    tips:SetPoint("BOTTOMLEFT")
end

local init
local function ShowUtilitySettings(which)
    if which == "clickCastingHints" then
        if not init then
            init = true
            CreatePane()
        end

        local db = CellDB["tools"]["clickCastingHints"]
        enabledCB:SetChecked(db["enabled"])
        sizeSlider:SetValue(db["size"])
        orientationDD:SetSelectedValue(db["orientation"])
        UpdatePerLineLabel(db["orientation"])
        perLineSlider:SetValue(db["perRow"])
        spacingSlider:SetValue(db["spacing"])
        Cell.SetEnabled(db["enabled"], sizeSlider, orientationDD, perLineSlider, spacingSlider)

        cchPane:Show()

    elseif init then
        -- leaving the pane re-locks the bar, so the mover never outlives the settings
        if not unlockBtn.locked then
            unlockBtn:SetText(L["Unlock"])
            unlockBtn.locked = true
            LCG.PixelGlow_Stop(unlockBtn)
            Cell.vars.showMover = false
            Cell.Fire("ShowMover", false)
        end
        cchPane:Hide()
    end
end
Cell.RegisterCallback("ShowUtilitySettings", "ClickCastingHints_ShowUtilitySettings", ShowUtilitySettings)
