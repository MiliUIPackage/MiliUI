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
local minimapMover = CreateFrame("Frame", "MinimapMover", UIParent)
local minimapMoverTexture = minimapMover:CreateTexture(nil, "BACKGROUND")

-- Variables for Collections Journal
local collectionsJournalMover = CreateFrame("Frame", "CollectionsJournalMover", UIParent)
local collectionsJournalMoverTexture = collectionsJournalMover:CreateTexture(nil, "BACKGROUND")

-- Variables for Communities
local communitiesMover = CreateFrame("Frame", "CommunitiesMover", UIParent)
local communitiesMoverTexture = communitiesMover:CreateTexture(nil, "BACKGROUND")

-- Variables for Bags
local TOTAL_BAGS = 13

-- Variables for WoW version 
local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local isClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
local isWC = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)

-- Variables for whether components have been fixed
local hasFixedBags = false
local hasFixedPlayerChoice = false
local hasFixedMinimap = false
local hasFixedCollections = false
local hasFixedCommunities = false
local hasFixedFramesForElvUIRetail = false
local hasFixedQuestWatchClassic = false
local hasFixedWatchWC = false
local hasFixedTimeManager = false
local hasFixedMicroMenu = false
local hasFixedEncounterJournal = false
local hasFixedTradeSkillMaster = false


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
	if frame.DriftUnmovable then
		print("|cffFFC125移動和縮放視窗:|r 不支援移動 " .. frame:GetName() .. "。")
		return false
	end

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
	if frame.DriftUnscalable then
		print("|cffFFC125移動和縮放視窗:|r 不支援縮放 " .. frame:GetName() .. "。")
		return false
	end

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

local function resetScaleAndPosition(frame)
	local frameToMove = frame.DriftDelegate or frame

	if frameCannotBeModified(frame) or frameCannotBeModified(frameToMove) then
		return
	end

	if frameToMove.DriftIsMoving or frameToMove.DriftIsScaling then
		return
	end

	-- Reset scale
	local scale = DriftScales[frameToMove:GetName()]
	if scale then
		frameToMove.DriftAboutToSetScale = true
		frameToMove:SetScale(scale)
	end

	-- Reset position
	local point = DriftPoints[frameToMove:GetName()]
	if point then
		frameToMove:ClearAllPoints()
		frameToMove.DriftAboutToSetPoint = true
		xpcall(
			frameToMove.SetPoint,
			function() end,
			frameToMove,
			point["point"],
			point["relativeTo"],
			point["relativePoint"],
			point["xOfs"],
			point["yOfs"]
		)

		if frame.DriftHasMover then
			if (hasFixedCommunities) then
				communitiesMover:SetWidth(CommunitiesFrame:GetWidth())
				communitiesMover:SetHeight(CommunitiesFrame:GetHeight())
			end

			frame:ClearAllPoints()
			xpcall(
				frame.SetPoint,
				function() end,
				frame,
				point["point"],
				point["relativeTo"],
				point["relativePoint"],
				point["xOfs"],
				point["yOfs"]
			)
		end
	end
end

local function onDragStart(frame, button)
	local frameToMove = frame.DriftDelegate or frame

	-- Left click is move
	if button == "LeftButton" then
		if not shouldMove(frameToMove) or not shouldMove(frame) then
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
		if not shouldScale(frameToMove) or not shouldScale(frame) then
			return
		end

		-- Prevent moving while scaling
		frame:RegisterForDrag("RightButton")

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

	if frameCannotBeModified(frame) or frameCannotBeModified(frameToMove) then
		return
	end

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
		end
	end
	frameToMove.DriftIsMoving = false

	-- Save scale
	if (frameToMove.DriftIsScaling) then
		DriftScales[frameToMove:GetName()] = frameToMove:GetScale()
	end
	frameToMove.DriftIsScaling = false
	DriftHelpers.frameBeingScaled = nil

	if frame.DriftHasMover then
		frameToMove:SetAlpha(0)
		resetScaleAndPosition(frame)
	end

	-- Hide GameTooltip
	GameTooltip:Hide()

	-- Allow for dragging with both buttons
	frame:RegisterForDrag("LeftButton", "RightButton")
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

