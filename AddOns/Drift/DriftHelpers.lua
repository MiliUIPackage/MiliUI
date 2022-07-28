--------------------------------------------------------------------------------
-- Setup
--------------------------------------------------------------------------------

-- Variables for holding functions
DriftHelpers = {}

-- Variables for moving
if not DriftPoints then DriftPoints = {} end
local ALPHA_DURING_MOVE = 0.3 -- TODO: Configurable

-- Variables for timer
DriftHelpers.waitTable = {}
DriftHelpers.resetTable = {}
DriftHelpers.waitFrame = nil

-- Variables for scaling
local MAX_SCALE = 1.5 -- TODO: Configurable
local MIN_SCALE = 0.5 -- TODO: Configurable
local SCALE_INCREMENT = 0.01 -- TODO: Configurable
local ALPHA_DURING_SCALE = 0.3 -- TODO: Configurable
DriftHelpers.scaleHandlerFrame = nil
DriftHelpers.prevMouseX = nil
DriftHelpers.prevMouseY = nil
DriftHelpers.frameBeingScaled = nil
if not DriftScales then DriftScales = {} end

-- Variables for Minimap
local phantomMinimapCluster = nil

-- Variables for Objective Tracker
local OBJECTIVE_TRACKER_HEIGHT = 0.5 -- TODO: Configurable

-- Variables for Collections Journal
local collectionsJournalMover = CreateFrame("Frame", "CollectionsJournalMover", UIParent)
local collectionsJournalMoverTexture = collectionsJournalMover:CreateTexture(nil, "BACKGROUND")

-- Variables for WoW version 
local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local isClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
local isBCC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)

-- Other variables
local hasFixedPVPTalentList = false
local hasFixedPlayerChoice = false
local hasFixedObjectiveTracker = false
local hasFixedMinimap = false
local hasFixedCollections = false
local hasFixedArena = false
local hasFixedManageFramePositions = false


--------------------------------------------------------------------------------
-- Core Logic
--------------------------------------------------------------------------------

-- Local functions
local function getInCombatLockdown()
    return InCombatLockdown()
end

local function frameCannotBeModified(frame)
    -- Do not reset protected frame if in combat to avoid Lua errors
    -- Refer to https://wowwiki.fandom.com/wiki/API_InCombatLockdown
    return frame:IsProtected() and getInCombatLockdown()
end

local function shouldMove(frame)
    if frameCannotBeModified(frame) then
        print("|cFFFFFF00移動和縮放視窗:|r 戰鬥中無法移動 " .. frame:GetName() .. "。")
        return false
    end

    if not DriftOptions.frameDragIsLocked then
        return true
    elseif ((DriftOptions.dragAltKeyEnabled and IsAltKeyDown()) or
            (DriftOptions.dragCtrlKeyEnabled and IsControlKeyDown()) or
            (DriftOptions.dragShiftKeyEnabled and IsShiftKeyDown())) then
        return true
    else
        return false
    end
end

local function shouldScale(frame)
    if frameCannotBeModified(frame) then
        print("|cFFFFFF00移動和縮放視窗:|r 戰鬥中無法縮放 " .. frame:GetName() .. "。")
        return false
    end

    if not DriftOptions.frameScaleIsLocked then
        return true
    elseif ((DriftOptions.scaleAltKeyEnabled and IsAltKeyDown()) or
            (DriftOptions.scaleCtrlKeyEnabled and IsControlKeyDown()) or
            (DriftOptions.scaleShiftKeyEnabled and IsShiftKeyDown())) then
        return true
    else
        return false
    end
end

local function getFrame(frameName)
    if not frameName then
        return nil
    end

    -- First check global table
    local frame = _G[frameName]
    if frame then
        return frame
    end

    -- Try splitting on dot
    local frameNames = {}
    for name in string.gmatch(frameName, "[^%.]+") do
        table.insert(frameNames, name)
    end
    if #frameNames < 2 then
        return nil
    end

    -- Combine
    frame = _G[frameNames[1]]
    if frame then
        for idx = 2, #frameNames do
            frame = frame[frameNames[idx]]
        end
    end

    return frame
end

local function onDragStart(frame, button)
    local frameToMove = frame.DriftDelegate or frame

    -- Left click is move
    if button == "LeftButton" then
        if not shouldMove(frameToMove) then
            return
        end

        -- Prevent scaling while moving
        frame:RegisterForDrag("LeftButton")

        -- Start moving
        frameToMove:StartMoving()

        -- Set alpha
        frameToMove:SetAlpha(ALPHA_DURING_MOVE)

        -- Set the frame as moving
        frameToMove.DriftIsMoving = true

    -- Right click is scale
    elseif button == "RightButton" then
        if not shouldScale(frameToMove) then
            return
        end

        -- Prevent moving while scaling
        frame:RegisterForDrag("RightButton")

        -- Prevent unscalable frames from being scaled
        if frameToMove.DriftUnscalable then
            print("|cFFFFFF00移動和縮放視窗:|r 不支援縮放視窗 " .. frameToMove:GetName() .. "。")
            return
        end

        -- Set alpha
        frameToMove:SetAlpha(ALPHA_DURING_SCALE)

        -- Set the frame as scaling
        frameToMove.DriftIsScaling = true

        -- Reset the previous mouse position
        DriftHelpers.prevMouseX = nil
        DriftHelpers.prevMouseY = nil

        -- Set the global frame being scaled
        DriftHelpers.frameBeingScaled = frameToMove
    end
end

