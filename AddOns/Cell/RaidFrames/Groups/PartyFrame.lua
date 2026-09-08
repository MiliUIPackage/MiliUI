local _, Cell = ...
local F = Cell.funcs
local B = Cell.bFuncs
local P = Cell.pixelPerfectFuncs

local partyFrame = CreateFrame("Frame", "CellPartyFrame", Cell.frames.mainFrame, "SecureFrameTemplate")
Cell.frames.partyFrame = partyFrame
partyFrame:SetAllPoints(Cell.frames.mainFrame)

local header = CreateFrame("Frame", "CellPartyFrameHeader", partyFrame, "SecureGroupHeaderTemplate")
header:SetAttribute("template", "CellUnitButtonTemplate")

function header:UpdateButtonUnit(bName, unit)
    if not unit then return end

    _G[bName].unit = unit -- OmniCD

    local petUnit, targetUnit
    if unit == "player" then
        petUnit = "pet"
        targetUnit = "target"
    else
        petUnit = string.gsub(unit, "party", "partypet")
        targetUnit = unit.."target"
    end
    Cell.unitButtons.party.units[unit] = _G[bName]
    Cell.unitButtons.party.units[petUnit] = _G[bName].petButton

    -- fix from MiliUI: same bookkeeping for the target button, so F.GetUnitButtonByUnit
    -- (and through it LibGetFrame) can find the frame that is drawing "party2target".
    -- Piggy-backs on the branch above rather than testing `unit` again: on 12.1 a unit
    -- token can be a secret string, and each comparison against a literal is a chance to
    -- feed `if` a secret boolean.
    if _G[bName].targetButton then
        Cell.unitButtons.party.units[targetUnit] = _G[bName].targetButton
    end
end

-- header:SetAttribute("initialConfigFunction", [[
--     RegisterUnitWatch(self)

--     local header = self:GetParent()
--     self:SetWidth(header:GetAttribute("buttonWidth") or 66)
--     self:SetHeight(header:GetAttribute("buttonHeight") or 46)
-- ]])

header:SetAttribute("_initialAttributeNames", "refreshUnitChange")
header:SetAttribute("_initialAttribute-refreshUnitChange", [[
    local unit = self:GetAttribute("unit")
    local header = self:GetParent()
    local petButton = self:GetFrameRef("petButton")

    -- print(self:GetName(), unit, petButton)

    if petButton and header:GetAttribute("showPartyPets") and not header:GetAttribute("partyDetached") then
        local petUnit
        if unit == "player" then
            petUnit = "pet"
        else
            petUnit = string.gsub(unit, "party", "partypet")
        end
        petButton:SetAttribute("unit", petUnit)
        RegisterUnitWatch(petButton)
    end

    --! fix from MiliUI: party targets. All three attributes are set HERE, in the secure
    --! environment, and not from a Lua OnAttributeChanged hook: the buttons are protected,
    --! SetAttribute on a protected frame is refused in combat, and "who sits in which slot"
    --! is exactly what changes in combat (someone dies out of the party, roles resort).
    --! Blizzard runs this closure for every DISPLAYED child, so `unit` is never nil here;
    --! surplus slots are hidden by the header instead, which hides this child with them.
    local targetButton = self:GetFrameRef("targetButton")
    if targetButton and header:GetAttribute("showPartyTargets") then
        if unit == "player" then
            targetButton:SetAttribute("unit", "target")
            targetButton:SetAttribute("refreshOnUpdate", nil)
            targetButton:SetAttribute("updateOnTargetChanged", true)
        else
            targetButton:SetAttribute("unit", unit.."target")
            --! no UNIT_TARGET-style event reaches a partyNtarget token, so this one rides
            --! the shared 0.25s tick driver, exactly as a Spotlight bound to "XXtarget" does
            targetButton:SetAttribute("refreshOnUpdate", true)
            targetButton:SetAttribute("updateOnTargetChanged", nil)
        end
        RegisterUnitWatch(targetButton)
    end

    header:CallMethod("UpdateButtonUnit", self:GetName(), unit)
]])

header:SetAttribute("point", "TOP")
header:SetAttribute("xOffset", 0)
header:SetAttribute("yOffset", -1)
header:SetAttribute("maxColumns", 1)
header:SetAttribute("unitsPerColumn", 5)
header:SetAttribute("showPlayer", true)
header:SetAttribute("showParty", true)

--! to make needButtons == 5 cheat configureChildren in SecureGroupHeaders.lua
header:SetAttribute("startingIndex", -4)
header:Show()
header:SetAttribute("startingIndex", 1)