local function hookSet(frameOriginal)
	local frame = frameOriginal.DriftDelegate or frameOriginal
	local setTarget = (frameOriginal.DriftHasMover and frameOriginal) or frame

	if frame.DriftHookSet then
		return
	end

	hooksecurefunc(
		setTarget,
		"SetPoint",
		function()
			if frame.DriftAboutToSetPoint then
				frame.DriftAboutToSetPoint = false
			else
				resetScaleAndPosition(setTarget)
			end
		end
	)

	hooksecurefunc(
		setTarget,
		"SetScale",
		function()
			if frame.DriftAboutToSetScale then
				frame.DriftAboutToSetScale = false
			else
				resetScaleAndPosition(setTarget)
			end
		end
	)

	frame.DriftHookSet = true
end

-- Global functions
function DriftHelpers:DeleteDriftState()
	-- Delete DriftPoints state
	DriftPoints = {}

	-- SetScale to 1 for each frame
	for frameName, _ in pairs(DriftScales) do
		local frame = getFrame(frameName)
		if frame then
			frame.DriftAboutToSetScale = true
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
	if isClassic then
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
							DriftHelpers.frameBeingScaled.DriftAboutToSetScale = true
							DriftHelpers.frameBeingScaled:SetScale(newScale)
						elseif curMouseY < DriftHelpers.prevMouseY then
							-- Subtract from scale
							local newScale = math.max(
								DriftHelpers.frameBeingScaled:GetScale() - SCALE_INCREMENT,
								MIN_SCALE
							)

							-- Scale
							DriftHelpers.frameBeingScaled.DriftAboutToSetScale = true
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

	-- Fix QuestWatchFrame Classic
	if (isClassic) and (not DriftOptions.objectivesDisabled) then
		DriftHelpers:FixQuestWatchClassic()
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
			if properties.DriftUnmovable then
				frame.DriftUnmovable = true
			end
			if properties.DriftHasMover then
				frame.DriftHasMover = true
			end
			if properties.DriftDelegate then
				frame.DriftDelegate = getFrame(properties.DriftDelegate) or frame
			end

			makeModifiable(frame)
			hookSet(frame)
		end
	end

	-- Fix Bags
	if not DriftOptions.bagsDisabled then
		DriftHelpers:FixBags()
	end

	-- Fix PlayerChoiceFrame
	if not DriftOptions.windowsDisabled then
		DriftHelpers:FixPlayerChoiceFrame()
	end

	-- Fix Minimap
	if (not isRetail) and (not DriftOptions.minimapDisabled) then
		DriftHelpers:FixMinimap()
	end

	-- Fix CollectionsJournal
	if not DriftOptions.windowsDisabled then
		DriftHelpers:FixCollectionsJournal()
	end

	-- Fix Communities
	if not DriftOptions.windowsDisabled then
		DriftHelpers:FixCommunities(frames)
	end

	-- ElvUI compatibility Retail
	-- https://github.com/jaredbwasserman/drift/issues/39
	-- https://github.com/jaredbwasserman/drift/issues/46
	if (isRetail) and (not DriftOptions.windowsDisabled) then
		DriftHelpers:FixFramesForElvUIRetail()
	end

	-- Fix TimeManagerFrame
	if not DriftOptions.windowsDisabled then
		DriftHelpers:FixTimeManagerFrame()
	end

	-- Fix WatchFrame WC
	if (isWC) and (not DriftOptions.objectivesDisabled) then
		DriftHelpers:FixWatchWC()
	end

	-- Fix tooltip issue
	-- https://github.com/jaredbwasserman/drift/issues/50
	if (not DriftOptions.buttonsDisabled) then
		DriftHelpers:FixMicroMenu()
	end

	-- Fix EncounterJournal
	-- https://github.com/jaredbwasserman/drift/issues/51
	if (not DriftOptions.windowsDisabled) then
		DriftHelpers:FixEncounterJournal()
	end

	-- Fix TradeSkillMaster
	-- https://github.com/jaredbwasserman/drift/issues/54
	if (not DriftOptions.windowsDisabled) then
		DriftHelpers:FixTradeSkillMaster()
	end

	-- Reset for good measure
	for frameName, _ in pairs(frames) do
		local frame = getFrame(frameName)
		if frame then
			resetScaleAndPosition(frame)
		end
	end
