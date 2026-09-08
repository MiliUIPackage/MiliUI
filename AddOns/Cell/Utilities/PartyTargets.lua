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