-- init pet buttons
for i, playerButton in ipairs(header) do
    -- playerButton.type = "main" -- layout setup

    local petButton = CreateFrame("Button", playerButton:GetName().."Pet", playerButton, "CellUnitButtonTemplate")
    -- petButton.type = "pet" -- layout setup
    petButton:SetIgnoreParentAlpha(true)

    --! button for pet/vehicle only, toggleForVehicle MUST be false
    petButton:SetAttribute("toggleForVehicle", false)

    playerButton.petButton = petButton
    SecureHandlerSetFrameRef(playerButton, "petButton", petButton)

    -- fix from MiliUI: party targets -- one full unit button per slot, showing that
    -- member's target. A plain CellUnitButtonTemplate on purpose: health, name, class
    -- colour, the 12.1 secret-value handling and click-casting all come with it, and
    -- left-click-to-target is already Cell's default click-cast.
    local targetButton = CreateFrame("Button", playerButton:GetName().."Target", playerButton, "CellUnitButtonTemplate")
    targetButton:SetIgnoreParentAlpha(true)
    --! the token is always "<member>target", never a vehicle of one
    targetButton:SetAttribute("toggleForVehicle", false)
    --! borrowed from the Spotlight buttons: a target button does NOT own the unit it is
    --! showing. Letting it write Cell.vars.guids / Cell.vars.names would point the shared
    --! guid->unit map at "party2target" the moment somebody targets a party member, and
    --! every guid-routed update (CLEU health, comms, nicknames) would follow it there.
    targetButton.isSpotlight = true
    --! read in UnitButton.lua: no role icon, raid marker always on, health bar coloured by
    --! reaction instead of Cell's flat "friendly NPC" green
    targetButton.isPartyTarget = true

    playerButton.targetButton = targetButton
    SecureHandlerSetFrameRef(playerButton, "targetButton", targetButton)

    -- for IterateAllUnitButtons
    Cell.unitButtons.party["player"..i] = playerButton
    Cell.unitButtons.party["pet"..i] = petButton
    Cell.unitButtons.partyTarget[i] = targetButton

    -- OmniCD
    _G["CellPartyFrameMember"..i] = playerButton
end

-------------------------------------------------
-- fix from MiliUI: party targets
--
-- Geometry only. WHICH unit each button shows is decided in the secure snippet above --
-- never here -- because the roster changes in combat and Lua may not touch a protected
-- frame's attributes then.
-------------------------------------------------
local function GetPartyTargetsDB()
    return CellDB and CellDB["tools"] and CellDB["tools"]["partyTargets"]
end

local function SetPartyTargetSize(b, layout)
    local db = GetPartyTargetsDB()
    local width, height = unpack(layout["main"]["size"])
    -- 0 means "same as the main button"; height always follows the main button, so a
    -- target sits level with the member it belongs to whatever the width is set to
    local w = db and db["width"] or 0
    P.Size(b, w > 0 and w or width, height)
end

local function SetPartyTargetPoint(b, playerButton, orientation)
    local db = GetPartyTargetsDB()
    local spacing = P.Scale(db and db["spacing"] or 3)
    local side = db and db["side"] or "right"

    b:ClearAllPoints()
    if orientation == "vertical" then
        if side == "left" then
            b:SetPoint("TOPRIGHT", playerButton, "TOPLEFT", -spacing, 0)
        else
            b:SetPoint("TOPLEFT", playerButton, "TOPRIGHT", spacing, 0)
        end
    else
        --! the party frame itself runs sideways here, so left/right would land on the
        --! neighbouring slot. Same setting, rotated: "left" reads as above, "right" as below.
        if side == "left" then
            b:SetPoint("BOTTOMLEFT", playerButton, "TOPLEFT", 0, spacing)
        else
            b:SetPoint("TOPLEFT", playerButton, "BOTTOMLEFT", 0, -spacing)
        end
    end
end

--! The pet button and the target button both hang off the side of a member, so with both
--! shown they have to take opposite sides or they land on top of each other. The player
--! picks the TARGET's side; the pet takes whatever is left, overriding the side Cell
--! derives from the layout anchor. Returns true when that override is needed.
local function WantPetFlip(layout)
    local db = GetPartyTargetsDB()
    if not (db and db["enabled"]) then return false end
    if not (layout["pet"]["partyEnabled"] and not layout["pet"]["partyDetached"]) then return false end

    local anchor = layout["main"]["anchor"]
    local side = db["side"] or "right"
    if layout["main"]["orientation"] == "vertical" then
        -- an anchor ending in LEFT puts the pet on the member's right (see the table below)
        return (strfind(anchor, "LEFT$") ~= nil) == (side == "right")
    else
        -- an anchor starting with BOTTOM puts the pet above the member
        return (strfind(anchor, "^BOTTOM") ~= nil) == (side == "left")
    end
