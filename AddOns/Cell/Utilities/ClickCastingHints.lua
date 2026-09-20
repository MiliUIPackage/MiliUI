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
-- defaults
-------------------------------------------------
--! ⚠ ONE copy of these values, here, because two things read them: Core's per-key top-up
--! (which fills whatever a saved database is missing) and the "restore defaults" button.
--! Written out twice they drift, and the drift is invisible -- the button would quietly
--! restore a look nobody has shipped.
--! Read at ADDON_LOADED, which fires after every file in the addon has run, so Core can
--! use it even though this file loads long after Core.lua.
Cell.defaults.clickCastingHints = {
    ["enabled"] = false,
    ["size"] = 30,
    ["perRow"] = 5,
    ["spacing"] = 2,
    -- where a FREE-STANDING bar sits. Only read while snap is off; attached, the position is
    -- computed from where the unit buttons are and nothing is stored.
    ["position"] = {},
    -- attached to Cell, or free-standing? On by default: this is a reminder bar that belongs
    -- next to the frames, and a tool that switches on in the middle of the screen reads as
    -- broken. Off means the mover drags it and `position` is what is remembered.
    ["snap"] = true,
    -- WHICH SIDE it attaches to, one setting per group type, because the frames are a
    -- different shape in each and a player may want the bar somewhere else in a raid. Both
    -- SHIP on the left, running down the screen: that is where the pack has always parked
    -- it, and a bar that jumps to another edge the moment a party converts to a raid reads
    -- as a bug. "auto" reads the direction off the side -- see ResolvedOrientation.
    ["attach"] = {
        ["party"] = {["side"] = "left", ["orientation"] = "auto", ["gap"] = 4},
        ["raid"] = {["side"] = "left", ["orientation"] = "auto", ["gap"] = 4},
    },
    -- mouse over an icon -> the spell's own tooltip. ⚠ The bar catches the mouse while this
    -- is on (each icon does, not the whole strip), which is why it is a setting at all.
    ["showTooltip"] = true,
    -- keybind label: master switch, then what each key is drawn as. An EMPTY string on a
    -- mouse button means "use the glyph"; anything else is used literally.
    ["showKeys"] = true,
    ["keyLabels"] = {
        ["left"] = "", ["right"] = "", ["middle"] = "",
        -- the trailing "+" is what separates the modifier from the key: "S+R" reads as a
        -- combination, "SR" reads as one token
        ["alt"] = "A+", ["ctrl"] = "C+", ["shift"] = "S+", ["meta"] = "M+",
    },
    -- the keybind floats just above the icon, so it never covers the art
    ["keyAnchor"] = "TOP", ["keyX"] = 0, ["keyY"] = 5,
    -- ⚠ FIXED sizes, never derived from the icon size: a label's width depends on how much
    -- the player wrote in it, so auto-fitting made neighbouring icons disagree
    ["keyFontSize"] = 12,
    ["durationAnchor"] = "CENTER", ["durationX"] = 0, ["durationY"] = -4,
    ["durationFontSize"] = 15,
    -- only show the number once the cooldown is under this many seconds; 0 = always
    ["durationThreshold"] = 60,
}

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
-- attach
-------------------------------------------------
--! With "snap" on the bar stores no position at all: it is placed against one SIDE of the
--! unit buttons and RECOMPUTED every time something that could have moved them happens. That
--! is the whole difference from the drag-and-magnet model this replaces -- there, a bar
--! dropped next to a three-spell character's frames was in the wrong place on a five-spell
--! one, and every layout change meant picking it up and dropping it again.
--!
--! Three things decide where it lands:
--!
--!   * side -- which edge of the unit buttons it sits against, and therefore which of OUR
--!     edges faces them. ⚠ That facing edge is what gets pinned, never the far one: the bar
--!     is as wide as the character has bindings, so pinning the far edge lets the gap float
--!     with the icon count -- a three-spell character would sit a spell and a half further
--!     from the frames than a five-spell one.
--!   * the layout's own anchor (TOPLEFT / TOPRIGHT / BOTTOMLEFT / BOTTOMRIGHT) -- Cell grows
--!     its frames away from that corner, so the bar starts from the same end and the two
--!     grow together instead of drifting apart.
--!   * gap -- how far the facing edge sits from the buttons.
--!
--! ⚠ The rectangle we measure is the UNIT BUTTONS ONLY. The menu block (CellAnchorFrame) is
--! deliberately NOT part of it: it is a 20x10 handle parked outside the frames, so folding it
--! in would shift the whole bar by the handle's size and still leave the two overlapping. It
--! is something to make room FOR, not something to line up with -- so it is an obstacle
--! instead (see Obstacles), together with the battle-res box while that is docked to it.
--! Anything in the way pushes the bar's STARTING end further along the edge; the side and the
--! gap never change, so the bar stays where the player put it and merely begins later.
--!
--! ⚠ Distances are compared in raw UI coordinates, NOT through P.Scale. Every frame involved
--! lives under CellParent and therefore shares one effective scale, so GetLeft() values are
--! directly comparable -- and the offset that comes out of them is exactly what SetPoint
--! wants. Running them through P.Scale would scale an already-scaled number. This is the
--! same convention P.SavePosition / P.LoadPosition use.