local function onDragStop(frame)
    local frameToMove = frame.DriftDelegate or frame

    -- Stop moving or scaling and reset alpha
    frameToMove:StopMovingOrSizing()
    frameToMove:SetAlpha(1)

    -- Save position
    if (frameToMove.DriftIsMoving) then
        local point, _, relativePoint, xOfs, yOfs = frameToMove:GetPoint()
        if (point ~= nil and relativePoint ~= nil and xOfs ~= nil and yOfs ~= nil) then
            DriftPoints[frameToMove:GetName()] = {
                ["point"] = point,
                ["relativeTo"] = "UIParent",
                ["relativePoint"] = relativePoint,
                ["xOfs"] = xOfs,
                ["yOfs"] = yOfs
            }

            -- TODO: This is messy
            if ("CollectionsJournal" == frame:GetName()) then
                frame:ClearAllPoints()
                frame:SetPoint(
                    point,
                    "UIParent",
                    relativePoint,
                    xOfs,
                    yOfs
                )
            end
        end
    end
    frameToMove.DriftIsMoving = false

    -- Save scale
    if (frameToMove.DriftIsScaling) then
        DriftScales[frameToMove:GetName()] = frameToMove:GetScale()
    end
    frameToMove.DriftIsScaling = false
    DriftHelpers.frameBeingScaled = nil

    -- Hide GameTooltip
    GameTooltip:Hide()

    -- Allow for dragging with both buttons
    frame:RegisterForDrag("LeftButton", "RightButton")
end

local function resetScaleAndPosition(frame)
    local modifiedSet = {}
    local frameToMove = frame.DriftDelegate or frame

    if frameCannotBeModified(frameToMove) then
        modifiedSet["unmodifiable"] = true
        return modifiedSet
    end

    -- Do not reset if frame is moving or scaling
    if frameToMove.DriftIsMoving or frameToMove.DriftIsScaling then
        modifiedSet["isModifying"] = true
        return modifiedSet
    end

    -- Reset scale
    local scale = DriftScales[frameToMove:GetName()]
    if scale then
        frameToMove:SetScale(scale)
        modifiedSet["scale"] = true
    end

    -- Reset position
    local point = DriftPoints[frameToMove:GetName()]
    if point then
        frameToMove:ClearAllPoints()
        frameToMove:SetPoint(
            point["point"],
            point["relativeTo"],
            point["relativePoint"],
            point["xOfs"],
            point["yOfs"]
        )

        -- TODO: This is messy
        if ("CollectionsJournal" == frame:GetName()) then
            frame:ClearAllPoints()
            frame:SetPoint(
                point["point"],
                point["relativeTo"],
                point["relativePoint"],
                point["xOfs"],
                point["yOfs"]
            )
        end

        modifiedSet["position"] = true
    end

    return modifiedSet
end

local function makeModifiable(frame)
    if frame.DriftModifiable then
        return
    end

    local frameToMove = frame.DriftDelegate or frame
    frame:SetMovable(true)
    frameToMove:SetMovable(true)
    frameToMove:SetUserPlaced(true)
    frameToMove:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton", "RightButton")
    frame:SetScript("OnDragStart", onDragStart)
    frame:SetScript("OnDragStop", onDragStop)
    frame:HookScript("OnHide", onDragStop)

    frame.DriftModifiable = true
end

local function makeSticky(frame, frames)
    if frame.DriftSticky then
        return
    end

    frame:HookScript(
        "OnShow",
        function(self, event, ...)
            resetScaleAndPosition(frame)
            DriftHelpers:BroadcastReset(frames)
        end
    )

    frame:HookScript(
        "OnHide",
        function(self, event, ...)
            DriftHelpers:BroadcastReset(frames)
        end
    )

    frame:HookScript(
        "OnUpdate",
        function(self, event, ...)
            if frame.DriftResetNeeded then
                resetScaleAndPosition(frame)
                frame.DriftResetNeeded = nil
            end
        end
    )

    frame.DriftSticky = true
end

local function makeTabsSticky(frame, frames)
    if frame.DriftTabs then
        for _, tab in pairs(frame.DriftTabs) do
            if not tab.DriftTabSticky then
                tab:HookScript(
                    "OnClick",
                    function(self, event, ...)
                        resetScaleAndPosition(frame)
                        DriftHelpers:BroadcastReset(frames)
                    end
                )
                tab.DriftTabSticky = true
            end
        end
    end
end

local function makeChildMovers(frame, frames)
    -- Exit if not configured
    if not frame.DriftChildMovers then
        return
    end

    -- Exit if already hooked
    if frame.DriftChildMoversHooked then
        return
    end

    -- Run once in case log in to a place with the widget
    local function makeMovers()
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            child.DriftDelegate = frame
            makeModifiable(child)
            makeSticky(child, frames)
            makeTabsSticky(child, frames)
        end
    end
    makeMovers()

    -- Run each time there is an update
    frame:RegisterEvent("UPDATE_UI_WIDGET")
    frame:HookScript(
        "OnEvent",
        function(self, event, ...)
            if event == "UPDATE_UI_WIDGET" then
                makeMovers()
            end
        end
    )

    frame.DriftChildMoversHooked = true
end

-- Global functions
function DriftHelpers:DeleteDriftState()
    -- Delete DriftPoints state
    DriftPoints = {}

    -- SetScale to 1 for each frame
    for frameName, _ in pairs(DriftScales) do
        local frame = getFrame(frameName)
        if frame then
            frame:SetScale(1)
        end
    end

    -- Delete DriftScales state
    DriftScales = {}

    -- Reload UI
    ReloadUI()
end