end

--! Mirror an anchor point across the axis the pet is offset on: LEFT<->RIGHT when the party
--! frame runs down the screen, TOP<->BOTTOM when it runs across. Safe on the compound names
--! ("BOTTOMLEFT" contains neither "TOP" nor, after the LEFT swap, a second match).
local function FlipPetPoint(p, orientation)
    if orientation == "vertical" then
        if strfind(p, "RIGHT") then return (gsub(p, "RIGHT", "LEFT")) end
        return (gsub(p, "LEFT", "RIGHT"))
    end
    if strfind(p, "TOP") then return (gsub(p, "TOP", "BOTTOM")) end
    return (gsub(p, "BOTTOM", "TOP"))
end

--! what the last arrangement pass actually applied, so the tool knows when the pets need
--! moving and can leave them alone the rest of the time
local petFlipApplied = false

local PartyFrame_UpdateLayout

local partyTargetsDelay = CreateFrame("Frame")
partyTargetsDelay:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    F.UpdatePartyTargets()
end)

--! Every line below is a protected action on a protected frame -- SetSize, SetPoint,
--! SetAttribute, Register/UnregisterUnitWatch -- and all of them are refused in combat.
--! Cell's own F.UpdateLayout defers the same way; this needs its own because the tool can
--! be switched on from the options pane, which opens in combat.
--!
--! Exported rather than reached through Cell.Fire("UpdateLayout", ..., "partyTargets"):
--! three of the UpdateLayout listeners ignore `which` and rebuild their preview button on
--! every fire, and the spacing/width sliders fire once per step while being dragged.
function F.UpdatePartyTargets()
    local layout = Cell.vars.currentLayoutTable
    if not layout then return end

    if InCombatLockdown() then
        partyTargetsDelay:RegisterEvent("PLAYER_REGEN_ENABLED")
        return
    end
    partyTargetsDelay:UnregisterEvent("PLAYER_REGEN_ENABLED")

    local db = GetPartyTargetsDB()
    local enabled = db and db["enabled"] and true or false
    local orientation = layout["main"]["orientation"]

    for _, playerButton in ipairs(header) do
        local b = playerButton.targetButton
        SetPartyTargetSize(b, layout)
        SetPartyTargetPoint(b, playerButton, orientation)
        -- NOTE: SetOrientation BEFORE SetPowerSize
        B.SetOrientation(b, layout["barOrientation"][1], layout["barOrientation"][2])
        B.SetPowerSize(b, layout["main"]["powerSize"])

        if not enabled then
            UnregisterUnitWatch(b)
            b:SetAttribute("unit", nil)
            b:SetAttribute("refreshOnUpdate", nil)
            b:SetAttribute("updateOnTargetChanged", nil)
            b:Hide()
        end
    end

    --! LAST, and this is what actually turns the tool on: any attribute set on a visible
    --! SecureGroupHeader re-runs configureChildren, which re-runs refreshUnitChange for
    --! every displayed slot -- the snippet then hands out the unit tokens and the unit
    --! watches. There is no Lua path that could do that job: reading a slot's unit back
    --! from Lua would mean comparing a possibly-secret token against "player".
    --! ⚠ Only on a real change. A full secure-header reconfigure (every button repositioned,
    --! the snippet re-run five times) is not what dragging the spacing slider should cost,
    --! and the roster events already re-run it whenever the group actually moves.
    if header:GetAttribute("showPartyTargets") ~= enabled then
        header:SetAttribute("showPartyTargets", enabled)
    end

    --! and if the pets now belong on the other side, re-run the arrangement that places
    --! them. Gated on a real change for the same reason as the attribute above: this is a
    --! full re-anchor of every button and the width slider must not pay for it.
    if PartyFrame_UpdateLayout and WantPetFlip(layout) ~= petFlipApplied then
        PartyFrame_UpdateLayout(Cell.vars.currentLayout, "pet-arrangement")
    end
end