end

function DriftHelpers:FixBags()
	if hasFixedBags then
		return
	end

	for i=1,TOTAL_BAGS do
		_G["ContainerFrame"..i]:HookScript(
			"OnHide",
			function(self, event, ...)
				if (not DriftHelpers:IsAnyBagShown()) then
					DriftHelpers:RevertBags()
				end
			end
		)
	end

	if (ContainerFrameCombinedBags) then
		ContainerFrameCombinedBags:HookScript(
			"OnHide",
			function(self, event, ...)
				if (not DriftHelpers:IsAnyBagShown()) then
					DriftHelpers:RevertBags()
				end
			end
		)
	end

	hasFixedBags = true
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

function DriftHelpers:FixMinimap()
	if hasFixedMinimap then
		return
	end

	if nil == MinimapCluster then
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

	if (isWC) then
		-- Set up mover
		minimapMover:SetFrameStrata("MEDIUM")
		minimapMover:SetWidth(MinimapCluster:GetWidth())
		minimapMover:SetHeight(MinimapCluster:GetHeight())
		minimapMoverTexture:SetAllPoints(minimapMover)
		minimapMover.texture = minimapMoverTexture
		minimapMover:SetAllPoints(MinimapCluster)
		minimapMover:SetAlpha(0)
		minimapMover:Show()

		-- Texture should only show during movement
		MinimapCluster:HookScript("OnDragStart", function()
			minimapMoverTexture:SetTexture("Interface\\Collections\\CollectionsBackgroundTile.blp")
		end)
		MinimapCluster:HookScript("OnDragStop", function()
			minimapMoverTexture:SetTexture(nil)
		end)

		-- Fix post-reload behavior
		hooksecurefunc(
			"FCF_DockUpdate",
			function() resetScaleAndPosition(MinimapCluster) end
		)
	end

	hasFixedMinimap = true
end

function DriftHelpers:FixCollectionsJournal()
	if hasFixedCollections then
		return
	end

	if (CollectionsJournal) then
		-- Set up mover
		collectionsJournalMover:SetFrameStrata("MEDIUM")
		collectionsJournalMover:SetWidth(CollectionsJournal:GetWidth()) 
		collectionsJournalMover:SetHeight(CollectionsJournal:GetHeight())
		collectionsJournalMoverTexture:SetTexture("Interface\\Collections\\CollectionsBackgroundTile.blp")
		collectionsJournalMoverTexture:SetAllPoints(collectionsJournalMover)
		collectionsJournalMover.texture = collectionsJournalMoverTexture
		collectionsJournalMover:SetAllPoints(CollectionsJournal)
		collectionsJournalMover:SetAlpha(0)
		collectionsJournalMover:Show()

		hasFixedCollections = true
	end
end

function DriftHelpers:FixCommunities(frames)
	if hasFixedCommunities then
		return
	end

	if (CommunitiesFrame) then
		-- Set up mover
		communitiesMover:SetFrameStrata("MEDIUM")
		communitiesMover:SetWidth(CommunitiesFrame:GetWidth())
		communitiesMover:SetHeight(CommunitiesFrame:GetHeight())
		communitiesMoverTexture:SetTexture("Interface\\Collections\\CollectionsBackgroundTile.blp")
		communitiesMoverTexture:SetAllPoints(communitiesMover)
		communitiesMover.texture = communitiesMoverTexture
		communitiesMover:SetAllPoints(CommunitiesFrame)
		communitiesMover:SetAlpha(0)
		communitiesMover:Show()

		hasFixedCommunities = true
	end
end

function DriftHelpers:FixFramesForElvUIRetail()
	if hasFixedFramesForElvUIRetail then
		return
	end

	if not isRetail then
		return
	end

	if not IsAddOnLoaded("ElvUI") then
		return
	end

	if (MailFrame and TokenFrame and TokenFramePopup) then
		MailFrame:HookScript(
			"OnShow",
			function()
				if (MailFrameInset) and (MailFrameInset:GetParent() ~= MailFrame) then
					MailFrameInset:SetParent(MailFrame)
				end
			end
		)

		TokenFramePopup:ClearAllPoints()
		xpcall(
			TokenFramePopup.SetPoint,
			function() end,
			TokenFramePopup,
			"TOPLEFT",
			TokenFrame,
			"TOPRIGHT",
			3,
			-28
		)

		hasFixedFramesForElvUIRetail = true
	end