function DriftHelpers:PrintAllowedCommands()
    print("|cffFFC125Drift:|r Allowed commands:")
    print("|cffFFC125/drift|r - Print allowed commands.")
    print("|cffFFC125/drift help|r - Print help message.")
    print("|cffFFC125/drift version|r - Print addon version.")
    print("|cffFFC125/drift reset|r - Reset position and scale for all modified frames.")
end

function DriftHelpers:PrintHelp()
    local interfaceOptionsLabel = "Interface"
    if (isRetail or isBCC) then
        interfaceOptionsLabel = "Interface"
    elseif (isClassic) then
        interfaceOptionsLabel = "Interface Options"
    end

    print("|cffFFC125Drift:|r Modifies default UI frames so you can click and drag to move and scale. " ..
          "Left-click and drag anywhere to move a frame. " ..
          "Right-click and drag up or down to scale a frame. " ..
          "Position and scale for each frame are saved. " ..
          "For additional configuration options, visit " .. interfaceOptionsLabel .. " -> AddOns -> Drift."
    )
end

function DriftHelpers:PrintVersion()
    print("|cffFFC125Drift:|r Version " .. GetAddOnMetadata("Drift", "Version"))
end

function DriftHelpers:HandleSlashCommands(msg, editBox)
    local cmd = msg
    if (cmd == nil or cmd == "") then
        DriftHelpers:PrintAllowedCommands()
    elseif (cmd == "help") then
        DriftHelpers:PrintHelp()
    elseif (cmd == "version") then
        DriftHelpers:PrintVersion()
    elseif (cmd == "reset") then
        DriftHelpers:DeleteDriftState()
    else
        print("|cffFFC125Drift:|r Unknown command '" .. cmd .. "'")
        DriftHelpers:PrintAllowedCommands()
    end
end

function DriftHelpers:ModifyFrames(frames)
    -- Do not modify frames during combat
    if (getInCombatLockdown()) then
        return
    end

    -- Set up scaling
    if DriftHelpers.scaleHandlerFrame == nil then
        DriftHelpers.scaleHandlerFrame = CreateFrame("Frame", "ScaleHandlerFrame", UIParent)
        DriftHelpers.scaleHandlerFrame:SetScript(
            "OnUpdate",
            function(self)
                if (DriftHelpers.frameBeingScaled) then
                    -- Get current mouse position
                    local curMouseX, curMouseY = GetCursorPosition()

                    -- Only try to scale once there was at least one previous position
                    if DriftHelpers.prevMouseX and DriftHelpers.prevMouseY then
                        if curMouseY > DriftHelpers.prevMouseY then
                            -- Add to scale
                            local newScale = math.min(
                                DriftHelpers.frameBeingScaled:GetScale() + SCALE_INCREMENT,
                                MAX_SCALE
                            )

                            -- Scale
                            DriftHelpers.frameBeingScaled:SetScale(newScale)
                        elseif curMouseY < DriftHelpers.prevMouseY then
                            -- Subtract from scale
                            local newScale = math.max(
                                DriftHelpers.frameBeingScaled:GetScale() - SCALE_INCREMENT,
                                MIN_SCALE
                            )

                            -- Scale
                            DriftHelpers.frameBeingScaled:SetScale(newScale)
                        end
                    end

                    -- Update tooltip
                    GameTooltip:SetOwner(DriftHelpers.frameBeingScaled)
                    GameTooltip:SetText(
                        "" .. math.floor(DriftHelpers.frameBeingScaled:GetScale() * 100) .. "%",
                        1.0, -- red
                        1.0, -- green
                        1.0, -- blue
                        1.0, -- alpha
                        true -- wrap
                    )

                    -- Update previous mouse position
                    DriftHelpers.prevMouseX = curMouseX
                    DriftHelpers.prevMouseY = curMouseY
                end
            end
        )
    end

    for frameName, properties in pairs(frames) do
        local frame = getFrame(frameName)
        if frame then
            if not frame:GetName() then
                frame.GetName = function()
                    return frameName
                end
            end
            if properties.DriftUnscalable then
                frame.DriftUnscalable = true
            end
            if properties.DriftDelegate then
                frame.DriftDelegate = getFrame(properties.DriftDelegate) or frame
            end
            if properties.DriftTabs then
                frame.DriftTabs = {}
                for _, tabName in pairs(properties.DriftTabs) do
                    local tabFrame = getFrame(tabName)
                    if tabFrame then
                        table.insert(frame.DriftTabs, tabFrame)
                    end
                end
            end
            if properties.DriftChildMovers then
                frame.DriftChildMovers = true
            end

            makeModifiable(frame)
            makeSticky(frame, frames)
            makeTabsSticky(frame, frames)
            makeChildMovers(frame, frames)
        end
    end

    -- ClearAllPoints is needed to avoid Lua errors
    if not DriftOptions.windowsDisabled and EncounterJournalTooltip then
        EncounterJournalTooltip:ClearAllPoints()
    end

    -- Modify UpdateContainerFrameAnchors
    if not DriftOptions.bagsDisabled then
        UpdateContainerFrameAnchors = DriftHelpers.UpdateContainerFrameAnchors
    end

    -- Fix PVP talents list
    if not DriftOptions.windowsDisabled then
        DriftHelpers:FixPVPTalentsList(frames)
    end

    -- Fix PlayerChoiceFrame
    if not DriftOptions.windowsDisabled then
        DriftHelpers:FixPlayerChoiceFrame()
    end

    -- Fix Objectives
    if not DriftOptions.objectivesDisabled then
        DriftHelpers:FixObjectiveTrackerFrame()
    end

    -- Fix Minimap
    if not DriftOptions.minimapDisabled then
        DriftHelpers:FixMinimap()
    end

    -- Fix MacroPopupFrame
    if not DriftOptions.windowsDisabled then
        MacroPopupFrame_AdjustAnchors = function() end
    end

    -- Fix CollectionsJournal
    if not DriftOptions.windowsDisabled then
        DriftHelpers:FixCollectionsJournal()
    end

    -- Fix OrderHallTalentFrame
    if not DriftOptions.windowsDisabled and OrderHallTalentFrame then
        DriftHelpers.resetTable["OrderHallTalentFrame"] = OrderHallTalentFrame
    end

    -- Fix LootFrame
    if not DriftOptions.windowsDisabled and LootFrame then
        DriftHelpers.resetTable["LootFrame"] = LootFrame
    end

    -- Fix Arena frames
    if not DriftOptions.arenaDisabled then
        DriftHelpers:FixArenaFrames()
    end

    -- Fix managed frames
    DriftHelpers:FixManagedFrames()

    -- Hook FCF_DockUpdate since it's called at the end of UIParentManageFramePositions
    DriftHelpers:HookFCF_DockUpdate(frames)

    -- Reset everything in case there was a delay
    DriftHelpers:BroadcastReset(frames)