--! How much slack the obstacle test gives on the VERTICAL axis. The battle-res box slides 14
--! up or down while the menu fades in and out (BattleRes.lua's onShow / onHide offsets), and
--! a strict overlap test would change its answer halfway through that slide -- the bar would
--! step aside and back for the length of the animation. Reserving the whole travel makes both
--! ends of it give the same answer. The cost is that a bar attached to the LEFT or RIGHT
--! edge, where this is the axis it grows along, can start up to 14 further along than it
--! strictly has to; that is a gap nobody can name, and a twitching bar is not.
local OBSTACLE_PAD = 14

local SIDES = {["left"] = true, ["right"] = true, ["top"] = true, ["bottom"] = true}
local ORIENTATIONS = {
    ["left-to-right"] = true, ["right-to-left"] = true,
    ["top-to-bottom"] = true, ["bottom-to-top"] = true,
}

--! Raid, or everything else. Solo shares the party settings on purpose: solo IS the party
--! layout with one row in it, so whatever fits beside a party fits beside that too, and a
--! third copy of the settings would only ever be set to the same thing.
local function Context()
    return Cell.vars.groupType == "raid" and "raid" or "party"
end

-- The stored table for one context, repaired on the spot if a saved database is missing it.
local function AttachTable(context)
    local db = CellDB["tools"]["clickCastingHints"]
    if type(db["attach"]) ~= "table" then db["attach"] = {} end
    if type(db["attach"][context]) ~= "table" then
        db["attach"][context] = F.Copy(Cell.defaults.clickCastingHints["attach"][context])
    end
    return db["attach"][context]
end

--! The three values for the group type we are in, each falling back to the shipped default on
--! its own. Per key, not per table: a database can be any shape after a hand edit or a
--! half-finished migration, and one unreadable value must not cost the other two.
local function AttachDB()
    local context = Context()
    local t = AttachTable(context)
    local d = Cell.defaults.clickCastingHints["attach"][context]

    local side = SIDES[t["side"]] and t["side"] or d["side"]
    local orientation = t["orientation"]
    if orientation ~= "auto" and not ORIENTATIONS[orientation] then orientation = d["orientation"] end
    local gap = type(t["gap"]) == "number" and t["gap"] or d["gap"]

    return side, orientation, gap
end

local function IsAttached()
    return CellDB["tools"]["clickCastingHints"]["snap"] and true or false
end

--! "auto" read off the side: a bar down the side of the frames runs vertically, one along the
--! top or the bottom runs across. Free-standing there is no side to ask, so it reads
--! left-to-right like any other row. Everything that draws the bar asks this, never the
--! stored value -- see Layout and UpdatePerLineLabel.
local function ResolvedOrientation()
    local side, orientation = AttachDB()
    if orientation ~= "auto" then return orientation end
    if not IsAttached() then return "left-to-right" end
    if side == "left" or side == "right" then return "top-to-bottom" end
    return "left-to-right"
end

--! a resolvable rect is NOT implied by IsVisible() -- check the numbers
local function RectOf(f)
    if not f then return end
    local l, r, t, b = f:GetLeft(), f:GetRight(), f:GetTop(), f:GetBottom()
    if not (l and r and t and b) then return end
    return l, r, t, b
end

-- The rectangle the unit buttons of the CURRENT group type occupy, plus (in a party) the pet
-- and target slots beside each member who is present, whether or not something is in them
-- right now. skipShared leaves out the NPC and spotlight frames -- those have their own movers
-- and can sit anywhere, so counting them would park the bar next to something the player has
-- deliberately put on the other side of the screen.
local function GetCellRect()
    local left, right, top, bottom

    local function add(f)
        local l, r, t, b = RectOf(f)
        if not l then return end
        if not left or l < left then left = l end
        if not right or r > right then right = r end
        if not top or t > top then top = t end
        if not bottom or b < bottom then bottom = b end
    end

    local function addIfVisible(f)
        if f and f.IsVisible and f:IsVisible() then add(f) end
    end

    F.IterateAllUnitButtons(addIfVisible, true, false, true)

    --! In a party, the pet column and the party-target column count even while EMPTY. Both
    --! are reserved slots beside every member -- a pet that is not out right now, a member
    --! with nothing targeted -- and a bar that only measured the visible ones would sit
    --! exactly where the next pet appears. Only beside members who are present: an empty
    --! party slot reserves nothing, the same as the member buttons themselves. Hidden frames
    --! still answer GetLeft() once anchored.
    if Cell.vars.groupType == "party" then
        local layout = Cell.vars.currentLayoutTable
        local petsOn = layout and layout["pet"]["partyEnabled"] and not layout["pet"]["partyDetached"]
        local targetsOn = F.GetPartyTargetsSide and F.GetPartyTargetsSide() ~= nil
        for i = 1, 5 do
            local member = Cell.unitButtons.party["player"..i]
            if member and member:IsVisible() then
                if petsOn and member.petButton then add(member.petButton) end
                if targetsOn and member.targetButton then add(member.targetButton) end
            end
        end
    end

    --! Nothing to measure: solo with the frames hidden, a layout set to hide them, or the
    --! very first pass before the secure headers have laid anything out. Fall back to the
    --! frame that IS the group area, and only if even that has no rect yet to the menu block,
    --! which always has one.
    if not left then left, right, top, bottom = RectOf(Cell.frames.mainFrame) end
    if not left then left, right, top, bottom = RectOf(Cell.frames.anchorFrame) end

    return left, right, top, bottom
end

-- What the bar has to step around, in the order they stack up outward from the frames: the
-- menu block first (always counted, hidden or not -- it is Cell's position handle and a hidden
-- frame still answers GetLeft once it is anchored), then the battle-res box when it is on
-- screen AND still docked to the menu block. Dragged out to a position of its own
-- (battleResTimer[2]) it is somewhere else entirely and none of our business.
local function Obstacles()
    local t = {}

    local l, r, tp, b = RectOf(Cell.frames.anchorFrame)
    if l then tinsert(t, {l, r, tp, b}) end

    --! In a raid the menu is TWO buttons: the raid-roster button sits beside the options
    --! button, outside CellAnchorFrame's own 20x10 (MainFrame.lua). IsShown, not IsVisible --
    --! the menu fades by alpha, and a faded button is still where the mouse brings it back.
    local raidBtn = Cell.frames.menuFrame and Cell.frames.menuFrame.raidButton
    if raidBtn and raidBtn:IsShown() then
        l, r, tp, b = RectOf(raidBtn)
        if l then tinsert(t, {l, r, tp, b}) end
    end

    local brDB = CellDB["tools"]["battleResTimer"]
    local br = Cell.frames.battleResFrame
    if br and br:IsShown() and not (type(brDB) == "table" and brDB[2]) then
        l, r, tp, b = RectOf(br)
        if l then tinsert(t, {l, r, tp, b}) end
    end

    return t
end

-- Where the bar's pinned corner belongs, in screen coordinates: the corner's name plus its
-- x and y. Returns nothing when there is no rect to measure against yet.
local function AttachPoint()
    local bl, br, bt, bb = GetCellRect()
    if not bl then return end

    local side, _, gap = AttachDB()
    local w, h = hintsFrame:GetWidth(), hintsFrame:GetHeight()
    local anchor = Cell.vars.currentLayoutTable and Cell.vars.currentLayoutTable["main"]["anchor"] or "TOPLEFT"

    -- lay the bar against the chosen edge: this fixes the axis PERPENDICULAR to the one it
    -- grows along, and it is the only place `gap` decides a distance from the buttons
    local l, r, t, b
    if side == "left" then
        r = bl - gap
        l = r - w
    elseif side == "right" then
        l = br + gap
        r = l + w
    elseif side == "top" then
        b = bt + gap
        t = b + h
    else -- bottom
        t = bb - gap
        b = t - h
    end

    -- ...and start it at the end the layout grows from, which fixes the other axis
    local vertical = side == "left" or side == "right"
    local pinLow --! vertical: pinned by our BOTTOM edge. horizontal: pinned by our LEFT edge.
    if vertical then
        pinLow = not strfind(anchor, "^TOP")
        if pinLow then b = bb; t = b + h else t = bt; b = t - h end
    else
        pinLow = strfind(anchor, "LEFT$") and true or false
        if pinLow then l = bl; r = l + w else r = br; l = r - w end
    end

    --! Step over anything in the way, then look again: the two obstacles stack (the
    --! battle-res box sits directly outside the menu block), so clearing one can walk the bar
    --! straight into the other. Every push moves strictly away from the pinned end, so this
    --! cannot oscillate; one pass per obstacle is the most it can ever need.
    local obstacles = Obstacles()
    for _ = 1, #obstacles do
        local moved = false
        for _, o in ipairs(obstacles) do
            local ol, orr, ot, ob = o[1], o[2], o[3] + OBSTACLE_PAD, o[4] - OBSTACLE_PAD
            if l < orr and r > ol and b < ot and t > ob then -- overlapping on BOTH axes
                if vertical then
                    if pinLow then b = ot + gap; t = b + h else t = ob - gap; b = t - h end
                else
                    if pinLow then l = orr + gap; r = l + w else r = ol - gap; l = r - w end
                end
                moved = true
            end
        end
        if not moved then break end
    end

    -- Pin the corner where the facing edge meets the starting end. Both halves matter: the
    -- facing edge holds the gap steady however many icons there are, the starting end keeps
    -- the bar growing the same way the frames do.
    local point
    if vertical then
        point = (pinLow and "BOTTOM" or "TOP") .. (side == "left" and "RIGHT" or "LEFT")
    else
        point = (side == "top" and "BOTTOM" or "TOP") .. (pinLow and "LEFT" or "RIGHT")
    end

    return point, (strfind(point, "RIGHT") and r or l), (strfind(point, "BOTTOM") and b or t)
end

--! The one-off conversion of a database that was dragged to a custom offset under the old
--! magnet model. Core.lua cannot finish that migration itself: the old value is an offset
--! from CellAnchorFrame and turning it into a stored SCREEN position needs a resolved rect,
--! which nothing has at ADDON_LOADED. So Core parks the old numbers here and the first
--! placement that has a rect to work with replays the old SetPoint once, saves where that
--! landed as an ordinary free position, and drops the key. Those players keep the bar exactly
--! where it was; it simply stops following Cell until they tick the box again.
--! Returns false only when it wants to be tried again later.
local LEGACY_POINTS = {["TOPLEFT"] = true, ["TOPRIGHT"] = true, ["BOTTOMLEFT"] = true, ["BOTTOMRIGHT"] = true}
local function ConsumeLegacyAnchor()
    local db = CellDB["tools"]["clickCastingHints"]
    local legacy = db["legacyAnchor"]
    if type(legacy) ~= "table" then return true end

    if not (type(legacy[1]) == "number" and type(legacy[2]) == "number") then
        db["legacyAnchor"] = nil
        return true
    end

    local anchor = Cell.frames.anchorFrame
    if not (anchor and anchor:GetLeft()) then return false end

    P.ClearPoints(hintsFrame)
    hintsFrame:SetPoint(LEGACY_POINTS[legacy[3]] and legacy[3] or "TOPLEFT", anchor, "TOPLEFT", legacy[1], legacy[2])
    if hintsFrame:GetLeft() then P.SavePosition(hintsFrame, db["position"]) end
    db["legacyAnchor"] = nil
    return true
end

local function ApplyPosition()
    local db = CellDB and CellDB["tools"] and CellDB["tools"]["clickCastingHints"]
    if not db then return end
    --! switched off: the callbacks below still fire for every layout change, and there is no
    --! bar to place. Enabling goes through Build -> Layout, which schedules a pass of its own.
    if not db["enabled"] then return end

    if IsAttached() then
        local point, x, y = AttachPoint()
        local anchor = Cell.frames.anchorFrame
        --! nothing resolvable yet -- leave the bar where it is and wait for the next pass,
        --! rather than clearing its points and dropping it on CellParent's centre
        if not (point and anchor and anchor:GetLeft()) then return end

        --! ticking "attach" on a database that still owes us the old-model conversion makes
        --! that conversion pointless -- it only existed to keep a FREE bar where it was
        db["legacyAnchor"] = nil

        --! ⚠ clamping OFF while attached: the clamp repositions the frame to keep it on
        --! screen, which silently overrides the anchor whenever Cell sits near an edge --
        --! the bar would look like it had stopped following.
        hintsFrame:SetClampedToScreen(false)
        P.ClearPoints(hintsFrame)
        --! anchored to the menu block rather than to the screen, so dragging Cell carries the
        --! bar along with it -- nothing to keep in sync, and no hook on Cell's own drag
        hintsFrame:SetPoint(point, anchor, "TOPLEFT", x - anchor:GetLeft(), y - anchor:GetTop())
    else
        if not ConsumeLegacyAnchor() then return end
        hintsFrame:SetClampedToScreen(true)
        P.ClearPoints(hintsFrame)
        if not P.LoadPosition(hintsFrame, db["position"]) then
            PixelUtil.SetPoint(hintsFrame, "TOPLEFT", CellParent, "CENTER", 1, -1)
        end
    end

    if hintsFrame.moverText:IsShown() then
        hintsFrame.moverText:SetText(IsAttached() and (L["Mover"] .. " |cff00ff00" .. L["Snapped"]) or L["Mover"])
    end
end

--! Everything that can move the bar fires in bursts -- a roster change is three events, a
--! slider drag is one call per step, an option pane repaint fires UpdateTools once per tool --
--! and the placement reads half a dozen rects, so do it once, next frame. The delay is also
--! what lets the secure headers finish laying the buttons out: GROUP_ROSTER_UPDATE arrives
--! before the new row has a rect.
local posPending
local function SchedulePosition()
    if posPending then return end
    posPending = true
    C_Timer.After(0.05, function()
        posPending = nil
        ApplyPosition()
    end)
end

hintsFrame:SetScript("OnDragStart", function()
    --! there is nothing to drag while the bar is attached -- its position is computed, so a
    --! drag would be undone by the next roster change. Refusing to start is honest; the
    --! mover's own label carries the "[snapped]" tag that says why.
    if IsAttached() then return end
    hintsFrame:StartMoving()
    hintsFrame:SetUserPlaced(false)
end)
hintsFrame:SetScript("OnDragStop", function()
    if IsAttached() then return end
    hintsFrame:StopMovingOrSizing()
    P.SavePosition(hintsFrame, CellDB["tools"]["clickCastingHints"]["position"])
    ApplyPosition()
end)

--! The battle-res box comes and goes in the middle of a fight and the bar steps around it, so
--! its own show and hide are placement triggers.
--! ⚠ HookScript, and exactly once. BattleRes.lua owns those two scripts with SetScript at file
--! scope, which would wipe a hook made before it ran. It loads BEFORE this file today
--! (Utilities/LoadUtilities.xml), so a hook here would survive -- but this is put off until
--! the first UpdateTools anyway, which runs after every file has, so re-ordering that xml
--! cannot silently cost us the trigger.
local battleResHooked
local function HookBattleRes()
    if battleResHooked then return end
    local br = Cell.frames.battleResFrame
    if not br then return end
    battleResHooked = true
    br:HookScript("OnShow", SchedulePosition)
    br:HookScript("OnHide", SchedulePosition)
end

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
--! How much taller than the font the mouse glyph is drawn -- and, because of that, how
--! tall EVERY keybind label's box is. The two have to be the same number; see ApplyKeyLabel.
local KEY_GLYPH_PAD = 4

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
        local h = fontSize + KEY_GLYPH_PAD
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
--! ⚠ These are the player's own spells, so start/duration are normally plain numbers --
--! but in restricted content (every raid boss) they come back as secret values, and a
--! secret cannot be compared, only passed on. Ask BEFORE comparing: the old version let
--! the compare throw inside a pcall, which still counts as a blocked action -- one per
--! icon per cooldown update, 39k lines of taint.log over a single raid night.
--! Failure is deliberately OPEN (show the number): a countdown that is wrongly visible is
--! a cosmetic slip, one that is wrongly hidden looks like the addon is broken.
local function CountdownGate(spellId, threshold)
    if threshold <= 0 then return false end

    local start, duration = F.GetSpellCooldown(spellId)
    if F.IsSecretValue(start) or F.IsSecretValue(duration) then return false end
    if not start or not duration or duration <= 0 then return false end
    local remaining = start + duration - GetTime()
    if remaining <= threshold then return false end
    return true, remaining - threshold
end

--! Blizzard's own countdown FontString, moved to where the player asked for it. It only
--! exists once the Cooldown has something to draw, so this is re-run on every arm rather
--! than done once at creation.
local function ApplyDurationText(icon)
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
    fs:SetFont(GameFontNormal:GetFont(), db["durationFontSize"], "OUTLINE")
end

--! ⚠ One fixed font size for the whole bar, set by the player -- NOT fitted per icon.
--! Auto-shrinking meant the size depended on how long that particular binding happened to
--! be, so "S+R" and "R" ended up at different sizes side by side. The label is anchored by
--! a single point and is free to be wider than its icon; a player who wants more text in
--! there turns the size down.
local function ApplyKeyLabel(icon)
    local db = CellDB["tools"]["clickCastingHints"]
    if not db["showKeys"] then
        icon.keyText:Hide()
        return
    end
    icon.keyText:Show()

    local point = db["keyAnchor"]
    P.ClearPoints(icon.keyText)
    P.Point(icon.keyText, point, icon, point, db["keyX"], db["keyY"])
    icon.keyText:SetJustifyH(JustifyFor(point))

    local fontSize = db["keyFontSize"]
    icon.keyText:SetFont(GameFontNormal:GetFont(), fontSize, "OUTLINE")

    --! ⚠ Fixed height + MIDDLE, not the string's natural height. An inline texture makes
    --! its line taller than a text-only line, and the string is anchored by its TOP -- so
    --! "C+<glyph>" sat a couple of pixels lower than the plain "S+R" beside it. Giving
    --! every label the same box (as tall as the tallest possible line, i.e. the glyph) and
    --! centring inside it makes the two line up whatever they contain.
    icon.keyText:SetHeight(fontSize + KEY_GLYPH_PAD)
    icon.keyText:SetJustifyV("MIDDLE")

    icon.keyText:SetText(BuildKeyLabel(icon.bindModifier or "", icon.bindKey or "", fontSize))
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

    --! The spell's own tooltip, through Cell's tooltip frame (the same one the Quick Assist
    --! spell pickers use) so it is skinned like the rest of the addon and carries the icon.
    --! Mouse is enabled per ICON in Layout(), never on the strip: the strip's own mouse is
    --! the mover's, and swallowing it here would make the bar undraggable.
    icon:SetScript("OnEnter", function(self)
        if not (self.spellId and CellSpellTooltip) then return end
        CellSpellTooltip:SetOwner(self, "ANCHOR_TOP")
        CellSpellTooltip:SetSpellByID(self.spellId, self.tex:GetTexture())
        CellSpellTooltip:Show()
    end)
    icon:SetScript("OnLeave", function()
        if CellSpellTooltip then CellSpellTooltip:Hide() end
    end)

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
    --! never the stored value: it may be "auto", which only the attached side can answer
    local orientation = ResolvedOrientation()
    local isHorizontal = orientation == "left-to-right" or orientation == "right-to-left"

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
        --! ⚠ off while the mover is up, whatever the setting says: the drag lives on the
        --! strip, and a mouse-enabled icon would eat the click that is supposed to move it.
        icon:EnableMouse(db["showTooltip"] and not Cell.vars.showMover and true or false)
        ApplyKeyLabel(icon)
        ApplyDurationText(icon)
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

    --! the bar's SIZE just changed, and an attached bar is measured from its facing edge --
    --! so the placement has to be redone. Coalesced, because this runs once per step while a
    --! slider is being dragged.
    SchedulePosition()
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
    elseif event == "GROUP_ROSTER_UPDATE" or event == "UNIT_PET" then
        --! the roster decides how many unit buttons there are, and an attached bar is placed
        --! against the rectangle they make. ⚠ UNIT_PET's unit argument is deliberately
        --! ignored rather than filtered: in 12.1 a unit token can be a secret string, and
        --! comparing one is a hard error -- the placement re-reads every rect anyway.
        SchedulePosition()
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
    --! only while the tool is on, like everything above: an attached bar is measured from
    --! the unit buttons, and these two are what change how many of those there are
    hintsFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
    hintsFrame:RegisterEvent("UNIT_PET")

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
        --! ⚠ NOT while attached: the drag is refused there (see OnDragStart), and a strip
        --! that eats the mouse without moving reads as a bug. The green box and the
        --! "[snapped]" label still show, so unlocking still tells the player where it is.
        hintsFrame:EnableMouse(not IsAttached())
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
    --! first thing that runs after every file has loaded -- see HookBattleRes
    HookBattleRes()

    if not which or which == "clickCastingHints" then
        UpdateVisibility()
        ShowMover(Cell.vars.showMover and CellDB["tools"]["clickCastingHints"]["enabled"])
    end

    --! unconditionally, whichever tool this was about: the battle-res box docks beside the
    --! menu block and the party-target column widens the unit-button rectangle, so another
    --! tool's settings can move this bar without it hearing anything else
    SchedulePosition()
end
Cell.RegisterCallback("UpdateTools", "ClickCastingHints_UpdateTools", UpdateTools)

--! the frames were resized, re-anchored or re-arranged -- all of which move the rectangle the
--! bar is measured against
Cell.RegisterCallback("UpdateLayout", "ClickCastingHints_UpdateLayout", function()
    SchedulePosition()
end)

--! the menu block changed shape (top_bottom is 20x10, left_right is 10x20) and with it what
--! the bar has to step around
Cell.RegisterCallback("UpdateMenu", "ClickCastingHints_UpdateMenu", function(which)
    if which == "position" then SchedulePosition() end
end)

--! the context switched, so side / direction / gap now come out of the other table. Layout(),
--! not just a reposition: "auto" resolves off the side, so the bar may have to be rebuilt the
--! other way round before it can be placed.
Cell.RegisterCallback("GroupTypeChanged", "ClickCastingHints_GroupTypeChanged", function()
    Layout()
end)

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
local LCG = Cell.MiliUIGlow

local cchPane, unlockBtn, enabledCB, snapCB, showKeysCB, showTooltipCB, sizeSlider, orientationDD,
    perLineSlider, spacingSlider, sideDD, gapSlider, partyBtn, raidBtn, HighlightContext
local labelBoxes = {}   -- keyLabels entries, free text
local valueBoxes = {}   -- plain numeric settings (offsets, threshold)
local anchorDropdowns = {}

--! Which context the three attach controls are showing. NOT the group type the player is in:
--! the point of the pair of buttons is to set up the other one before getting there.
local editing = "party"

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

--! One of the three per-context values. Always Layout(), even when the context being edited
--! is not the one on screen: the values it reads come from Context(), so editing the other
--! table is a no-op there, and the alternative is a branch that quietly goes stale.
--! The placement rides Layout's own coalesced pass -- the gap slider fires once per step.
local function SaveAttach(key, value)
    AttachTable(editing)[key] = value
    Layout()
end

--! What the perRow slider counts depends on which way the bar runs, so it follows the bar on
--! SCREEN (ResolvedOrientation), not the context being edited -- picking a direction for the
--! raid while standing in a party must not relabel the slider that is counting party columns.
local function UpdatePerLineLabel()
    local orientation = ResolvedOrientation()
    if strfind(orientation, "top") or strfind(orientation, "bottom") then
        perLineSlider:SetLabel(L["Rows"])
    else
        perLineSlider:SetLabel(L["Columns"])
    end
end

--! The three attach controls, reloaded from whichever context is being edited. Per key with
--! the shipped default behind it, for the same reason AttachDB is.
local function LoadAttachDB()
    local t = AttachTable(editing)
    local d = Cell.defaults.clickCastingHints["attach"][editing]
    local orientation = t["orientation"]
    if orientation ~= "auto" and not ORIENTATIONS[orientation] then orientation = d["orientation"] end

    sideDD:SetSelectedValue(SIDES[t["side"]] and t["side"] or d["side"])
    orientationDD:SetSelectedValue(orientation)
    gapSlider:SetValue(type(t["gap"]) == "number" and t["gap"] or d["gap"])
end

--! ⚠ forward declaration -- the reset button's handler is written inside CreatePane,
--! which is above the body. A `local function` declared below its call site resolves to a
--! nil GLOBAL there, and nothing complains until the button is actually clicked.
local RestoreDefaults

--! ⚠ Everything in here is placed with P.Point, never a bare SetPoint. The options frame
--! height goes through P.Scale (P.Height in Utilities.lua), so on any UI scale other than
--! 1 a raw offset is measured in different units than the frame it sits in -- the rows
--! drift down and the last one ends up outside the panel. Cell's other panes get away with
--! raw offsets only because they leave a lot of slack at the bottom.
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
        local db = CellDB["tools"]["clickCastingHints"]
        Cell.SetEnabled(checked, snapCB, showKeysCB, showTooltipCB, sizeSlider, orientationDD,
            perLineSlider, spacingSlider, partyBtn, raidBtn)
        --! side and gap describe an attachment, so they follow the snap box as well. The
        --! DIRECTION does not: a free-standing bar is laid out too.
        Cell.SetEnabled(checked and db["snap"] and true or false, sideDD, gapSlider)
        for _, eb in pairs(labelBoxes) do
            eb:SetEnabled(checked and db["showKeys"])
        end
        for _, eb in pairs(valueBoxes) do eb:SetEnabled(checked) end
        for _, dd in pairs(anchorDropdowns) do dd:SetEnabled(checked) end
        Save("enabled", checked)
    end, L["Click-Casting Hints"], L["CLICK_CASTING_HINTS_TIPS"])
    P.Point(enabledCB, "TOPLEFT", cchPane, "TOPLEFT", 5, -27)
    Cell.RegisterForCloseDropdown(enabledCB)

    -- attach ---------------------------------------------------------------------------
    snapCB = Cell.CreateCheckButton(cchPane, L["Snap to Cell"], function(checked)
        local db = CellDB["tools"]["clickCastingHints"]
        --! freeze the bar where it is BEFORE letting go of Cell, so unticking the box leaves
        --! it under the player's eyes instead of teleporting it to some older stored spot
        if not checked and hintsFrame:GetLeft() then
            P.SavePosition(hintsFrame, db["position"])
        end
        db["snap"] = checked
        Cell.SetEnabled(db["enabled"] and checked and true or false, sideDD, gapSlider)
        --! Layout(), not just a reposition: "auto" resolves off the side while attached and
        --! to left-to-right while not, so the bar itself may change shape.
        --! the mover only takes the mouse while the bar is free (see ShowMover), so an
        --! unlocked bar has to be told when that changes -- ShowMover ends in Layout()
        if Cell.vars.showMover then ShowMover(true) else Layout() end
        UpdatePerLineLabel()
    end, L["Snap to Cell"], L["SNAP_TO_CELL_TIPS"])
    P.Point(snapCB, "TOPLEFT", enabledCB, "BOTTOMLEFT", 0, -8)

    -- keybind text ---------------------------------------------------------------------
    showKeysCB = Cell.CreateCheckButton(cchPane, L["Show Keybind"], function(checked)
        for _, eb in pairs(labelBoxes) do
            eb:SetEnabled(checked)
        end
        Save("showKeys", checked)
    end, L["Show Keybind"], L["SHOW_KEYBIND_TIPS"])
    P.Point(showKeysCB, "TOPLEFT", snapCB, "BOTTOMLEFT", 0, -8)

    -- spell tooltip ---------------------------------------------------------------------
    showTooltipCB = Cell.CreateCheckButton(cchPane, L["Show Spell Tooltip"], function(checked)
        Save("showTooltip", checked)
    end, L["Show Spell Tooltip"], L["SHOW_SPELL_TOOLTIP_TIPS"])
    --! second column rather than a fourth row: the sliders below are anchored to showKeysCB
    --! with a fixed -55, so another row here would land on top of them.
    P.Point(showTooltipCB, "TOPLEFT", showKeysCB, "TOPLEFT", 200, 0)

    -- size -----------------------------------------------------------------------------
    sizeSlider = Cell.CreateSlider(L["Size"], cchPane, 12, 64, 120, 1, function(value)
        Save("size", value)
    end)
    P.Point(sizeSlider, "TOPLEFT", showKeysCB, "TOPLEFT", 0, -55)

    -- icons per line -------------------------------------------------------------------
    perLineSlider = Cell.CreateSlider(L["Columns"], cchPane, 1, 20, 120, 1, function(value)
        Save("perRow", value)
    end)
    P.Point(perLineSlider, "TOPLEFT", sizeSlider, "TOPLEFT", 146, 0)

    -- spacing --------------------------------------------------------------------------
    spacingSlider = Cell.CreateSlider(L["Spacing"], cchPane, 0, 20, 120, 1, function(value)
        Save("spacing", value)
    end)
    P.Point(spacingSlider, "TOPLEFT", sizeSlider, "TOPLEFT", 292, 0)

    -- which context the three below are for ----------------------------------------------
    --! A pair of buttons rather than a third dropdown: this is not a setting, it is which
    --! copy of the next row you are looking at, and a dropdown reads as one more thing to
    --! configure. They also keep both answers visible, which a dropdown does not.
    partyBtn = Cell.CreateButton(cchPane, L["Party"], "accent-hover", {70, 20})
    partyBtn.id = "party"
    P.Point(partyBtn, "TOPLEFT", sizeSlider, "TOPLEFT", 0, -52)

    raidBtn = Cell.CreateButton(cchPane, L["Raid"], "accent-hover", {70, 20})
    raidBtn.id = "raid"
    P.Point(raidBtn, "TOPLEFT", sizeSlider, "TOPLEFT", 71, -52)

    local contextText = cchPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    contextText:SetText(L["Settings For"])
    P.Point(contextText, "BOTTOMLEFT", partyBtn, "TOPLEFT", 0, 1)

    HighlightContext = Cell.CreateButtonGroup({partyBtn, raidBtn}, function(id)
        editing = id
        LoadAttachDB()
    end)

    -- attach side ------------------------------------------------------------------------
    --! ⚠ L["LEFT"] / L["RIGHT"], not L["Left"] / L["Right"]: on zhCN the latter pair is
    --! translated as the MOUSE buttons ("左键" / "右键"), not as directions.
    sideDD = Cell.CreateDropdown(cchPane, 100)
    P.Point(sideDD, "TOPLEFT", sizeSlider, "TOPLEFT", 0, -97)

    local sideItems = {}
    for _, side in ipairs({"left", "right", "top", "bottom"}) do
        tinsert(sideItems, {
            ["text"] = L[strupper(side)],
            ["value"] = side,
            ["onClick"] = function()
                SaveAttach("side", side)
                UpdatePerLineLabel() -- "auto" reads the direction off the side
            end,
        })
    end
    sideDD:SetItems(sideItems)

    local sideText = cchPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    sideText:SetText(L["Side"])
    P.Point(sideText, "BOTTOMLEFT", sideDD, "TOPLEFT", 0, 1)
    Cell.SetTooltips(sideDD, "ANCHOR_TOPLEFT", 0, 3, L["Side"], L["ATTACH_SIDE_TIPS"])

    -- orientation ----------------------------------------------------------------------
    orientationDD = Cell.CreateDropdown(cchPane, 120)
    P.Point(orientationDD, "TOPLEFT", sizeSlider, "TOPLEFT", 146, -97)

    local orientations = {"auto", "left-to-right", "right-to-left", "top-to-bottom", "bottom-to-top"}
    local items = {}
    for _, orientation in ipairs(orientations) do
        tinsert(items, {
            ["text"] = L[orientation],
            ["value"] = orientation,
            ["onClick"] = function()
                SaveAttach("orientation", orientation)
                UpdatePerLineLabel()
            end,
        })
    end
    orientationDD:SetItems(items)

    local orientationText = cchPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    orientationText:SetText(L["Orientation"])
    P.Point(orientationText, "BOTTOMLEFT", orientationDD, "TOPLEFT", 0, 1)

    -- gap ---------------------------------------------------------------------------------
    --! ⚠ NOT called "spacing": that word is taken two controls to the left, where it means
    --! the distance between two icons. This one is the distance from the bar to the frames.
    gapSlider = Cell.CreateSlider(L["Frame Distance"], cchPane, 0, 40, 120, 1, function(value)
        SaveAttach("gap", value)
    end)
    P.Point(gapSlider, "TOPLEFT", sizeSlider, "TOPLEFT", 292, -97)

    -- text positions -------------------------------------------------------------------
    --! Free text rather than sliders: an offset is a number the player already has in mind
    --! ("nudge it up 10"), and four sliders would cost more vertical room than the rest of
    --! this pane put together.
    local function CreateValueBox(key, width, text, anchor, x, y, minV, maxV)
        local eb = Cell.CreateEditBox(cchPane, width, 20)
        valueBoxes[key] = eb
        P.Point(eb, "TOPLEFT", anchor, "TOPLEFT", x, y)
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
        P.Point(fs, "BOTTOMLEFT", eb, "TOPLEFT", 0, 1)
        return eb
    end

    local function CreateAnchorDropdown(key, text, anchor, x, y)
        local dd = Cell.CreateDropdown(cchPane, 100)
        anchorDropdowns[key] = dd
        P.Point(dd, "TOPLEFT", anchor, "TOPLEFT", x, y)

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
        P.Point(fs, "BOTTOMLEFT", dd, "TOPLEFT", 0, 1)
        return dd
    end

    --! ⚠ The offset columns are labelled "X" / "Y", not L["X Offset"] / L["Y Offset"].
    --! Those strings are ~90px in zhTW over a 55px box, so each one ran straight through
    --! its neighbour. A caption may never be wider than the column it belongs to.
    --! One column grid shared by both rows -- anchor, X, Y, size, and one row-specific
    --! extra. Keeping the two rows on the same x positions is what makes them read as a
    --! pair rather than as two unrelated clumps of boxes.
    local COL = {0, 110, 168, 226, 319}

    --! ⚠ Every row from here down hangs off sizeSlider, the top-left control of the block,
    --! rather than off whatever happens to sit at the left of the row above. Two rows now
    --! stand between them (the context buttons and the attach row) and an anchor chain
    --! through those would have to be re-derived every time one of them moves.
    CreateAnchorDropdown("keyAnchor", L["Keybind Position"], sizeSlider, COL[1], -147)
    CreateValueBox("keyX", 50, "X", sizeSlider, COL[2], -147)
    CreateValueBox("keyY", 50, "Y", sizeSlider, COL[3], -147)
    CreateValueBox("keyFontSize", 85, L["Font Size"], sizeSlider, COL[4], -147, 6, 32)

    CreateAnchorDropdown("durationAnchor", L["Duration Position"], sizeSlider, COL[1], -189)
    CreateValueBox("durationX", 50, "X", sizeSlider, COL[2], -189)
    CreateValueBox("durationY", 50, "Y", sizeSlider, COL[3], -189)
    CreateValueBox("durationFontSize", 85, L["Font Size"], sizeSlider, COL[4], -189, 6, 32)
    CreateValueBox("durationThreshold", 85, L["Duration Threshold"], sizeSlider, COL[5], -189, 0, 3600)

    -- key labels -----------------------------------------------------------------------
    --! The mouse rows are labelled WITH the glyph, not just with a name. It is the only
    --! place a player can find out what the picture on their bar means, and it doubles as
    --! a preview of what they are about to replace.
    local function CreateLabelBox(key, width, text, anchor, x, y)
        local eb = Cell.CreateEditBox(cchPane, width, 20)
        labelBoxes[key] = eb
        P.Point(eb, "TOPLEFT", anchor, "TOPLEFT", x, y)
        eb:SetMaxLetters(6) -- "Shift+" has to fit
        eb:SetScript("OnTextChanged", function(self, userChanged)
            if not userChanged then return end
            CellDB["tools"]["clickCastingHints"]["keyLabels"][key] = self:GetText()
            Layout()
        end)

        local fs = cchPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
        fs:SetText(text)
        P.Point(fs, "BOTTOMLEFT", eb, "TOPLEFT", 0, 1)
        return eb
    end

    local function Glyph(file)
        return "|T" .. MOUSE_MEDIA .. file .. ":14:14|t "
    end

    CreateLabelBox("left", 120, Glyph("mouse-left.png") .. L["Left Button"], sizeSlider, 0, -231)
    CreateLabelBox("right", 120, Glyph("mouse-right.png") .. L["Right Button"], sizeSlider, 140, -231)
    CreateLabelBox("middle", 120, Glyph("mouse-middle.png") .. L["Middle Button"], sizeSlider, 280, -231)

    --! plain "Alt" / "Ctrl" / "Shift" rather than ALT_KEY_TEXT and friends: the localised
    --! globals are a mix of cases and lengths ("Alt 鍵" next to "CTRL" next to "SHIFT"),
    --! and these four are read as names, not translated.
    CreateLabelBox("alt", 95, "Alt", sizeSlider, 0, -273)
    CreateLabelBox("ctrl", 95, "Ctrl", sizeSlider, 103, -273)
    CreateLabelBox("shift", 95, "Shift", sizeSlider, 206, -273)
    CreateLabelBox("meta", 95, "Cmd", sizeSlider, 309, -273)

    -- restore defaults -----------------------------------------------------------------
    local tips = cchPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    tips:SetText("|cffababab" .. L["KEY_LABEL_TIPS"])
    tips:SetPoint("BOTTOMLEFT")
    tips:SetPoint("BOTTOMRIGHT")
    tips:SetJustifyH("LEFT")
    tips:SetSpacing(2)

    local resetBtn = Cell.CreateButton(cchPane, L["Restore Defaults"], "red-hover", {110, 20})
    P.Point(resetBtn, "BOTTOMRIGHT", tips, "TOPRIGHT", 0, 4)
    resetBtn:SetScript("OnClick", function()
        -- confirmed, not immediate: this throws away hand-typed key names and the position
        local popup = Cell.CreateConfirmPopup(cchPane, 250, L["RESTORE_DEFAULTS_CONFIRM"],
            RestoreDefaults, nil, true)
        popup:SetPoint("CENTER")
    end)
