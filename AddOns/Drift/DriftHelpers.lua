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

-- Variables for Collections Journal
local collectionsJournalMover = CreateFrame("Frame", "CollectionsJournalMover", UIParent)
local collectionsJournalMoverTexture = collectionsJournalMover:CreateTexture(nil, "BACKGROUND")

-- Variables for Communities
local communitiesMover = CreateFrame("Frame", "CommunitiesMover", UIParent)
local communitiesMoverTexture = communitiesMover:CreateTexture(nil, "BACKGROUND")

-- Variables for WoW version 
local isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
local isClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
local isBCC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
local isWC = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)

-- Other variables
local hasFixedPVPTalentList = false
local hasFixedPlayerChoice = false
local hasFixedCollections = false
local hasFixedCommunities = false
local hasFixedFramesForElvUI = false
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
			if ("CollectionsJournal" == frame:GetName() or "CommunitiesFrame" == frame:GetName()) then
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

		-- TODO: This is messy
		if ("CollectionsJournal" == frame:GetName() or "CommunitiesFrame" == frame:GetName()) then
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

	-- Fix PVP talents list
	if not DriftOptions.windowsDisabled then
		DriftHelpers:FixPVPTalentsList(frames)
	end

	-- Fix PlayerChoiceFrame
	if not DriftOptions.windowsDisabled then
		DriftHelpers:FixPlayerChoiceFrame()
	end

	-- Fix MacroPopupFrame
	if not DriftOptions.windowsDisabled then
		MacroPopupFrame_AdjustAnchors = function() end
	end

	-- Fix CollectionsJournal
	if not DriftOptions.windowsDisabled then
		DriftHelpers:FixCollectionsJournal()
	end

	-- Fix Communities
	if not DriftOptions.windowsDisabled then
		DriftHelpers:FixCommunities(frames)
	end

	-- Fix OrderHallTalentFrame
	if not DriftOptions.windowsDisabled and OrderHallTalentFrame then
		DriftHelpers.resetTable["OrderHallTalentFrame"] = OrderHallTalentFrame
	end

	-- Fix LootFrame
	if (isClassic or isBCC or isWC) and (not DriftOptions.windowsDisabled) and (LootFrame) then
		DriftHelpers.resetTable["LootFrame"] = LootFrame
	end

	-- ElvUI compatibility BCC
	-- https://github.com/jaredbwasserman/drift/issues/31
	if isBCC and not DriftOptions.windowsDisabled then
		DriftHelpers:FixFramesForElvUI()
	end

	-- Hook FCF_DockUpdate since it's called at the end of UIParentManageFramePositions
	DriftHelpers:HookFCF_DockUpdate(frames)

	-- Reset everything in case there was a delay
	DriftHelpers:BroadcastReset(frames)
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
				xpcall(
					CollectionsJournal.SetPoint,
					function() end,
					CollectionsJournal,
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
		communitiesMover:Show()

		-- Fix parenting
		CommunitiesFrame:SetParent(communitiesMover)

		-- Show and hide communitiesMover correctly
		CommunitiesFrame:HookScript("OnShow", function()
			local point = DriftPoints["CommunitiesFrameMover"]
			if point then
				CommunitiesFrame:ClearAllPoints()
				xpcall(
					CommunitiesFrame.SetPoint,
					function() end,
					CommunitiesFrame,
					point["point"],
					point["relativeTo"],
					point["relativePoint"],
					point["xOfs"],
					point["yOfs"]
				)
			end

			communitiesMover:SetAlpha(1)
		end)
		CommunitiesFrame:HookScript("OnHide", function() communitiesMover:SetAlpha(0) end)

		-- Hide communitiesMover if CommunitiesFrame is not shown
		if not CommunitiesFrame:IsShown() then
			communitiesMover:SetAlpha(0)
		end

		-- Fix scroll buttons
		if (ClubFinderGuildFinderFrame) then
			ClubFinderGuildFinderFrame:HookScript(
				"OnShow",
				function(self, event, ...)
					DriftHelpers:BroadcastReset(frames)
				end
			)
		end

		if (CommunitiesFrameInset) then
			CommunitiesFrameInset:HookScript(
				"OnShow",
				function(self, event, ...)
					DriftHelpers:BroadcastReset(frames)
				end
			)
		end

		if (ClubFinderCommunityAndGuildFinderFrame) then
			ClubFinderCommunityAndGuildFinderFrame:HookScript(
				"OnShow",
				function(self, event, ...)
					DriftHelpers:BroadcastReset(frames)
				end
			)
		end

		hasFixedCommunities = true
	end
end

function DriftHelpers:FixFramesForElvUI()
	if hasFixedFramesForElvUI then
		return
	end

	local UpdateUIPanelPositions_Original = UpdateUIPanelPositions
	function UpdateUIPanelPositions(currentFrame)
		if currentFrame == FriendsFrame and DriftPoints["FriendsFrame"] then
			return
		end
		if currentFrame == CharacterFrame and DriftPoints["CharacterFrame"] then
			return
		end
		UpdateUIPanelPositions_Original(currentFrame)
	end

	hasFixedFramesForElvUI = true
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