end

function DriftHelpers:UpdateContainerFrameAnchors()
    -- Fix variables that might not exist
    local MINIMUM_CONTAINER_OFFSET_X = MINIMUM_CONTAINER_OFFSET_X or 10
    local CONTAINER_SCALE = CONTAINER_SCALE or 0.75
    local VISIBLE_CONTAINER_SPACING = VISIBLE_CONTAINER_SPACING or 3
    local CONTAINER_WIDTH = CONTAINER_WIDTH or 192

    local containerFrameOffsetX = math.max(CONTAINER_OFFSET_X, MINIMUM_CONTAINER_OFFSET_X)
    local frame, xOffset, yOffset, screenHeight, freeScreenHeight, leftMostPoint, column
    local screenWidth = GetScreenWidth()
    local containerScale = 1
    local leftLimit = 0
    if ( BankFrame:IsShown() ) then
        leftLimit = BankFrame:GetRight() - 25
    end

    while ( containerScale > CONTAINER_SCALE ) do
        screenHeight = GetScreenHeight() / containerScale
        -- Adjust the start anchor for bags depending on the multibars
        xOffset = containerFrameOffsetX / containerScale
        yOffset = CONTAINER_OFFSET_Y / containerScale
        -- freeScreenHeight determines when to start a new column of bags
        freeScreenHeight = screenHeight - yOffset
        leftMostPoint = screenWidth - xOffset
        column = 1
        local frameHeight
        for _, frameName in ipairs(ContainerFrame1.bags) do
            frameHeight = _G[frameName]:GetHeight()
            if ( freeScreenHeight < frameHeight ) then
                -- Start a new column
                column = column + 1
                leftMostPoint = screenWidth - ( column * CONTAINER_WIDTH * containerScale ) - xOffset
                freeScreenHeight = screenHeight - yOffset
            end
            freeScreenHeight = freeScreenHeight - frameHeight - VISIBLE_CONTAINER_SPACING
        end
        if ( leftMostPoint < leftLimit ) then
            containerScale = containerScale - 0.01
        else
            break
        end
    end

    if ( containerScale < CONTAINER_SCALE ) then
        containerScale = CONTAINER_SCALE
    end

    screenHeight = GetScreenHeight() / containerScale
    -- Adjust the start anchor for bags depending on the multibars
    xOffset = containerFrameOffsetX / containerScale
    yOffset = CONTAINER_OFFSET_Y / containerScale
    -- freeScreenHeight determines when to start a new column of bags
    freeScreenHeight = screenHeight - yOffset
    column = 0
    for index, frameName in ipairs(ContainerFrame1.bags) do
        frame = _G[frameName]

        -- Try to apply Drift settings
        local modifiedSet = resetScaleAndPosition(frame)

        -- Conditionally apply containerScale
        if not modifiedSet["scale"] and not (modifiedSet["unmodifiable"] or modifiedSet["isModifying"]) then
            frame:SetScale(containerScale)
        end

        -- Conditionally apply original container position
        if not modifiedSet["position"] and not (modifiedSet["unmodifiable"] or modifiedSet["isModifying"]) then
            frame:ClearAllPoints()
            if ( index == 1 ) then
                -- First bag
                frame:SetPoint("BOTTOMRIGHT", frame:GetParent(), "BOTTOMRIGHT", -xOffset, yOffset )
            elseif ( freeScreenHeight < frame:GetHeight() ) then
                -- Start a new column
                column = column + 1
                freeScreenHeight = screenHeight - yOffset
                frame:SetPoint("BOTTOMRIGHT", frame:GetParent(), "BOTTOMRIGHT", -(column * CONTAINER_WIDTH) - xOffset, yOffset)
            else
                -- Anchor to the previous bag
                frame:SetPoint("BOTTOMRIGHT", ContainerFrame1.bags[index - 1], "TOPRIGHT", 0, CONTAINER_SPACING)
            end
        end

        freeScreenHeight = freeScreenHeight - frame:GetHeight() - VISIBLE_CONTAINER_SPACING
    end
end

-- Make it so clicking Close button for PVP talents causes reset
function DriftHelpers:FixPVPTalentsList(frames)
    if hasFixedPVPTalentList then
        return
    end

    local talentListFrame = _G['PlayerTalentFrameTalentsPvpTalentFrameTalentList']
    if (talentListFrame) then
        talentListFrame:HookScript(
            "OnHide",
            function(self, event, ...)
                DriftHelpers:BroadcastReset(frames)
            end
        )
        hasFixedPVPTalentList = true
    end
