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

local ceil, floor, max, min, abs = math.ceil, math.floor, math.max, math.min, math.abs

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

-- the label floats above the bar so the frame stays exactly as big as the icons
hintsFrame.moverText = hintsFrame:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
hintsFrame.moverText:SetPoint("BOTTOM", hintsFrame, "TOP", 0, 2)
hintsFrame.moverText:SetText(L["Mover"])
hintsFrame.moverText:Hide()

-------------------------------------------------
-- magnet
-------------------------------------------------
--! With "snap" on, dropping the bar next to the raid frames stops storing a SCREEN
--! position and stores an offset from CellAnchorFrame instead -- the little menu block
--! that IS Cell's position handle. Everything else in Cell is laid out from that frame,
--! so anchoring to it means the bar simply comes along when Cell is dragged; there is
--! nothing to keep in sync and no hook on Cell's own drag.
--!
--! ⚠ Distances are compared in raw UI coordinates, NOT through P.Scale. Every frame
--! involved lives under CellParent and therefore shares one effective scale, so GetLeft()
--! values are directly comparable -- and the offset that comes out of them is exactly what
--! SetPoint wants. Running them through P.Scale would scale an already-scaled number.
--! This is the same convention P.SavePosition / P.LoadPosition use.

local ATTACH_RANGE = 40 -- how close the bar has to land before it sticks to Cell at all
local EDGE_SNAP = 10    -- once it sticks, how close an edge has to be to align exactly

-- The rectangle the player thinks of as "Cell": the menu block plus every unit button of
-- the CURRENT group type. skipShared leaves out the NPC and spotlight frames -- those have
-- their own movers and can sit anywhere, so counting them would make "near Cell" meaningless.
local function GetCellRect()
    local left, right, top, bottom

    local function add(f)
        --! a resolvable rect is NOT implied by IsVisible() -- check the numbers
        local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
        if not (l and r and t and b) then return end
        if not left or l < left then left = l end
        if not right or r > right then right = r end
        if not top or t > top then top = t end
        if not bottom or b < bottom then bottom = b end
    end

    local function addIfVisible(f)
        if f and f.IsVisible and f:IsVisible() then add(f) end
    end

    --! unconditionally, even when the menu block is hidden: it is Cell's position handle
    --! and always has a rect, so the magnet still has something to grab when the raid
    --! frames themselves are hidden (solo, or a layout set to hide)
    if Cell.frames.anchorFrame then add(Cell.frames.anchorFrame) end
    F.IterateAllUnitButtons(addIfVisible, true, false, true)

    return left, right, top, bottom
end

-- Align one axis: try putting our low edge, our high edge or our centre on each of the
-- target's edges/centre, and take whichever lands closest. Returns the new low edge.
local function SnapEdge(lo, hi, t1, t2)
    local size = hi - lo
    local targets = {t1, t2, (t1 + t2) / 2}
    local best, bestDist

    for _, target in ipairs(targets) do
        for _, candidate in ipairs({target, target - size, target - size / 2}) do
            local d = abs(candidate - lo)
            if d <= EDGE_SNAP and (not bestDist or d < bestDist) then
                best, bestDist = candidate, d
            end
        end
    end

    return best or lo
end

-- Returns true when the bar ended up attached.
local function TryAttach()
    local db = CellDB["tools"]["clickCastingHints"]
    if not db["snap"] then return false end

    local anchor = Cell.frames.anchorFrame
    if not (anchor and anchor:GetLeft()) then return false end

    local cl, cr, ct, cb = GetCellRect()
    if not cl then return false end

    local l, r, t, b = hintsFrame:GetLeft(), hintsFrame:GetRight(), hintsFrame:GetTop(), hintsFrame:GetBottom()
    if not (l and r and t and b) then return false end

    -- gap between the two rectangles on each axis; 0 when they overlap
    local gapX = max(cl - r, l - cr, 0)
    local gapY = max(cb - t, b - ct, 0)
    if gapX > ATTACH_RANGE or gapY > ATTACH_RANGE then return false end

    local newL = SnapEdge(l, r, cl, cr)
    local newB = SnapEdge(b, t, cb, ct)
    local newT = newB + (t - b)

    db["anchor"] = {newL - anchor:GetLeft(), newT - anchor:GetTop()}
    return true
