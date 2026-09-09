local _, Cell = ...
local L = Cell.L
local F = Cell.funcs
local P = Cell.pixelPerfectFuncs

-------------------------------------------------
-- party targets
-------------------------------------------------
--! Settings only. The buttons themselves live in RaidFrames/Groups/PartyFrame.lua, next to
--! the pet buttons, because they have to be created as children of the secure group header's
--! own children and handed out their unit token from the header's secure snippet -- the
--! roster resorts in combat, and Lua may not set an attribute on a protected frame then.
--!
--! Nothing here reads a unit. The buttons are plain CellUnitButtonTemplates, so the 12.1
--! secret-value handling (a target can be an NPC nobody is allowed to identify: secret name,
--! secret reaction, secret GUID) is whatever Cell already does for a Spotlight bound to
--! "XXtarget". See .claude/notes/wow-121-unit-api-secrets.md.

-------------------------------------------------
-- defaults
-------------------------------------------------
--! ⚠ ONE copy of these values, here, because two things read them: Core's per-key top-up
--! (which fills whatever a saved database is missing) and the "restore defaults" button.
--! Written out twice they drift, and the drift is invisible.
--! Read at ADDON_LOADED, which fires after every file in the addon has run, so Core can use
--! it even though this file loads long after Core.lua.
Cell.defaults.partyTargets = {
    ["enabled"] = false,
    -- which side of the party button the target sits on. Rotated by the party frame's own
    -- orientation, because left/right on a sideways party frame lands on the next member:
    -- vertical -> left | right, horizontal -> above | below.
    ["side"] = "right",
    ["spacing"] = 3,
    -- 0 = as wide as the main button. The HEIGHT always follows the main button, so a target
    -- stays level with the member it belongs to no matter what this is set to.
    ["width"] = 0,
    --! Health bar colours. The shipped values are the pack's nameplate palette (they are the
    --! reaction + eliteType layers of MiliUI/Config/Luxthos_Platynator.lua), so a target on
    --! this row reads the same as the nameplate over the same mob -- but they are SETTINGS,
    --! not constants: the nameplate addon keeps its copy in its own saved variables and
    --! offers no way to ask, so the two can only be kept together by hand.
    --! Read in RaidFrames/UnitButton.lua; the two lists there decide which one wins.
    ["colors"] = {
        -- a mob that still owes you an objective. Open world only: the tooltip it is read
        -- from does not exist for a unit you may not identify, which is everything indoors.
        ["quest"]      = {1, 0.5882353, 0.1607843},
        -- by reaction, anywhere
        ["tapped"]     = {0.4313725, 0.4313725, 0.4313725}, -- someone else's kill
        ["hostile"]    = {0.7294118, 0.1411765, 0.1686275},
        ["unfriendly"] = {1, 0.5058824, 0},
        ["neutral"]    = {0.8588236, 0.7176471, 0.3176471},
        ["friendly"]   = {0.2745098, 0.8862746, 0.3372549},
        -- by kind, inside dungeons and raids only, and never over a neutral. Wins over the
        -- reaction colours above: in there everything is hostile, so "what kind is it" is
        -- the question worth a colour.
        ["boss"]       = {0.7372549, 0.1098039, 0},
        ["miniboss"]   = {0.5647059, 0, 0.7372549},
        ["caster"]     = {0, 0.6431373, 1},
        ["melee"]      = {0.7803922, 0.6196079, 0.3686275},
        ["trivial"]    = {0.4705883, 0.4039216, 0.3254902},
    },
}

--! The palette, grouped the way the settings pane draws it and in the order the colours are
--! consulted: quest wins over kind, kind wins over reaction.
Cell.partyTargetColorGroups = {
    {["heading"] = "Quest", ["keys"] = {"quest"}},
    {["heading"] = "Elite Type", ["keys"] = {"boss", "miniboss", "caster", "melee", "trivial"}},
    {["heading"] = "Reaction", ["keys"] = {"tapped", "hostile", "unfriendly", "neutral", "friendly"}},
}

-------------------------------------------------
-- callbacks
-------------------------------------------------
local function UpdateTools(which)
    if not which or which == "partyTargets" then
        --! straight to the party frame rather than through Cell.Fire("UpdateLayout", ...):
        --! three UpdateLayout listeners ignore `which` and rebuild a preview button on every
        --! fire, and the sliders below fire once per step while being dragged.
        if F.UpdatePartyTargets then F.UpdatePartyTargets() end
    end
end
Cell.RegisterCallback("UpdateTools", "PartyTargets_UpdateTools", UpdateTools)

-------------------------------------------------
-- settings pane
-------------------------------------------------
local ptPane, enabledCB, sideDD, spacingSlider, widthSlider
local colorPickers = {}
--! forward declaration: CreatePane's reset button closes over it, and a GLOBAL here would
--! be shared with every other utility that has a reset button -- last file loaded wins
local RestoreDefaults

local function Save(key, value)
    CellDB["tools"]["partyTargets"][key] = value
    Cell.Fire("UpdateTools", "partyTargets")
end