end

-- ClearAllPoints OnHide to avoid Lua errors
function DriftHelpers:FixPlayerChoiceFrame()
    if hasFixedPlayerChoice then
        return
    end

    if (PlayerChoiceFrame) then
        PlayerChoiceFrame:HookScript(
            "OnHide",
            function()
                PlayerChoiceFrame:ClearAllPoints()
            end
        )
        hasFixedPlayerChoice = true
    end
end

-- Set height for ObjectiveTrackerFrame so it has enough room
function DriftHelpers:FixObjectiveTrackerFrame()
    if hasFixedObjectiveTracker then
        return
    end

    if (ObjectiveTrackerFrame) then
        local height = GetScreenHeight() * OBJECTIVE_TRACKER_HEIGHT
        ObjectiveTrackerFrame:SetHeight(height)

        -- Hook collapse and expand to avoid dragging minimized
        local ObjectiveTracker_Collapse_Original = ObjectiveTracker_Collapse
        ObjectiveTracker_Collapse = function()
            ObjectiveTrackerFrame:EnableMouse(false)
            ObjectiveTracker_Collapse_Original()
        end

        local ObjectiveTracker_Expand_Original = ObjectiveTracker_Expand
        ObjectiveTracker_Expand = function()
            ObjectiveTrackerFrame:EnableMouse(true)
            ObjectiveTracker_Expand_Original()
        end

        hasFixedObjectiveTracker = true
    end
end

-- Minimap needs to modify its dependents
function DriftHelpers:FixMinimap()
    if hasFixedMinimap then
        return
    end

    -- Create phantom Minimap to trick update functions
    phantomMinimapCluster = CreateFrame("Frame", "PhantomMinimapCluster", UIParent)
    phantomMinimapCluster:SetFrameStrata("BACKGROUND")
    phantomMinimapCluster:SetWidth(MinimapCluster:GetWidth())
    phantomMinimapCluster:SetHeight(MinimapCluster:GetHeight())
    phantomMinimapCluster:SetPoint("TOPRIGHT")

    -- Override Minimap functions to trick Multibar update
    MinimapCluster.GetBottom = function ()
        return phantomMinimapCluster:GetBottom()
    end

    -- Retail fixes
    if isRetail then
        -- Hook UIParent_UpdateTopFramePositions to fix buffs
        local UIParent_UpdateTopFramePositions_Original = UIParent_UpdateTopFramePositions
        UIParent_UpdateTopFramePositions = function ()
            local MinimapCluster_Original = MinimapCluster
            MinimapCluster = phantomMinimapCluster
            UIParent_UpdateTopFramePositions_Original()
            MinimapCluster = MinimapCluster_Original
        end

        -- Avoid errors in UIParentManageFramePositions
        ObjectiveTrackerFrame:SetMovable(true)
        ObjectiveTrackerFrame:SetUserPlaced(true)

        -- Hook UpdateContainerFrameAnchors to fix modifications in UIParentManageFramePositions
        local UpdateContainerFrameAnchors_Original = UpdateContainerFrameAnchors
        UpdateContainerFrameAnchors = function()
            UpdateContainerFrameAnchors_Original()
            DriftHelpers:FixMinimapDependentFramesRetail()
        end
    end

    -- Classic fixes
    if isClassic then
        -- Hook UpdateContainerFrameAnchors to fix modifications in UIParentManageFramePositions
        local UpdateContainerFrameAnchors_Original = UpdateContainerFrameAnchors
        UpdateContainerFrameAnchors = function()
            UpdateContainerFrameAnchors_Original()
            DriftHelpers:FixMinimapDependentFramesClassic()
        end
    end

    -- BCC fixes
    if isBCC then
        -- Hook UpdateContainerFrameAnchors to fix modifications in UIParentManageFramePositions
        local UpdateContainerFrameAnchors_Original = UpdateContainerFrameAnchors
        UpdateContainerFrameAnchors = function()
            UpdateContainerFrameAnchors_Original()
            DriftHelpers:FixMinimapDependentFramesBCC()
        end
    end

    hasFixedMinimap = true
end