function PartyFrame_UpdateLayout(layout, which)
    -- visibility
    if Cell.vars.groupType ~= "party" or Cell.vars.isHidden then
        UnregisterAttributeDriver(partyFrame, "state-visibility")
        partyFrame:Hide()
        return
    else
        RegisterAttributeDriver(partyFrame, "state-visibility", "[@raid1,exists] hide;[@party1,exists] show;[group:party] show;hide")
    end

    -- update
    layout = CellDB["layouts"][layout]

    -- anchor
    if not which or which == "main-arrangement" or which == "pet-arrangement" then
        local orientation = layout["main"]["orientation"]
        local anchor = layout["main"]["anchor"]
        local spacingX = layout["main"]["spacingX"]
        local spacingY = layout["main"]["spacingY"]
        local petSpacingX = layout["pet"]["sameArrangementAsMain"] and spacingX or layout["pet"]["spacingX"]
        local petSpacingY = layout["pet"]["sameArrangementAsMain"] and spacingY or layout["pet"]["spacingY"]

        local point, playerAnchorPoint, petAnchorPoint, playerSpacing, petSpacing, headerPoint
        if orientation == "vertical" then
            if anchor == "BOTTOMLEFT" then
                point, playerAnchorPoint, petAnchorPoint = "BOTTOMLEFT", "TOPLEFT", "BOTTOMRIGHT"
                headerPoint = "BOTTOM"
                playerSpacing = spacingY
                petSpacing = petSpacingX
            elseif anchor == "BOTTOMRIGHT" then
                point, playerAnchorPoint, petAnchorPoint = "BOTTOMRIGHT", "TOPRIGHT", "BOTTOMLEFT"
                headerPoint = "BOTTOM"
                playerSpacing = spacingY
                petSpacing = -petSpacingX
            elseif anchor == "TOPLEFT" then
                point, playerAnchorPoint, petAnchorPoint = "TOPLEFT", "BOTTOMLEFT", "TOPRIGHT"
                headerPoint = "TOP"
                playerSpacing = -spacingY
                petSpacing = petSpacingX
            elseif anchor == "TOPRIGHT" then
                point, playerAnchorPoint, petAnchorPoint = "TOPRIGHT", "BOTTOMRIGHT", "TOPLEFT"
                headerPoint = "TOP"
                playerSpacing = -spacingY
                petSpacing = -petSpacingX
            end

            header:SetAttribute("xOffset", 0)
            header:SetAttribute("yOffset", P.Scale(playerSpacing))
        else
            -- anchor
            if anchor == "BOTTOMLEFT" then
                point, playerAnchorPoint, petAnchorPoint = "BOTTOMLEFT", "BOTTOMRIGHT", "TOPLEFT"
                headerPoint = "LEFT"
                playerSpacing = spacingX
                petSpacing = petSpacingY
            elseif anchor == "BOTTOMRIGHT" then
                point, playerAnchorPoint, petAnchorPoint = "BOTTOMRIGHT", "BOTTOMLEFT", "TOPRIGHT"
                headerPoint = "RIGHT"
                playerSpacing = -spacingX
                petSpacing = petSpacingY
            elseif anchor == "TOPLEFT" then
                point, playerAnchorPoint, petAnchorPoint = "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT"
                headerPoint = "LEFT"
                playerSpacing = spacingX
                petSpacing = -petSpacingY
            elseif anchor == "TOPRIGHT" then
                point, playerAnchorPoint, petAnchorPoint = "TOPRIGHT", "TOPLEFT", "BOTTOMRIGHT"
                headerPoint = "RIGHT"
                playerSpacing = -spacingX
                petSpacing = -petSpacingY
            end

            header:SetAttribute("xOffset", P.Scale(playerSpacing))
            header:SetAttribute("yOffset", 0)
        end

        header:ClearAllPoints()
        header:SetPoint(point)
        header:SetAttribute("point", headerPoint)

        --! force update unitbutton's point
        -- fix from MiliUI: push the pets to the side the target buttons are not using
        petFlipApplied = WantPetFlip(layout)
        local petPoint, petRelPoint = point, petAnchorPoint
        if petFlipApplied then
            petPoint = FlipPetPoint(point, orientation)
            petRelPoint = FlipPetPoint(petAnchorPoint, orientation)
            petSpacing = -petSpacing
        end

        for j = 1, 5 do
            header[j]:ClearAllPoints()
            -- update petButton's point
            header[j].petButton:ClearAllPoints()
            if orientation == "vertical" then
                header[j].petButton:SetPoint(petPoint, header[j], petRelPoint, P.Scale(petSpacing), 0)
            else
                header[j].petButton:SetPoint(petPoint, header[j], petRelPoint, 0, P.Scale(petSpacing))
            end
            -- fix from MiliUI: the target button rides the main orientation, not the pet anchor
            SetPartyTargetPoint(header[j].targetButton, header[j], orientation)
        end
        header:SetAttribute("unitsPerColumn", 5)
    end

    if not which or strfind(which, "size$") or strfind(which, "power$") or which == "barOrientation" or which == "powerFilter" then
        for i, playerButton in ipairs(header) do
            local petButton = playerButton.petButton

            -- fix from MiliUI: party targets
            local targetButton = playerButton.targetButton

            if not which or strfind(which, "size$") then
                local width, height = unpack(layout["main"]["size"])
                P.Size(playerButton, width, height)
                header:SetAttribute("buttonWidth", P.Scale(width))
                header:SetAttribute("buttonHeight", P.Scale(height))
                if layout["pet"]["sameSizeAsMain"] then
                    P.Size(petButton, width, height)
                else
                    P.Size(petButton, layout["pet"]["size"][1], layout["pet"]["size"][2])
                end
                SetPartyTargetSize(targetButton, layout)
            end

            -- NOTE: SetOrientation BEFORE SetPowerSize
            if not which or which == "barOrientation" then
                B.SetOrientation(playerButton, layout["barOrientation"][1], layout["barOrientation"][2])
                B.SetOrientation(petButton, layout["barOrientation"][1], layout["barOrientation"][2])
                B.SetOrientation(targetButton, layout["barOrientation"][1], layout["barOrientation"][2])
            end

            if not which or strfind(which, "power$") or which == "barOrientation" or which == "powerFilter" then
                B.SetPowerSize(playerButton, layout["main"]["powerSize"])
                if layout["pet"]["sameSizeAsMain"] then
                    B.SetPowerSize(petButton, layout["main"]["powerSize"])
                else
                    B.SetPowerSize(petButton, layout["pet"]["powerSize"])
                end
                B.SetPowerSize(targetButton, layout["main"]["powerSize"])
            end
        end
    end

    if not which or which == "pet" then
        header:SetAttribute("showPartyPets", layout["pet"]["partyEnabled"])
        header:SetAttribute("partyDetached", layout["pet"]["partyDetached"])
        if layout["pet"]["partyEnabled"] and not layout["pet"]["partyDetached"] then
            for i, playerButton in ipairs(header) do
                RegisterUnitWatch(playerButton.petButton)
            end
        else
            for i, playerButton in ipairs(header) do
                UnregisterUnitWatch(playerButton.petButton)
                playerButton.petButton:Hide()
            end
        end
    end

    -- fix from MiliUI: party targets
    if not which then
        F.UpdatePartyTargets()
    end

    if not which or which == "sort" then
        if layout["main"]["sortByRole"] then
            header:SetAttribute("sortMethod", "NAME")
            local order = table.concat(layout["main"]["roleOrder"], ",")..",NONE"
            header:SetAttribute("groupingOrder", order)
            header:SetAttribute("groupBy", "ASSIGNEDROLE")
        else
            header:SetAttribute("sortMethod", "INDEX")
            header:SetAttribute("groupingOrder", "")
            header:SetAttribute("groupBy", nil)
        end
    end

    if not which or which == "hideSelf" then
        header:SetAttribute("showPlayer", not layout["main"]["hideSelf"])
    end