end

function DriftHelpers:FixQuestWatchClassic()
	if hasFixedQuestWatchClassic then
		return
	end

	if (not isClassic) then
		return
	end

	-- TODO: Fix this unsafe hook
	if (QuestWatchFrame) then
		local QuestWatchFrame_SetPoint_Original = QuestWatchFrame.SetPoint
		QuestWatchFrame.SetPoint = function(_, point, relativeTo, relativePoint, ofsx, ofsy)
			if "MinimapCluster" == relativeTo then
				return
			end
			QuestWatchFrame_SetPoint_Original(QuestWatchFrame, point, relativeTo, relativePoint, ofsx, ofsy)
		end

		hasFixedQuestWatchClassic = true
	end
end

function DriftHelpers:FixTimeManagerFrame()
	if hasFixedTimeManager then
		return
	end

	hooksecurefunc(
		"TimeManager_LoadUI",
		function() resetScaleAndPosition(TimeManagerFrame) end
	)

	hasFixedTimeManager = true
end

function DriftHelpers:FixWatchWC()
	if hasFixedWatchWC then
		return
	end

	if (not isWC) then
		return
	end

	if (WatchFrame) then
		hooksecurefunc(
			"FCF_DockUpdate",
			function() resetScaleAndPosition(WatchFrame) end
		)

		hasFixedWatchWC = true
	end
end

function DriftHelpers:FixMicroMenu()
	if hasFixedMicroMenu then
		return
	end

	if MicroMenu and HelpOpenWebTicketButton then
		hooksecurefunc(
			MicroMenu,
			"GetEdgeButton",
			function()
				HelpOpenWebTicketButton:ClearAllPoints()
			end
		)

		hasFixedMicroMenu = true
	end
end

function DriftHelpers:FixEncounterJournal()
	if hasFixedEncounterJournal then
		return
	end

	if (not isRetail) then
		return
	end

	if EncounterJournal then
		EncounterJournal:HookScript(
			"OnShow",
			function()
				EncounterJournalTooltip:ClearAllPoints()
			end
		)

		hasFixedEncounterJournal = true
	end
end

function DriftHelpers:FixTradeSkillMaster()
	if hasFixedTradeSkillMaster then
		return
	end

	if not IsAddOnLoaded("TradeSkillMaster") then
		return
	end

	if MerchantFrame then
		DriftPoints[MerchantFrame:GetName()] = nil
		MerchantFrame:SetClampedToScreen(false)
		hasFixedTradeSkillMaster = true
	end
end

function DriftHelpers:IsAnyBagShown()
	local anyBagShown = false
	for i=1,TOTAL_BAGS do
		local frameName = "ContainerFrame"..i
		if _G[frameName]:IsShown() then
			anyBagShown = true
		end
	end
	if ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown() then
		anyBagShown = true
	end
	return anyBagShown
end

function DriftHelpers:RevertBags()
	for i=1,TOTAL_BAGS do
		local frameName = "ContainerFrame"..i
		_G[frameName]:ClearAllPoints()
		_G[frameName].DriftAboutToSetPoint = true
		xpcall(
			_G[frameName].SetPoint,
			function() end,
			_G[frameName],
			"BOTTOMRIGHT",
			UIParent,
			"BOTTOMRIGHT",
			0,
			0
		)
	end
	if (ContainerFrameCombinedBags) then
		ContainerFrameCombinedBags:ClearAllPoints()
		ContainerFrameCombinedBags.DriftAboutToSetPoint = true
		xpcall(
			ContainerFrameCombinedBags.SetPoint,
			function() end,
			ContainerFrameCombinedBags,
			"BOTTOMRIGHT",
			UIParent,
			"BOTTOMRIGHT",
			0,
			0
		)
	end
end