function DriftHelpers:FixMinimapDependentFramesRetail()
    -- Setup y anchors
    local anchorY = 0
    local buffsAnchorY = min(0, (MINIMAP_BOTTOM_EDGE_EXTENT or 0) - BuffFrame.bottomEdgeExtent)
    -- Count right action bars
    local rightActionBars = 0
    if ( IsNormalActionBarState() ) then
        if ( SHOW_MULTI_ACTIONBAR_3 ) then
            rightActionBars = 1
            if ( SHOW_MULTI_ACTIONBAR_4 ) then
                rightActionBars = 2
            end
        end
    end

    -- BelowMinimap Widgets - need to move below buffs/debuffs
    if UIWidgetBelowMinimapContainerFrame and UIWidgetBelowMinimapContainerFrame:GetNumWidgetsShowing() > 0 then
        anchorY = min(anchorY, buffsAnchorY)

        UIWidgetBelowMinimapContainerFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)

        anchorY = anchorY - UIWidgetBelowMinimapContainerFrame:GetHeight() - 4
    end

    -- MawBuffsBelowMinimapFrame - need to move below buffs/debuffs
    if MawBuffsBelowMinimapFrame and MawBuffsBelowMinimapFrame:IsShown() then
        anchorY = min(anchorY, buffsAnchorY)

        MawBuffsBelowMinimapFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)

        anchorY = anchorY - MawBuffsBelowMinimapFrame:GetHeight() - 4
    end

    --Setup Vehicle seat indicator offset - needs to move below buffs/debuffs if both right action bars are showing
    if ( VehicleSeatIndicator and VehicleSeatIndicator:IsShown() ) then
        if ( rightActionBars == 2 ) then
            anchorY = min(anchorY, buffsAnchorY)
            VehicleSeatIndicator:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -100, anchorY)
        elseif ( rightActionBars == 1 ) then
            VehicleSeatIndicator:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -62, anchorY)
        else
            VehicleSeatIndicator:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", 0, anchorY)
        end
        anchorY = anchorY - VehicleSeatIndicator:GetHeight() - 4    --The -4 is there to give a small buffer for things like the QuestTimeFrame below the Seat Indicator
    end

    -- Boss frames - need to move below buffs/debuffs if both right action bars are showing
    local numBossFrames = 0
    for i = 1, MAX_BOSS_FRAMES do
        if ( _G["Boss"..i.."TargetFrame"]:IsShown() ) then
            numBossFrames = i
        end
    end
    if ( numBossFrames > 0 ) then
        if ( rightActionBars > 1 ) then
            anchorY = min(anchorY, buffsAnchorY)
        end
        Boss1TargetFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -(CONTAINER_OFFSET_X * 1.3) + 60, anchorY * 1.333)    -- by 1.333 because it's 0.75 scale
        anchorY = anchorY - (numBossFrames * (68 + BOSS_FRAME_CASTBAR_HEIGHT) + BOSS_FRAME_CASTBAR_HEIGHT)
    end

    -- Setup durability offset
    if ( DurabilityFrame ) then
        DurabilityFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
        if ( DurabilityFrame:IsShown() ) then
            anchorY = anchorY - DurabilityFrame:GetHeight()
        end
    end

    if ( ArenaEnemyFrames ) then
        ArenaEnemyFrames:ClearAllPoints()
        ArenaEnemyFrames:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
    end

    if ( ArenaPrepFrames ) then
        ArenaPrepFrames:ClearAllPoints()
        ArenaPrepFrames:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
    end

    -- ObjectiveTracker - needs to move below buffs/debuffs if at least 1 right action bar is showing
    if ( rightActionBars > 0 ) then
        anchorY = min(anchorY, buffsAnchorY)
    end
    if ( ObjectiveTrackerFrame and DriftOptions.objectivesDisabled ) then
        local numArenaOpponents = GetNumArenaOpponents()
        if ( ArenaEnemyFrames and ArenaEnemyFrames:IsShown() and (numArenaOpponents > 0) ) then
            ObjectiveTrackerFrame:ClearAllPoints()
            ObjectiveTrackerFrame:SetPoint("TOPRIGHT", ArenaEnemyFrames_GetBestAnchorUnitFrameForOppponent(numArenaOpponents), "BOTTOMRIGHT", 2, -35)
        elseif ( ArenaPrepFrames and ArenaPrepFrames:IsShown() and (numArenaOpponents > 0) ) then
            ObjectiveTrackerFrame:ClearAllPoints()
            ObjectiveTrackerFrame:SetPoint("TOPRIGHT", ArenaPrepFrames_GetBestAnchorUnitFrameForOppponent(numArenaOpponents), "BOTTOMRIGHT", 2, -35)
        else
            -- We're using Simple Quest Tracking, automagically size and position!
            ObjectiveTrackerFrame:ClearAllPoints()
            -- move up if only the minimap cluster is above, move down a little otherwise
            ObjectiveTrackerFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -OBJTRACKER_OFFSET_X, anchorY)
        end
        ObjectiveTrackerFrame:SetPoint("BOTTOMRIGHT", "UIParent", "BOTTOMRIGHT", -OBJTRACKER_OFFSET_X, CONTAINER_OFFSET_Y)
    end
end

function DriftHelpers:FixMinimapDependentFramesClassic()
    -- Setup y anchors
    local anchorY = 0
    local buffsAnchorY = min(0, (MINIMAP_BOTTOM_EDGE_EXTENT or 0) - BuffFrame.bottomEdgeExtent)
    -- Count right action bars
    local rightActionBars = 0
    if ( IsNormalActionBarState() ) then
        if ( SHOW_MULTI_ACTIONBAR_3 ) then
            rightActionBars = 1
            if ( SHOW_MULTI_ACTIONBAR_4 ) then
                rightActionBars = 2
            end
        end
    end

    -- BelowMinimap Widgets - need to move below buffs/debuffs if at least 1 right action bar is showing
    if UIWidgetBelowMinimapContainerFrame and UIWidgetBelowMinimapContainerFrame:GetHeight() > 0 then
        if rightActionBars > 0 then
            anchorY = min(anchorY, buffsAnchorY)
        end

        UIWidgetBelowMinimapContainerFrame:ClearAllPoints()
        UIWidgetBelowMinimapContainerFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)

        anchorY = anchorY - UIWidgetBelowMinimapContainerFrame:GetHeight() - 4
    end

    -- Quest timers
    QuestTimerFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
    if ( QuestTimerFrame:IsShown() ) then
        anchorY = anchorY - QuestTimerFrame:GetHeight()
    end

    -- Boss frames - need to move below buffs/debuffs if both right action bars are showing
    local numBossFrames = 0
    for i = 1, MAX_BOSS_FRAMES do
        if ( _G["Boss"..i.."TargetFrame"]:IsShown() ) then
            numBossFrames = i
        end
    end
    if ( numBossFrames > 0 ) then
        if ( rightActionBars > 1 ) then
            anchorY = min(anchorY, buffsAnchorY)
        end
        Boss1TargetFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -(CONTAINER_OFFSET_X * 1.3) + 60, anchorY * 1.333)    -- by 1.333 because it's 0.75 scale
        anchorY = anchorY - (numBossFrames * (68 + BOSS_FRAME_CASTBAR_HEIGHT) + BOSS_FRAME_CASTBAR_HEIGHT)
    end

    -- Setup durability offset
    if ( DurabilityFrame ) then
        DurabilityFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
        if ( DurabilityFrame:IsShown() ) then
            anchorY = anchorY - DurabilityFrame:GetHeight()
        end
    end

    if ( ArenaEnemyFrames ) then
        ArenaEnemyFrames:ClearAllPoints()
        ArenaEnemyFrames:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
    end

    if ( ArenaPrepFrames ) then
        ArenaPrepFrames:ClearAllPoints()
        ArenaPrepFrames:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
    end

    -- QuestWatchFrame
    if ( rightActionBars > 0 ) then
        anchorY = min(anchorY, buffsAnchorY)
    end
    if ( QuestWatchFrame and DriftOptions.objectivesDisabled ) then
        QuestWatchFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
    end