end
Cell.RegisterCallback("UpdateLayout", "PartyFrame_UpdateLayout", PartyFrame_UpdateLayout)

-- local function PartyFrame_UpdateVisibility(which)
--     if not which or which == "party" then
--         header:SetAttribute("showParty", CellDB["general"]["showParty"])
--         if CellDB["general"]["showParty"] then
--             --! [group] won't fire during combat
--             -- RegisterAttributeDriver(partyFrame, "state-visibility", "[group:raid] hide; [group:party] show; hide")
--             -- NOTE: [group:party] show: fix for premade, only player in party, but party1 not exists
--             RegisterAttributeDriver(partyFrame, "state-visibility", "[@raid1,exists] hide;[@party1,exists] show;[group:party] show;hide")
--         else
--             UnregisterAttributeDriver(partyFrame, "state-visibility")
--             partyFrame:Hide()
--         end
--     end
-- end
-- Cell.RegisterCallback("UpdateVisibility", "PartyFrame_UpdateVisibility", PartyFrame_UpdateVisibility)

-- local f = CreateFrame("Frame", nil, CellParent, "SecureFrameTemplate")
-- RegisterAttributeDriver(f, "state-group", "[@raid1,exists] raid;[@party1,exists] party; solo")
-- SecureHandlerWrapScript(f, "OnAttributeChanged", f, [[
--     print(name, value)
--     if name ~= "state-group" then return end
-- ]])

-- RegisterStateDriver(f, "groupstate", "[group:raid] raid; [group:party] party; solo")
-- f:SetAttribute("_onstate-groupstate", [[
--     print(stateid, newstate)
-- ]])