local function CreatePane()
    ptPane = Cell.CreateTitledPane(Cell.frames.utilitiesTab, L["Party Targets"], 422, 190)
    ptPane:SetPoint("TOPLEFT", 5, -5)
    ptPane:SetPoint("BOTTOMRIGHT", -5, 5)

    -- enabled --------------------------------------------------------------------------
    enabledCB = Cell.CreateCheckButton(ptPane, L["Party Targets"], function(checked)
        Cell.SetEnabled(checked, sideDD, spacingSlider, widthSlider)
        for _, cp in pairs(colorPickers) do cp:SetEnabled(checked) end
        Save("enabled", checked)
    end, L["Party Targets"], L["PARTY_TARGETS_TIPS"])
    P.Point(enabledCB, "TOPLEFT", ptPane, "TOPLEFT", 5, -27)
    Cell.RegisterForCloseDropdown(enabledCB)

    -- side -----------------------------------------------------------------------------
    sideDD = Cell.CreateDropdown(ptPane, 120)
    P.Point(sideDD, "TOPLEFT", enabledCB, "TOPLEFT", 0, -55)
    sideDD:SetItems({
        --! L["LEFT"] / L["RIGHT"], not L["Left"] / L["Right"]: on zhCN the latter pair is
        --! translated as the MOUSE buttons ("左键" / "右键"), not as directions
        {["text"] = L["LEFT"], ["value"] = "left", ["onClick"] = function() Save("side", "left") end},
        {["text"] = L["RIGHT"], ["value"] = "right", ["onClick"] = function() Save("side", "right") end},
    })

    local sideText = ptPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    sideText:SetText(L["Side"])
    P.Point(sideText, "BOTTOMLEFT", sideDD, "TOPLEFT", 0, 1)
    Cell.SetTooltips(sideDD, "ANCHOR_TOPLEFT", 0, 3, L["Side"], L["PARTY_TARGETS_SIDE_TIPS"])

    -- spacing --------------------------------------------------------------------------
    spacingSlider = Cell.CreateSlider(L["Spacing"], ptPane, 0, 10, 120, 1, function(value)
        Save("spacing", value)
    end)
    P.Point(spacingSlider, "TOPLEFT", sideDD, "TOPLEFT", 146, 0)

    -- width ----------------------------------------------------------------------------
    widthSlider = Cell.CreateSlider(L["Width"], ptPane, 0, 200, 120, 1, function(value)
        Save("width", value)
    end, nil, nil, L["Width"], L["PARTY_TARGETS_WIDTH_TIPS"])
    P.Point(widthSlider, "TOPLEFT", spacingSlider, "TOPLEFT", 146, 0)

    -- colours ---------------------------------------------------------------------------
    --! One row per group, headed by the group's name. Five to a row at 80pt: the widest
    --! label in any group is three characters, so the last swatch still lands inside the
    --! pane. Widen a label and check this before shipping -- there is no wrapping, the
    --! fifth one just walks off the edge.
    local anchor, yOffset = spacingSlider, -55
    for _, group in ipairs(Cell.partyTargetColorGroups) do
        local text = ptPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
        text:SetText(L[group["heading"]])
        P.Point(text, "TOPLEFT", anchor, "TOPLEFT", 0, yOffset)

        for i, key in ipairs(group["keys"]) do
            local cp = Cell.CreateColorPicker(ptPane, L[key], false, function(r, g, b)
                local c = CellDB["tools"]["partyTargets"]["colors"][key]
                c[1], c[2], c[3] = r, g, b
                --! not Save(): the table is edited in place, so there is nothing to assign
                Cell.Fire("UpdateTools", "partyTargets")
            end)
            colorPickers[key] = cp
            P.Point(cp, "TOPLEFT", text, "BOTTOMLEFT", (i - 1) * 80, -4)
        end

        anchor, yOffset = text, -42
    end

    -- restore defaults -----------------------------------------------------------------
    local tips = ptPane:CreateFontString(nil, "OVERLAY", "CELL_FONT_WIDGET")
    tips:SetText("|cffababab" .. L["PARTY_TARGETS_PANE_TIPS"])
    tips:SetPoint("BOTTOMLEFT")
    tips:SetPoint("BOTTOMRIGHT")
    tips:SetJustifyH("LEFT")
    tips:SetSpacing(2)

    --! no confirmation popup, unlike the click-casting hints pane: there are three cosmetic
    --! numbers behind this button and nothing hand-typed, so a popup would cost more than
    --! the mistake it is guarding against
    local resetBtn = Cell.CreateButton(ptPane, L["Restore Defaults"], "red-hover", {110, 20})
    P.Point(resetBtn, "BOTTOMRIGHT", tips, "TOPRIGHT", 0, 4)
    resetBtn:SetScript("OnClick", function()
        RestoreDefaults()
    end)
end

local function LoadDB()
    local db = CellDB["tools"]["partyTargets"]
    enabledCB:SetChecked(db["enabled"])
    sideDD:SetSelectedValue(db["side"])
    spacingSlider:SetValue(db["spacing"])
    widthSlider:SetValue(db["width"])
    for key, cp in pairs(colorPickers) do
        cp:SetColor(db["colors"][key])
        cp:SetEnabled(db["enabled"])
    end
    Cell.SetEnabled(db["enabled"], sideDD, spacingSlider, widthSlider)
end

--! Everything except `enabled`. The master switch is not part of "how it looks", and a reset
--! that makes the buttons disappear reads as a bug rather than as a reset.
function RestoreDefaults()
    local t = CellDB["tools"]["partyTargets"]
    local enabled = t["enabled"]

    wipe(t)
    for key, value in pairs(Cell.defaults.partyTargets) do
        t[key] = type(value) == "table" and F.Copy(value) or value
    end
    t["enabled"] = enabled

    Cell.Fire("UpdateTools", "partyTargets")
    LoadDB()
end

local init
local function ShowUtilitySettings(which)
    if which == "partyTargets" then
        if not init then
            init = true
            CreatePane()
        end

        LoadDB()
        ptPane:Show()

    elseif init then
        ptPane:Hide()
    end
end
Cell.RegisterCallback("ShowUtilitySettings", "PartyTargets_ShowUtilitySettings", ShowUtilitySettings)