end

local function IsAttached()
    local a = CellDB["tools"]["clickCastingHints"]["anchor"]
    return CellDB["tools"]["clickCastingHints"]["snap"] and type(a) == "table"
        and type(a[1]) == "number" and type(a[2]) == "number"
end

local function ApplyPosition()
    local db = CellDB["tools"]["clickCastingHints"]
    P.ClearPoints(hintsFrame)

    if IsAttached() then
        --! ⚠ clamping OFF while attached: the clamp repositions the frame to keep it on
        --! screen, which silently overrides the anchor whenever Cell sits near an edge --
        --! the bar would look like it had stopped following.
        hintsFrame:SetClampedToScreen(false)
        hintsFrame:SetPoint("TOPLEFT", Cell.frames.anchorFrame, "TOPLEFT", db["anchor"][1], db["anchor"][2])
    else
        hintsFrame:SetClampedToScreen(true)
        if not P.LoadPosition(hintsFrame, db["position"]) then
            PixelUtil.SetPoint(hintsFrame, "TOPLEFT", CellParent, "CENTER", 1, -1)
        end
    end

    if hintsFrame.moverText:IsShown() then
        hintsFrame.moverText:SetText(IsAttached() and (L["Mover"] .. " |cff00ff00" .. L["Snapped"]) or L["Mover"])
    end
end

-- Stop following Cell but stay exactly where the bar currently is.
local function Detach()
    local db = CellDB["tools"]["clickCastingHints"]
    if db["anchor"] then
        P.SavePosition(hintsFrame, db["position"])
        db["anchor"] = false
    end
    ApplyPosition()
end

hintsFrame:SetScript("OnDragStart", function()
    hintsFrame:StartMoving()
    hintsFrame:SetUserPlaced(false)
end)
hintsFrame:SetScript("OnDragStop", function()
    hintsFrame:StopMovingOrSizing()
    local db = CellDB["tools"]["clickCastingHints"]
    if not TryAttach() then
        db["anchor"] = false
        P.SavePosition(hintsFrame, db["position"])
    end
    ApplyPosition()
end)