end

function DriftHelpers:FixMinimapDependentFramesBCC()
    -- Setup y anchors
    local anchorY = 0
    local buffsAnchorY = min(0, (MINIMAP_BOTTOM_EDGE_EXTENT or 0) - BuffFrame.bottomEdgeExtent)
    -- Count right action bars
    local rightActionBars = 0
    if ( IsNormalActionBarState() ) then
        if ( SHOW_MULTI_ACTIONBAR_3 ) then
            rightActionBars = 1
            if ( SHOW_MULTI_ACTIONBAR_4 ) then
                rightActionBars = 2
            end
        end
    end

    -- BelowMinimap Widgets - need to move below buffs/debuffs if at least 1 right action bar is showing
    if UIWidgetBelowMinimapContainerFrame and UIWidgetBelowMinimapContainerFrame:GetHeight() > 0 then
        if rightActionBars > 0 then
            anchorY = min(anchorY, buffsAnchorY)
        end

        UIWidgetBelowMinimapContainerFrame:ClearAllPoints()
        UIWidgetBelowMinimapContainerFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)

        anchorY = anchorY - UIWidgetBelowMinimapContainerFrame:GetHeight() - 4
    end

    -- Quest timers
    QuestTimerFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
    if ( QuestTimerFrame:IsShown() ) then
        anchorY = anchorY - QuestTimerFrame:GetHeight()
    end

    -- Boss frames - need to move below buffs/debuffs if both right action bars are showing
    local numBossFrames = 0
    for i = 1, MAX_BOSS_FRAMES do
        if ( _G["Boss"..i.."TargetFrame"]:IsShown() ) then
            numBossFrames = i
        end
    end
    if ( numBossFrames > 0 ) then
        if ( rightActionBars > 1 ) then
            anchorY = min(anchorY, buffsAnchorY)
        end
        Boss1TargetFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -(CONTAINER_OFFSET_X * 1.3) + 60, anchorY * 1.333)    -- by 1.333 because it's 0.75 scale
        anchorY = anchorY - (numBossFrames * (68 + BOSS_FRAME_CASTBAR_HEIGHT) + BOSS_FRAME_CASTBAR_HEIGHT)
    end

    -- Setup durability offset
    if ( DurabilityFrame ) then
        DurabilityFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
        if ( DurabilityFrame:IsShown() ) then
            anchorY = anchorY - DurabilityFrame:GetHeight()
        end
    end

    if ( ArenaEnemyFrames ) then
        ArenaEnemyFrames:ClearAllPoints()
        ArenaEnemyFrames:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
    end

    if ( ArenaPrepFrames ) then
        ArenaPrepFrames:ClearAllPoints()
        ArenaPrepFrames:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
    end

    -- QuestWatchFrame
    if ( rightActionBars > 0 ) then
        anchorY = min(anchorY, buffsAnchorY)
    end
    if ( QuestWatchFrame and DriftOptions.objectivesDisabled ) then
        QuestWatchFrame:SetPoint("TOPRIGHT", phantomMinimapCluster, "BOTTOMRIGHT", -CONTAINER_OFFSET_X, anchorY)
    end
end

function DriftHelpers:FixCollectionsJournal()
    if hasFixedCollections then
        return
    end

    if (CollectionsJournal) then
        -- Hide mover if Transmogrify is shown (only affects cases where Collections has not been moved)
        WardrobeFrame:HookScript("OnShow", function() collectionsJournalMover:SetAlpha(0) end)

        -- Set up mover
        collectionsJournalMover:SetFrameStrata("MEDIUM")
        collectionsJournalMover:SetWidth(CollectionsJournal:GetWidth()) 
        collectionsJournalMover:SetHeight(CollectionsJournal:GetHeight())
        collectionsJournalMoverTexture:SetTexture("Interface\\Collections\\CollectionsBackgroundTile.blp")
        collectionsJournalMoverTexture:SetAllPoints(collectionsJournalMover)
        collectionsJournalMover.texture = collectionsJournalMoverTexture
        collectionsJournalMover:SetAllPoints(CollectionsJournal)
        collectionsJournalMover:Show()

        -- Fix parenting
        CollectionsJournal:SetParent(collectionsJournalMover)

        -- Show and hide collectionsJournalMover correctly
        local CollectionsJournal_OnShow_Original = CollectionsJournal_OnShow
        CollectionsJournal:SetScript("OnShow", function()
            WardrobeFrame:ClearAllPoints()

            local point = DriftPoints["CollectionsJournalMover"]
            if point then
                CollectionsJournal:ClearAllPoints()
                CollectionsJournal:SetPoint(
                    point["point"],
                    point["relativeTo"],
                    point["relativePoint"],
                    point["xOfs"],
                    point["yOfs"]
                )
            end

            collectionsJournalMover:SetAlpha(1)

            CollectionsJournal_OnShow_Original(CollectionsJournal)
        end)
        CollectionsJournal:HookScript("OnHide", function() collectionsJournalMover:SetAlpha(0) end)

        -- Hide collectionsJournalMover if CollectionsJournal is not shown
        if not CollectionsJournal:IsShown() then
            collectionsJournalMover:SetAlpha(0)
        end

        hasFixedCollections = true
    end