end

local function LoadDB()
    local db = CellDB["tools"]["clickCastingHints"]
    enabledCB:SetChecked(db["enabled"])
    snapCB:SetChecked(db["snap"])
    showKeysCB:SetChecked(db["showKeys"])
    showTooltipCB:SetChecked(db["showTooltip"])
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
    perLineSlider:SetValue(db["perRow"])
    spacingSlider:SetValue(db["spacing"])

    --! opening the pane starts on the context the player is standing in -- that is the bar
    --! they can see, so it is the one they came here to move
    editing = Context()
    HighlightContext(editing)
    LoadAttachDB()
    UpdatePerLineLabel()

    Cell.SetEnabled(db["enabled"], snapCB, showKeysCB, showTooltipCB, sizeSlider, orientationDD,
        perLineSlider, spacingSlider, partyBtn, raidBtn)
    Cell.SetEnabled(db["enabled"] and db["snap"] and true or false, sideDD, gapSlider)
end

--! Everything except `enabled`. The master switch is not part of "how it looks", and a
--! reset that makes the whole bar disappear reads as a bug rather than as a reset.
function RestoreDefaults()
    local t = CellDB["tools"]["clickCastingHints"]
    local enabled = t["enabled"]

    wipe(t)
    for key, value in pairs(Cell.defaults.clickCastingHints) do
        --! F.Copy is deep, which `attach` needs -- it is a table of tables, and a shallow
        --! copy would hand the saved database the DEFAULTS table's own party/raid entries
        --! to edit in place
        t[key] = type(value) == "table" and F.Copy(value) or value
    end
    t["enabled"] = enabled

    Cell.Fire("UpdateTools", "clickCastingHints")
    Layout() -- the direction may have gone back to "auto"; the placement rides on that
    LoadDB()
end

local init
local function ShowUtilitySettings(which)
    if which == "clickCastingHints" then
        if not init then
            init = true
            CreatePane()
        end

        LoadDB()
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