-------------------------------------------------
-- key abbreviations
-------------------------------------------------
--! bindKey comes from Cell.CreateBindingButton: mouse buttons are "Left" /
--! "Right" / "Middle" / "ButtonN", the wheel is "ScrollUp" / "ScrollDown" and
--! everything else is a raw WoW key name ("F", "1", "F1", "NUMPAD1", "SPACE").
--!
--! ⚠ Mouse buttons are NOT in this table: they get a glyph (see MOUSE_GLYPH). A letter
--! cannot tell them apart from the keyboard -- "R" was both the right mouse button and
--! the R key -- and spelling them out is both too long for a 30px icon and a
--! translation problem. A picture is neither.
local KEY_ABBR = {
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

--! One glyph per mouse button, drawn by .claude/scripts/cell-mouse-icons.py -- change
--! the script and re-run, never the PNGs. The wheel and the side buttons reuse a glyph
--! plus one character, because four more silhouettes would be indistinguishable at this
--! size. [2] is that character.
local MOUSE_MEDIA = "Interface\\AddOns\\Cell\\Media\\Icons\\"
--! ⚠ the ".png" is required. Extensions are optional for BLP/TGA but not for PNG.
local MOUSE_GLYPH = {
    ["Left"]       = {MOUSE_MEDIA .. "mouse-left.png"},
    ["Right"]      = {MOUSE_MEDIA .. "mouse-right.png"},
    ["Middle"]     = {MOUSE_MEDIA .. "mouse-middle.png"},
    ["ScrollUp"]   = {MOUSE_MEDIA .. "mouse-middle.png", "↑"},
    ["ScrollDown"] = {MOUSE_MEDIA .. "mouse-middle.png", "↓"},
}

-- which keyLabels entry a bindKey draws from, and what to append after it
local MOUSE_LABEL_KEY = {
    ["Left"]       = {"left"},
    ["Right"]      = {"right"},
    ["Middle"]     = {"middle"},
    --! the wheel follows the MIDDLE setting: it is the same physical button, so a player
    --! who renames the middle button expects the wheel to match
    ["ScrollUp"]   = {"middle", "↑"},
    ["ScrollDown"] = {"middle", "↓"},
}

--! Everything is plain white with the font's outline -- no colour coding. The modifiers
--! used to be grey to keep them out of the way, which just made "S" and "C" hard to read
--! at all against a bright spell icon.
local function BuildKeyLabel(modifier, key, fontSize)
    local labels = CellDB["tools"]["clickCastingHints"]["keyLabels"]

    local mods = ""
    if strfind(modifier, "alt") then mods = mods .. labels["alt"] end
    if strfind(modifier, "ctrl") then mods = mods .. labels["ctrl"] end
    if strfind(modifier, "shift") then mods = mods .. labels["shift"] end
    if strfind(modifier, "meta") then mods = mods .. labels["meta"] end

    local suffix
    local mouse = MOUSE_LABEL_KEY[key]
    if mouse then
        local custom = labels[mouse[1]]
        if custom ~= "" then
            -- the player put their own wording in; the glyph is not wanted here
            return mods .. custom .. (mouse[2] or "")
        end
        suffix = mouse[2]
    end

    local glyph = MOUSE_GLYPH[key]
    if not glyph then
        local n = strmatch(key, "^Button(%d+)$")
        if n then glyph = {MOUSE_MEDIA .. "mouse-extra.png", n} end
    end

    if glyph then
        -- square: the PNG is square with the silhouette centred in it
        local h = fontSize + 4
        return mods .. "|T" .. glyph[1] .. ":" .. h .. ":" .. h .. "|t" .. (suffix or glyph[2] or "")
    end

    return mods .. AbbrevKey(key)
end

-- the five anchors offered for the two texts; x/y offsets reach everything else
local ANCHOR_POINTS = {"TOP", "BOTTOM", "LEFT", "RIGHT", "CENTER"}

local function JustifyFor(point)
    if point == "LEFT" or point == "RIGHT" then return point end
    return "CENTER"
end

--! Should the cooldown number be hidden right now, and if so for how long?
--!
--! ⚠ Every read, comparison and subtraction happens INSIDE the pcall. These are the
--! player's own spells, so start/duration are normally plain numbers -- but in restricted
--! content they can come back as secret values, and a secret cannot be compared, only
--! passed on. Doing the maths outside would throw on the first boss pull.
--! Failure is deliberately OPEN (show the number): a countdown that is wrongly visible is
--! a cosmetic slip, one that is wrongly hidden looks like the addon is broken.
local function CountdownGate(spellId, threshold)
    if threshold <= 0 then return false end

    local ok, hide, delay = pcall(function()
        local start, duration = F.GetSpellCooldown(spellId)
        if not start or not duration or duration <= 0 then return false end
        local remaining = start + duration - GetTime()
        if remaining <= threshold then return false end
        return true, remaining - threshold
    end)

    if not ok then return false end
    return hide, delay
end

--! Blizzard's own countdown FontString, moved to where the player asked for it. It only
--! exists once the Cooldown has something to draw, so this is re-run on every arm rather
--! than done once at creation.
local function ApplyDurationText(icon, size)
    local cd = icon.cooldown
    if not cd.GetCountdownFontString then return end
    local fs = cd:GetCountdownFontString()
    if not fs then return end

    local db = CellDB["tools"]["clickCastingHints"]
    local point = db["durationAnchor"]

    -- onto the overlay so it is never buried under the cooldown swipe
    if fs:GetParent() ~= icon.overlay then fs:SetParent(icon.overlay) end
    fs:ClearAllPoints()
    fs:SetPoint(point, icon, point, P.Scale(db["durationX"]), P.Scale(db["durationY"]))
    fs:SetJustifyH(JustifyFor(point))
    fs:SetFont(GameFontNormal:GetFont(), max(8, floor((size or db["size"]) * 0.4)), "OUTLINE")
end

--! Shrink to fit instead of truncating. The label is clipped to the icon width, and a
--! binding cut off half way ("S" where it should say "SC4") is worse than a small one.
--! Rebuilt at every candidate size because the mouse glyph's dimensions live inside the
--! string.
local KEY_FONT_MIN = 7

local function ApplyKeyLabel(icon, size, fontSize)
    if not CellDB["tools"]["clickCastingHints"]["showKeys"] then
        icon.keyText:Hide()
        return
    end
    icon.keyText:Show()

    local db = CellDB["tools"]["clickCastingHints"]
    local point = db["keyAnchor"]
    P.ClearPoints(icon.keyText)
    P.Point(icon.keyText, point, icon, point, db["keyX"], db["keyY"])
    icon.keyText:SetJustifyH(JustifyFor(point))

    local maxWidth = size - 2 -- the 1px border on each side
    local font = GameFontNormal:GetFont()

    for s = max(fontSize, KEY_FONT_MIN), KEY_FONT_MIN, -1 do
        icon.keyText:SetFont(font, s, "OUTLINE")
        icon.keyText:SetText(BuildKeyLabel(icon.bindModifier or "", icon.bindKey or "", s))
        if icon.keyText:GetStringWidth() <= maxWidth then return end
    end
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
    icon.keyText:SetTextColor(1, 1, 1, 1)
    icon.keyText:SetWordWrap(false)
    icon.keyText:SetShadowColor(0, 0, 0, 1)
    icon.keyText:SetShadowOffset(0, 0)
    -- anchored in ApplyKeyLabel, which knows the configured position

    function icon:UpdatePixelPerfect()
        P.Resize(icon)
        P.Repoint(icon)
        icon:SetBackdrop({edgeFile = Cell.vars.whiteTexture, edgeSize = P.Scale(1)})
        icon:SetBackdropBorderColor(0, 0, 0, 1)
        P.Repoint(icon.tex)
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

    --! bumped on every arm so a pending "now show the number" timer from an EARLIER
    --! cooldown cannot fire onto this one
    icon._cdGen = (icon._cdGen or 0) + 1
    local gen = icon._cdGen

    local hide, delay = CountdownGate(spellId, CellDB["tools"]["clickCastingHints"]["durationThreshold"])
    cd:SetHideCountdownNumbers(hide)
    if hide and delay and delay > 0 then
        C_Timer.After(delay, function()
            if icon._cdGen ~= gen then return end
            icon.cooldown:SetHideCountdownNumbers(false)
            ApplyDurationText(icon)
        end)
    end

    if GetSpellCooldownDuration then
        --! ignoreGCD left OFF: the global cooldown sweeps here too, same as an action bar.
        --! Never test the object (IsZero() returns a secret) -- just hand it over and let
        --! the engine draw whatever is left.
        local duration = GetSpellCooldownDuration(spellId)
        if duration then
            cd:SetCooldownFromDurationObject(duration)
        else
            cd:Clear()
        end
        ApplyDurationText(icon)
    else
        local start, duration = F.GetSpellCooldown(spellId)
        if start and duration and duration > 0 then
            cd:SetCooldown(start, duration)
        else
            cd:Clear()
        end
        ApplyDurationText(icon)
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
                    --! raw, not a finished string: the label embeds a mouse glyph whose
                    --! size depends on the font, and the font depends on the icon size --
                    --! so it can only be built once Layout() knows how big the icon is.
                    modifier = modifier,
                    key = bindKey,
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
        icon.bindModifier, icon.bindKey = info.modifier, info.key
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
        ApplyKeyLabel(icon, size, fontSize)
        ApplyDurationText(icon, size)
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
        hintsFrame.moverText:SetText(IsAttached() and (L["Mover"] .. " |cff00ff00" .. L["Snapped"]) or L["Mover"])
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
        ApplyPosition()
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

local cchPane, unlockBtn, enabledCB, snapCB, showKeysCB, sizeSlider, orientationDD,
    perLineSlider, spacingSlider
local labelBoxes = {}   -- keyLabels entries, free text
local valueBoxes = {}   -- plain numeric settings (offsets, threshold)
local anchorDropdowns = {}

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
        Cell.SetEnabled(checked, snapCB, showKeysCB, sizeSlider, orientationDD, perLineSlider, spacingSlider)
        for _, eb in pairs(labelBoxes) do
            eb:SetEnabled(checked and CellDB["tools"]["clickCastingHints"]["showKeys"])
        end
        for _, eb in pairs(valueBoxes) do eb:SetEnabled(checked) end
        for _, dd in pairs(anchorDropdowns) do dd:SetEnabled(checked) end
        Save("enabled", checked)
    end, L["Click-Casting Hints"], L["CLICK_CASTING_HINTS_TIPS"])
    enabledCB:SetPoint("TOPLEFT", cchPane, "TOPLEFT", 5, -27)
    Cell.RegisterForCloseDropdown(enabledCB)

    -- magnet ---------------------------------------------------------------------------
    snapCB = Cell.CreateCheckButton(cchPane, L["Snap to Cell"], function(checked)
        CellDB["tools"]["clickCastingHints"]["snap"] = checked
        if checked then
            -- attach right away if the bar already sits next to the frames, instead of
            -- making the player pick it up and drop it again to see anything happen
            TryAttach()
            ApplyPosition()
        else
            Detach()
        end
    end, L["Snap to Cell"], L["SNAP_TO_CELL_TIPS"])
    snapCB:SetPoint("TOPLEFT", enabledCB, "BOTTOMLEFT", 0, -8)

    -- keybind text ---------------------------------------------------------------------
    showKeysCB = Cell.CreateCheckButton(cchPane, L["Show Keybind"], function(checked)
        for _, eb in pairs(labelBoxes) do
            eb:SetEnabled(checked)
        end
        Save("showKeys", checked)
    end, L["Show Keybind"], L["SHOW_KEYBIND_TIPS"])
    showKeysCB:SetPoint("TOPLEFT", snapCB, "BOTTOMLEFT", 0, -8)

    -- size -----------------------------------------------------------------------------
    sizeSlider = Cell.CreateSlider(L["Size"], cchPane, 12, 64, 120, 1, function(value)
        Save("size", value)
    end)
    sizeSlider:SetPoint("TOPLEFT", showKeysCB, 0, -55)

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

    -- text positions -------------------------------------------------------------------
    --! Free text rather than sliders: an offset is a number the player already has in mind
    --! ("nudge it up 10"), and four sliders would cost more vertical room than the rest of
    --! this pane put together.
    local function CreateValueBox(key, width, text, anchor, x, y, minV, maxV)
        local eb = Cell.CreateEditBox(cchPane, width, 20)
        valueBoxes[key] = eb
        eb:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)
        eb:SetMaxLetters(5)

        --! commit on focus loss, not on every keystroke: "-1" passes through "-" first,
        --! and typing "12" would apply 1 on the way. OnEnterPressed clears focus, so
        --! Enter lands here too.
        eb:HookScript("OnEditFocusLost", function(self)
            local db = CellDB["tools"]["clickCastingHints"]
            local v = tonumber(self:GetText())
            if v then
                if minV and v < minV then v = minV end
                if maxV and v > maxV then v = maxV end
            else
                v = db[key]
            end
            self:SetText(v)
            db[key] = v
            if key == "durationThreshold" then
                RefreshCooldowns() -- the gate has to be re-evaluated, not just redrawn
            else
                Layout()
            end
        end)

        local fs = cchPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
        fs:SetText(text)
        fs:SetPoint("BOTTOMLEFT", eb, "TOPLEFT", 0, 1)
        return eb
    end

    local function CreateAnchorDropdown(key, text, anchor, x, y)
        local dd = Cell.CreateDropdown(cchPane, 120)
        anchorDropdowns[key] = dd
        dd:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)

        local anchorItems = {}
        for _, point in ipairs(ANCHOR_POINTS) do
            tinsert(anchorItems, {
                ["text"] = L[point],
                ["value"] = point,
                ["onClick"] = function() Save(key, point) end,
            })
        end
        dd:SetItems(anchorItems)

        local fs = cchPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
        fs:SetText(text)
        fs:SetPoint("BOTTOMLEFT", dd, "TOPLEFT", 0, 1)
        return dd
    end

    CreateAnchorDropdown("keyAnchor", L["Show Keybind"], spacingSlider, 0, -50)
    CreateValueBox("keyX", 60, L["X Offset"], spacingSlider, 130, -50)
    CreateValueBox("keyY", 60, L["Y Offset"], spacingSlider, 196, -50)

    CreateAnchorDropdown("durationAnchor", L["Duration Text"], spacingSlider, 0, -95)
    CreateValueBox("durationX", 60, L["X Offset"], spacingSlider, 130, -95)
    CreateValueBox("durationY", 60, L["Y Offset"], spacingSlider, 196, -95)
    CreateValueBox("durationThreshold", 100, L["Duration Threshold"], spacingSlider, 266, -95, 0, 3600)

    -- key labels -----------------------------------------------------------------------
    --! The mouse rows are labelled WITH the glyph, not just with a name. It is the only
    --! place a player can find out what the picture on their bar means, and it doubles as
    --! a preview of what they are about to replace.
    local function CreateLabelBox(key, width, text, anchor, x, y)
        local eb = Cell.CreateEditBox(cchPane, width, 20)
        labelBoxes[key] = eb
        eb:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)
        eb:SetMaxLetters(5)
        eb:SetScript("OnTextChanged", function(self, userChanged)
            if not userChanged then return end
            CellDB["tools"]["clickCastingHints"]["keyLabels"][key] = self:GetText()
            Layout()
        end)

        local fs = cchPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
        fs:SetText(text)
        fs:SetPoint("BOTTOMLEFT", eb, "TOPLEFT", 0, 1)
        return eb
    end

    local function Glyph(file)
        return "|T" .. MOUSE_MEDIA .. file .. ":14:14|t "
    end

    CreateLabelBox("left", 120, Glyph("mouse-left.png") .. L["Left Button"], spacingSlider, 0, -140)
    CreateLabelBox("right", 120, Glyph("mouse-right.png") .. L["Right Button"], spacingSlider, 140, -140)
    CreateLabelBox("middle", 120, Glyph("mouse-middle.png") .. L["Middle Button"], spacingSlider, 280, -140)

    CreateLabelBox("alt", 95, _G.ALT_KEY_TEXT or "Alt", spacingSlider, 0, -185)
    CreateLabelBox("ctrl", 95, _G.CTRL_KEY_TEXT or "Ctrl", spacingSlider, 103, -185)
    CreateLabelBox("shift", 95, _G.SHIFT_KEY_TEXT or "Shift", spacingSlider, 206, -185)
    CreateLabelBox("meta", 95, "Cmd", spacingSlider, 309, -185)

    -- tips -----------------------------------------------------------------------------
    local tips = cchPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    tips:SetText("|cffababab" .. L["KEY_LABEL_TIPS"])
    tips:SetPoint("BOTTOMLEFT")
    tips:SetPoint("BOTTOMRIGHT")
    tips:SetJustifyH("LEFT")
    tips:SetSpacing(2)
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
        snapCB:SetChecked(db["snap"])
        showKeysCB:SetChecked(db["showKeys"])
        for key, eb in pairs(labelBoxes) do
            eb:SetText(db["keyLabels"][key] or "")
            eb:SetEnabled(db["enabled"] and db["showKeys"])
        end
        for key, eb in pairs(valueBoxes) do
            eb:SetText(db[key])
            eb:SetEnabled(db["enabled"])
        end
        for key, dd in pairs(anchorDropdowns) do
            dd:SetSelectedValue(db[key])
            dd:SetEnabled(db["enabled"])
        end
        sizeSlider:SetValue(db["size"])
        orientationDD:SetSelectedValue(db["orientation"])
        UpdatePerLineLabel(db["orientation"])
        perLineSlider:SetValue(db["perRow"])
        spacingSlider:SetValue(db["spacing"])
        Cell.SetEnabled(db["enabled"], snapCB, showKeysCB, sizeSlider, orientationDD, perLineSlider, spacingSlider)

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