end

function DriftHelpers:FixArenaFrames()
    if hasFixedArena then
        return
    end

    if (isRetail and ArenaPrepFrames and ArenaEnemyFrames) then
        -- Hook SetScale so ArenaEnemyFrames always has ArenaPrepFrames scale
        local ArenaPrepFrames_SetScale_Original = ArenaPrepFrames.SetScale
        function ArenaPrepFrames:SetScale(newScale)
            ArenaPrepFrames_SetScale_Original(self, newScale)
            ArenaEnemyFrames:SetScale(ArenaPrepFrames:GetScale())
        end

        -- Hook SetPoint to avoid reverting position
        local ArenaPrepFrames_SetPoint_Original = ArenaPrepFrames.SetPoint
        function ArenaPrepFrames:SetPoint(point, relativeFrame, relativePoint, ofsx, ofsy)
            -- Increase ArenaPrepFrames size so ArenaPrepFrames is movable
            ArenaPrepFrames:SetSize(112, 160)

            if relativeFrame == MinimapCluster and DriftPoints["ArenaPrepFrames"] then
                ArenaPrepFrames.DriftResetNeeded = true
                return
            end
            ArenaPrepFrames_SetPoint_Original(self, point, relativeFrame, relativePoint, ofsx, ofsy)
        end

        -- Hook SetPoint to place ArenaEnemyFrames on top of ArenaPrepFrames
        local ArenaEnemyFrames_SetPoint_Original = ArenaEnemyFrames.SetPoint
        function ArenaEnemyFrames:SetPoint(point, relativeFrame, relativePoint, ofsx, ofsy)
            ArenaEnemyFrames_SetPoint_Original(self, "TOPRIGHT", ArenaPrepFrames, "TOPRIGHT", 0, 0)
        end

        -- Avoid weird ObjectiveTrackerFrame placement
        ObjectiveTrackerFrame:SetMovable(true)
        ObjectiveTrackerFrame:SetUserPlaced(true)

        hasFixedArena = true
    end
end

-- Remove frames from list of frames managed by UIParent
function DriftHelpers:FixManagedFrames()
    -- PlayerPowerBarAlt
    if (PlayerPowerBarAlt and PlayerPowerBarAlt.DriftModifiable) then
        UIPARENT_MANAGED_FRAME_POSITIONS["PlayerPowerBarAlt"] = nil
    end

    -- ExtraAbilityContainer
    if (ExtraAbilityContainer and ExtraAbilityContainer.DriftModifiable) then
        UIPARENT_MANAGED_FRAME_POSITIONS["ExtraAbilityContainer"] = nil
    end

    -- TalkingHeadFrame
    if (TalkingHeadFrame and TalkingHeadFrame.DriftModifiable) then
        UIPARENT_MANAGED_FRAME_POSITIONS["TalkingHeadFrame"] = nil
    end
end

function DriftHelpers:HookFCF_DockUpdate(frames)
    if hasFixedManageFramePositions then
        return
    end

    hooksecurefunc(
        "FCF_DockUpdate",
        function()
            DriftHelpers:BroadcastReset(frames)
        end
    )

    hasFixedManageFramePositions = true
end

function DriftHelpers:Wait(delay, func, ...)
    if type(delay) ~= "number" or type(func) ~= "function" then
        return false
    end

    if DriftHelpers.waitFrame == nil then
        DriftHelpers.waitFrame = CreateFrame("Frame", "WaitFrame", UIParent)
        DriftHelpers.waitFrame:SetScript(
            "OnUpdate",
            function(self, elapse)
                local count = #DriftHelpers.waitTable
                local i = 1
                while (i <= count) do
                    local waitRecord = tremove(DriftHelpers.waitTable, i)
                    local d = tremove(waitRecord, 1)
                    local f = tremove(waitRecord, 1)
                    local p = tremove(waitRecord, 1)
                    if (d > elapse) then
                        tinsert(DriftHelpers.waitTable, i, {d - elapse, f, p})
                        i = i + 1
                    else
                        count = count - 1
                        f(unpack(p))
                    end
                end

                -- Reset frames that cannot reset themselves
                for frameName, frame in pairs(DriftHelpers.resetTable) do
                    if frame.DriftResetNeeded then
                        resetScaleAndPosition(frame)
                        frame.DriftResetNeeded = nil
                    end
                end
            end
        )
    end

    tinsert(DriftHelpers.waitTable, {delay, func, {...}})
    return true
end

function DriftHelpers:BroadcastReset(frames)
    for frameName, _ in pairs(frames) do
        local frame = getFrame(frameName)
        if frame and frame:IsVisible() then
            frame.DriftResetNeeded = true
        end
    end
end
