--[[ 
===============================================================
Dugi Guides Addon License Agreement

Copyright (c) 2010-2015 Dugi Guides LTD
All rights reserved.

File Source: http://www.ultimatewowguide.com 
Author Name: Fransisco Brevoort
Email: support@ultimatewowguide.com

The contents of this addon, excluding third-party resources, are
copyrighted to its author with all rights reserved, under United
States copyright law and various international treaties.

In particular, please note that you may not distribute this addon in
any form, with or without modifications, including as part of a
compilation, without prior written permission from its author.

The author of this addon hereby grants you the following rights:

1. You may use this addon for private use only.

2. You may make modifications to this addon for private use only.

All rights not explicitly addressed in this license are reserved by
the copyright holder.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
]]


--Preserving original functions from being overridden
GetMapOverlayInfo_original = GetMapOverlayInfo
GetNumMapOverlays_original = GetNumMapOverlays




local lastMapUpdate = GetTime()

--DugisCharacterCache initialization	
if not DugisCharacterCache then
    DugisCharacterCache = {}
end

local _
DugisGuideViewer = {
	events = {},
	globalHandlers = {},
	eventFrame = CreateFrame("Frame"),
	RegisterEvent = function(self, event, method)
		self.eventFrame:RegisterEvent(event)
		if self.events[event] then
			local existingRegistration = self.events[event]
			if type(existingRegistration)~="table" then
				if existingRegistration==method then return end
				self.events[event] = self.GetCreateTable(existingRegistration, method or event)
			else
				for _,exItem in existingRegistration:IPairs() do
					if exItem==method then return end
				end
				existingRegistration:Insert(method or event)
			end
		else
			self.events[event] = method or event
		end
	end,
	UnregisterEvent = function(self, event, method)
		local existingRegistration = self.events[event]
		if existingRegistration and type(existingRegistration)=="table" then
			assert(#existingRegistration>1)
			method = method or event
			existingRegistration:RemoveFirst(method)
			if #existingRegistration==1 then
				self.events[event] = existingRegistration[1]
				existingRegistration:Pool()
			end
			return
		end
		self.eventFrame:UnregisterEvent(event)
		self.events[event] = nil
	end,
	version = GetAddOnMetadata("DugisGuideViewer", "Version"),
	RegisterGlobalEventHandler = function(self, method)
		self.globalHandlers[method] = true
	end,
	UnregisterGlobalEventHandler = function(self, method)
		self.globalHandlers[method] = nil
	end,
}
local DugisGuideViewer = DugisGuideViewer
local DGV = DugisGuideViewer


local savablePositionsFrameNames = {
     "DugisMainBorder"
    ,"DugisRecordFrame"
    --,"DugisSecureQuestButton"
    -- ,"DugisGuideViewerActionItemFrame"
    ,"DugisArrowFrame"
    ,"DugisGuideViewer_TargetFrame"
	,"DugisSmallFrameContainer"
	,"ObjectiveTrackerFrame"
	,"DugisGuideViewer_ModelViewer"
	,"DugisOnOffButton"
	,"GPSArrowScroll"
}

DugisGuideViewer.eventFrame:SetScript("OnEvent", function(self, event, ...)
	local entry = DugisGuideViewer.events[event]
	--if DugisGuideViewer.DebugFormat then DugisGuideViewer:DebugFormat("OnEvent", "event", event) end
	if type(entry)=="table" then
		for _,method in entry:IPairs() do
			if method and DugisGuideViewer[method] then
				DugisGuideViewer[method](DugisGuideViewer, event, ...)
			end
		end
	else
		if entry and DugisGuideViewer[entry] then
			DugisGuideViewer[entry](DugisGuideViewer, event, ...)
		end
	end
	for method in pairs(DugisGuideViewer.globalHandlers) do

		method(event, ...)
	end
end)


DugisGuideViewer:RegisterEvent("PLAYER_ENTERING_WORLD")
DugisGuideViewer:RegisterEvent("PLAYER_ALIVE")
DugisGuideViewer:RegisterEvent("ADDON_LOADED")

DugisGuideViewer:RegisterEvent("SKILL_LINES_CHANGED")
DugisGuideViewer:RegisterEvent("CHAT_MSG_SKILL")
DugisGuideViewer:RegisterEvent("TRADE_SKILL_DATA_SOURCE_CHANGED")
DugisGuideViewer:RegisterEvent("TRADE_SKILL_LIST_UPDATE")


--todo: find replacement
--DugisGuideViewer:RegisterEvent("WORLD_MAP_UPDATE")

local FirstTime = 1
local L = DugisLocals

if GetLocale() == "enUS" then
	DugisGuideViewer.Localize = 0
else
	DugisGuideViewer.Localize = 1
	
end

--local LastGuideNumRows = 0
local Debug = 0 --Print Debug Messages
local Localize = 0	--Print Localization Error messages
local SettingsRevision = 10

DugisGuideViewer.Debug = Debug and Debug>0 and 1 or nil
DugisGuideViewer.ARTWORK_PATH = "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\"
DugisGuideViewer.BACKGRND_PATH = "Interface\\DialogFrame\\UI-DialogBox-Background"
DugisGuideViewer.EDGE_PATH = "Interface\\DialogFrame\\UI-DialogBox-Border"

BINDING_HEADER_DUGI = L["Dugi Guides"]
_G["BINDING_NAME_CLICK DugisGuideViewer_TargetFrame:RightButton"] = L["Target Button"]
_G["BINDING_NAME_CLICK DugisSecureQuestButton:LeftButton"] = L["Floating Item Button"]


--Default colors definition
DugisGuideViewer.defaultBadArrowColor = {1, 0, 0} 
DugisGuideViewer.defaultMiddleArrowColor = {1, 0.5, 0}
DugisGuideViewer.defaultGoodArrowColor = {1, 0.5, 0}
DugisGuideViewer.defaultExactArrowColor = {1, 1, 0}
DugisGuideViewer.defaultQuestingAreaColor = {0, 1, 0}

DugisGuideViewer.defaultWaySegmentColor = function()

	--Backward compatibility
	local oldSettings = DugisGuideViewer:UserSetting(104) --DGV_ANTCOLOR 
	
	if oldSettings ==[[Interface\COMMON\Indicator-Gray]] then
		return {0.2, 0.2, 0.2}
	end
	
	if oldSettings ==[[Interface\COMMON\Indicator-Red]] then
		return {0.8, 0, 0}
	end	
	
	if oldSettings ==[[Interface\COMMON\Indicator-Yellow]] then
		return {0.8, 0.8, 0}
	end	
	
	if oldSettings ==[[Interface\COMMON\Indicator-Green]] then
		return {0.0, 0.7, 0}
	end		
	
	return {0, 0.8, 0}
end

local function LocalizePrint(message)
	if Localize == 1 then
		print(message)
	end
end
DugisGuideViewer.LocalizePrint = LocalizePrint

local function DebugPrint(message)
	if Debug == 1 then
		print(message)
	end
end
DugisGuideViewer.DebugPrint = DebugPrint

local function LoadSettings()
	local self = DugisGuideViewer
	--Settings Page Checkboxes
	DGV_QUESTLEVELON = 1
	DGV_LOCKSMALLFRAME = 2
	DGV_LOCKLARGEFRAME = 3
	DGV_WAYPOINTSON = 4
	DGV_ITEMBUTTONON = 5
	DGV_ENABLEQW = 6
	DGV_DUGIARROW = 7
	DGV_SHOWCORPSEARROW = 8
	DGV_CLASSICARROW = 9
	DGV_CARBONITEARROW = 10
	DGV_TOMTOMARROW = 11
	DGV_SHOWANTS = 12
	DGV_AUTOQUESTACCEPT = 13
	DGV_DISPLAYCOORDINATES = 14
	DGV_AUTOQUESTACCEPTALL = 15
	DGV_AUTOSELL = 16
	DGV_REMOVEMAPFOG = 17
	DGV_SMALLFRAMEBORDER = 18
	DGV_TARGETBUTTON = 19
	DGV_TARGETBUTTONSHOW = 20
	DGV_SHOWONOFF = 21
	DGV_STICKYFRAME = 22
    DGV_STICKYFRAMESHOWDESCRIPTIONS = 23
	--DGV_AUTOSTICK = 25
	DGV_DISPLAYMAPCOORDINATES = 24
	DGV_ENABLEMODELDB = 25
	DGV_ENABLENPCNAMEDB = 26
	DGV_ENABLEQUESTLEVELDB = 27
	DGV_ANCHOREDSMALLFRAME = 28
	DGV_QUESTCOLORON = 29
	DGV_MAPPREVIEWHIDEBORDER = 30
	DGV_UNLOADMODULES = 31
	DGV_FIXEDWIDTHSMALL = 32
	DGV_MOVEWATCHFRAME = 33
	DGV_WATCHFRAMEBORDER = 34
	DGV_WORLDMAPTRACKING = 35
	DGV_AUTOQUESTTURNIN = 36
	DGV_ACCOUNTWIDEACH = 37
	DGV_EMBEDDEDTOOLTIP = 38
	DGV_OBJECTIVECOUNTER = 39
	DGV_MULTISTEPMODE = 40
	DGV_FIXEDWIDEFRAME = 41
	DGV_AUTOEQUIPSMARTSET = 42
	DGV_SHOWAUTOEQUIPPROMPT = 43
	DGV_DISABLEWATCHFRAMEMOD = 44	
	DGV_AUTOREPAIR = 45
	DGV_AUTOREPAIRGUILD = 46
	DGV_HIGHLIGHTSTEPONENTER = 47
	DGV_MANUALWAYPOINT = 48
	DGV_TOMTOMEMULATION = 49
	DGV_LOCKMODELFRAME = 50
	DGV_JOURNALFRAME = 51
	DGV_JOURNALFRAMEBUTTONSTICKED = 52
	DGV_GUIDESUGGESTMODE = 53	
	DGV_FISHINGPOLE = 54
	DGV_COOKINGITEM = 55
	DGV_WATCHLOCALQUEST = 56
    DGV_AUTOFLIGHTPATHSELECT = 57
	DGV_TARGETTOOLTIP = 58
	DGV_USETAXISYSTEM = 59
	DGV_SHOWQUESTABANDONBUTTON = 60
	DGV_SUGGESTTRINKET = 61	
	DGV_DISPLAYALLSTATS = 62	
	DGV_DISPLAYGUIDESPROGRESS = 63	
	DGV_DISPLAYGUIDESPROGRESSTEXT = 64	
	DGV_AUTOQUESTITEMLOOT = 65
	DGV_DAILYITEM = 66
	DGV_BLINKMINIMAPICONS = 67
    DGV_ENABLEDGEARFINDER = 68
	DGV_INCLUDE_DUNG_NORMAL = 69
	DGV_INCLUDE_DUNG_HEROIC = 70
	DGV_INCLUDE_DUNG_MYTHIC = 71
	DGV_INCLUDE_DUNG_TIMEWALKING = 72
    
	DGV_INCLUDE_RAIDS_RAIDFINDER = 73
	DGV_INCLUDE_RAIDS_NORMAL = 74
	DGV_INCLUDE_RAIDS_HEROIC = 75
	DGV_INCLUDE_RAIDS_MYTHIC = 76
    
    DGV_GEARS_FROM_QUEST_GUIDES = 77
	
	DGV_AUTO_QUEST_TRACK = 78
	DGV_WAYPOINT_PING = 79
    
    DGV_HIDE_MODELS_IN_WORLDMAP = 80
    DGV_AUTO_MOUNT = 81
    DGV_ENABLED_MAPPREVIEW = 82
    
    DGV_DISABLE_QUICK_SETTINGS = 83
    
    DGV_TAXISYSTEM_ZONE_PORTALS = 84
    DGV_TAXISYSTEM_PLAYER_PORTALS = 85
    DGV_TAXISYSTEM_BOATS = 86
    DGV_TAXISYSTEM_CLASS_PORTALS = 87
    DGV_TAXISYSTEM_WHISTLE = 88
    DGV_ENABLED_GEAR_NOTIFICATIONS = 89
    DGV_ENABLED_GUIDE_NOTIFICATIONS = 90
	
    DGV_ALWAYS_SHOW_STANDARD_PROMPT_GEAR = 91
    DGV_ALWAYS_SHOW_STANDARD_PROMPT_GUIDE = 92
	DGV_BAD_COLOR = 93
	DGV_MIDDLE_COLOR = 94
	DGV_GOOD_COLOR = 95
	DGV_EXACT_COLOR = 96
	DGV_QUESTING_AREA_COLOR = 97
    DGV_ENABLED_JOURNAL_NOTIFICATIONS = 98
    DGV_USE_NOTIFICATIONS_MARK = 99
	
	DGV_WAY_SEGMENT_COLOR = 1001
	DGV_ENABLED_GPS_ARROW = 1002
	DGV_GPS_ARROW_AUTOZOOM = 1003
	DGV_GPS_ARROW_POIS = 1004
	DGV_GPS_AUTO_HIDE = 1005
	DGV_GPS_MERGE_WITH_DUGI_ARROW = 1006
	DGV_GPS_MINIMAP_TERRAIN_DETAIL = 1007
	
	DGV_TRGET_BUTTON_FIXED_MODE = 1008
	DGV_NAMEPLATES_TRACKING = 1009
	DGV_NAMEPLATES_SHOW_ICON = 1010
	DGV_NAMEPLATES_SHOW_TEXT = 1011

	--Sliders
	DGV_MINIBLOBQUALITY = 200
	DGV_SHOWTOOLTIP = 201
	DGV_RECORDSIZE = 202
	DGV_MAPPREVIEWDURATION = 203

	DGV_SMALLFRAMEFONTSIZE = 204
	DGV_TARGETBUTTONSCALE = 205
	DGV_ITEMBUTTONSCALE = 206
	DGV_JOURNALFRAMEBUTTONSCALE = 207
	DGV_SMALLFRAME_STEPS = 208
	DGV_MOUNT_DELAY = 209
	
	DGV_GPS_BORDER_OPACITY = 210
	DGV_GPS_MAPS_OPACITY = 211
	DGV_GPS_MAPS_SIZE = 212
	DGV_GPS_ARROW_SIZE = 213
	DGV_NAMEPLATEICONSIZE = 214
	DGV_NAMEPLATETEXTSIZE = 215
	
	--Dropdowns
	DGV_GUIDEDIFFICULTY = 100
	DGV_SMALLFRAMETRANSITION = 101
	DGV_LARGEFRAMEBORDER = 102
	DGV_STEPCOMPLETESOUND = 103
	--DGV_ANTCOLOR = 104
	DGV_TAXIFLIGHTMASTERS = 109
	DGV_GASTATCAPLEVELDIFFERENCE = 111
	DGV_SMALLFRAMEDOCKING = 112
	DGV_WEAPONPREF = 113
	DGV_MAIN_FRAME_BACKGROUND = 114
	DGV_ROUTE_STYLE = 115
		
	--DGV_MINIBLOBS = 104
	DGV_TOOLTIPANCHOR = 105
	DGV_MAPPREVIEWPOIS = 106
	DGV_QUESTCOMPLETESOUND = 107
	DGV_DISPLAYPRESET = 108
	DGV_GASMARTSETTARGET = 110
	
	DGV_GPS_BORDER = 116
	
	--Custom
	DGV_TARGETBUTTONCUSTOM = 300
	DGV_PROFILECUSTOM = 301
	DGV_GAWINCRITERIACUSTOM = 302

	local defaults = {
		profile = {
			char = {
				settings = {
					QuestRecordTable = {},
					QuestRecordTableCriterias = {},
					QuestRecordTableScenarios = {},
                    framePositions = {},
					QuestRecordEnabled = true,
					ModelViewer = {	pos_x = 300, pos_y = 45, relativePoint="CENTER"},
					StickyFrame = {	pos_x = 485, pos_y = 130, relativePoint="CENTER"},
					FirstTime = true,
					EssentialsMode = 0,
					SettingsRevision = 0,
					WatchFrameSnapped = true,
					GuideOn = true,
					sz = {}, --check boxes ids
					[DGV_QUESTLEVELON]			= { category = "Other",	text = "Display Quest Level", 	checked = false,	tooltip = "Show the quest level on the large and small frames", module = "Guides"},
					[DGV_QUESTCOLORON] 		= { category = "Other",	text = "Color Code Quest", 	checked = true,		tooltip = "Color code quest against your character's level", module = "Guides"},
					[DGV_LOCKSMALLFRAME] 		= { category = "Frames",	text = "Lock Small Frame", 	checked = false,	tooltip = "Lock small frame into place", module = "SmallFrame"},
					[DGV_MOVEWATCHFRAME] 		= { category = "Frames",	text = "Move Objective Tracker", showOnRightColumn = true, checked = false,	tooltip = "Allow movement of the watch frame, not available if other incompatible addons are loaded.", module = "DugisWatchFrame"},
					[DGV_ANCHOREDSMALLFRAME] 	= { category = "Display",	text = "Anchored Small Frame", 	checked = true,	tooltip = "Allow a fixed Anchored Small Frame that will integrate with the Objective Tracker", module = "SmallFrame"},
					[DGV_LOCKLARGEFRAME] 		= { category = "Frames",	text = "Lock Large Frame", 	checked = false,	tooltip = "Lock large frame into place", module = "Guides"},
					[DGV_WAYPOINTSON]			= { category = "Dugi Arrow",	text = "Automatic Waypoints", 	checked = true,		tooltip = "Automatically map waypoints from the Small Frame or from the Objective Tracker in essential mode",},
					[DGV_ITEMBUTTONON] 		= { category = "Questing",	text = "Floating Item Button",		checked = true,		tooltip = "Shows a small window to click when an item is needed for a quest",},
					[DGV_ENABLEQW] 			= { category = "Display",	text = "Automatic Quest Matching", checked = false,		tooltip = "Disable Blizzard's Automatic Quest Tracking feature and use Dugi Automatic Quest Matching feature which will sync your Objective tracker with the current guide", },
					[DGV_DUGIARROW]			= { category = "Dugi Arrow",	text = "Show Dugi Arrow",	checked = true,		tooltip = "Show Dugis waypoint arrow",},
					[DGV_SHOWCORPSEARROW]		= { category = "Dugi Arrow",	text = "Show Corpse Arrow",	checked = true,		tooltip = "Show the corpse arrow to direct you to your body", indent = true},
					[DGV_CLASSICARROW]			= { category = "Dugi Arrow",	text = "Classic Arrow",		checked = true,		tooltip = "Switch between modern and classic arrow icons", indent = true,},
					[DGV_CARBONITEARROW] 		= { category = "Dugi Arrow",	text = "Use Carbonite Arrow",	checked = true,	tooltip = "Use the Carbonite arrow instead of the built in arrow"},
					[DGV_TOMTOMARROW] 		= { category = "Dugi Arrow",	text = "Use TomTom Arrow", 	checked = false,	tooltip = "Use the TomTom arrow instead of the built in arrow"},
					[DGV_SHOWANTS] 			= { category = "Dugi Arrow",	text = "Show Ant Trail",	checked = true,		tooltip = "Display ant trail between waypoints on the world map",},
					[DGV_AUTOQUESTACCEPT] 		= { category = "Questing",	text = "Auto Quest Accept",	checked = false,	tooltip = "Automatically accept quests from NPCs. Disable with shift",},
					[DGV_AUTOQUESTACCEPTALL]	= { category = "Questing",	text = "Only Quests in Current Guide",	checked = true,	tooltip = "Auto quest accept feature will only accept quests in current guide", indent = true, module = "Guides"},							
					[DGV_AUTOQUESTTURNIN]	= { category = "Questing",	text = "Auto Quest Turn in",	checked = false,	tooltip = "Automatically turn in quests from NPCs. Disable with shift"},							
					[DGV_AUTOSELL]         		= { category = "Other",		text = "Auto Sell Greys",    	checked = false,    	tooltip = "Automatically sell grey quality items to merchant NPCs",},
					[DGV_AUTOREPAIR]			= { category = "Other",		text = "Auto Repair",    		checked = false,    tooltip = "Automatically repair all damaged equipment at repair NPC",},
					[DGV_AUTOFLIGHTPATHSELECT]			= { category = "Dugi Arrow",	showOnRightColumn = true,	text = "Auto Select Flight Path",	checked = false,	tooltip = "Automatically select the suggested flight path after opening the flightmaster map",},
					[DGV_USETAXISYSTEM]			= { category = "Taxi System", text = "Use Taxi System",	checked = true,	tooltip = "Taxi system will find the fastest route to get to your destination with the use of portals, teleports, vehicles etc. Disabling this option will give you a direct waypoint instead.",},
					[DGV_TAXISYSTEM_ZONE_PORTALS]			= { category = "Taxi System",	text = "Use Zone Portals",	checked = true,	tooltip = "",},
					[DGV_TAXISYSTEM_PLAYER_PORTALS]			= { category = "Taxi System",	text = "Use Player Portals",	checked = true,	tooltip = "",},
					[DGV_TAXISYSTEM_BOATS]			= { category = "Taxi System",	text = "Use Boats",	checked = true,	tooltip = "",},
					[DGV_TAXISYSTEM_CLASS_PORTALS]			= { category = "Taxi System",	text = "Use Class Portals",	checked = true,	tooltip = "",},
					[DGV_TAXISYSTEM_WHISTLE]			= { category = "Taxi System",	text = "Use Flight Master Whistle",	checked = true,	tooltip = "",},
                    [DGV_AUTOREPAIRGUILD]		= { category = "Other",		text = "Use Guild Bank",    	checked = false,   	tooltip = "Use guild funds when repairing automatically", indent=true,},
					[DGV_AUTO_QUEST_TRACK] 		= { category = "Questing",	text = "Auto Quest Tracking",	checked = true,		tooltip = "Automatically add quest to the Objective Tracker on accept or objective update", indent=false},
					[DGV_GUIDESUGGESTMODE] 		= { category = "Questing",	text = "Guide Suggest Mode",	showOnRightColumn = true, checked = true,		tooltip = "Suggest guides for your player on level up", module = "Guides", indent=false,},
					[DGV_SMALLFRAMEBORDER] 		= { category = "Frames",	text = "Small Frame Border", dY = -103, position = DGV_DISABLEWATCHFRAMEMOD + 1,	showOnRightColumn = true,	checked = true,	tooltip = "Use the same border that is selected for the large frame", module = "SmallFrame"},
					[DGV_WATCHFRAMEBORDER] 		= { category = "Frames",	text = "Objective Tracker Frame Border", position = DGV_DISABLEWATCHFRAMEMOD + 2,	showOnRightColumn = true,	checked = false,		tooltip = "Add a border for the Objective Tracker Frame", module = "DugisWatchFrame"},
					[DGV_REMOVEMAPFOG]     		= { category = "Maps",		text = "Remove Map Fog",  	checked = true,    	tooltip = "View undiscovered areas of the world map, type /reload in your chat box after change of settings",},
					[DGV_HIGHLIGHTSTEPONENTER]	= { category = "Tooltip",	text = "Highlight Guide Steps",	checked = true,	tooltip = "Guide step text color intensifies when moused over", module = "SmallFrame"},
					[DGV_DISPLAYCOORDINATES]	= { category = "Tooltip",	text = "Tooltip Coordinates",	checked = false,	tooltip = "Show destination coordinates in the status frame tooltip", module = "Guides"},
					[DGV_TARGETBUTTON] 		= { category = "Target",	text = "Target Button",		checked = true,		tooltip = "Target the NPC needed for the quest step", module = "Target"},
					[DGV_TARGETBUTTONSHOW]		= { category = "Target",	text = "Show Target Button",	checked = true,		tooltip = "Show target button frame", indent = "true", module = "Target"},
					[DGV_SHOWONOFF]			= { category = "Frames",	text = "Show DG Icon Button",	checked = true,		tooltip = "Show the On/Off button which enables or disables the guide", },
					[DGV_STICKYFRAME]			= { category = "Frames",	text = "Enable Sticky Frame",	checked = true,		tooltip = "Shift click a quest step to track in the frame", module = "StickyFrame" },
                    [DGV_STICKYFRAMESHOWDESCRIPTIONS]			= { category = "Frames",	text = "Sticky Frame Step Description",	checked = true,		tooltip = "Show step descriptions in the Sticky Frame", module = "StickyFrame" },
					--[DGV_AUTOSTICK] 		= { category = "Other",		text = "Auto Stick", 		checked = true,		tooltip = "This feature will automatically add 'as you go...' step into sticky frame",},
					[DGV_DISPLAYMAPCOORDINATES] 	= { category = "Maps",		text = "Map Coordinates",  	checked = true,    	tooltip = "Show Player and Mouse coordinates at the bottom of the map.",},
					[DGV_WORLDMAPTRACKING] 		= { category = "Maps",		text = "World Map Tracking",  	checked = true,    	tooltip = "Add minimap tracking icons on the world map.",},
					[DGV_BLINKMINIMAPICONS] 		= { category = "Maps",		text = "Blink Minimap Resource Nodes",  	checked = false,    	tooltip = "Resource nodes for gathering profession will blink in your minimap to make it easier to notice", module = "Disabled"},
					[DGV_HIDE_MODELS_IN_WORLDMAP] 		= { category = "Maps",		text = "Hide Model Preview in World Map",  	checked = false,    	tooltip = "Hide Model Preview in World Map"},
					[DGV_ENABLEMODELDB]		= { category = "Hide",	text = "Model Database",	checked = true,		tooltip = "Allows model viewer to function", module = "NpcsF"},
					[DGV_ENABLENPCNAMEDB]		= { category = "Other",	text = "NPC Name Database",	checked = true,		tooltip = "Provides localized NPC names. Required for target button.", module = "Disabled"},
					[DGV_ENABLEQUESTLEVELDB]		= { category = "Other",	text = "Quest Level Database", showOnRightColumn = true,	checked = true,		tooltip = "Shows minimum level required for quests.\n\nAlso used for color coding the quests.", module = "ReqLevel"},
					[DGV_UNLOADMODULES]		= { category = "Other",	text = "Unload Modules", showOnRightColumn = true,	checked = false,	tooltip = "Unloading modules will allow the addon to run on low memory setting in Essential Mode but will require a UI reload to return back to normal. ", module = "Guides"},
					[DGV_ENABLED_MAPPREVIEW]	= { category = "Maps",	text = "Enabled Map Preview",showOnRightColumn = true,		checked = false,		tooltip = "",},
                    [DGV_MAPPREVIEWHIDEBORDER]	= { category = "Maps",	text = "Hide Border",showOnRightColumn = true,		checked = true,	position = DGV_HIDE_MODELS_IN_WORLDMAP + 1,	tooltip = "Hides the minimized map border when map preview is on.",},
					[DGV_AUTOQUESTITEMLOOT]	= { category = "Questing",	text = "Auto Loot Quest Item",	checked = true,		tooltip = "Automatically loot quest items.",},
					[DGV_ACCOUNTWIDEACH]		= { category = "Other",text = "Account Wide Achievement",	checked = false,		tooltip = "Detects account wide achievements completion.", module = "Guides"},
					[DGV_DISABLE_QUICK_SETTINGS]		= { category = "Other",text = "Disable Quick Settings Under "..[[|T]]..DugisGuideViewer.ARTWORK_PATH.."iconbutton"..[[:20:20|t]].."Icon",	checked = false,		tooltip = "", module = "Guides"},
					[DGV_AUTO_MOUNT]		= { category = "Auto Mount", text = "Enable auto mount",	checked = false,		tooltip = "Automatically mounts the fastest available mount.", module = "GearAdvisor"},
					[DGV_EMBEDDEDTOOLTIP]		= { category = "Display",	text = "Embedded Tooltip",	checked = true,	tooltip = "Displays tooltip information under guide step", module = "Guides"},
					[DGV_FIXEDWIDTHSMALL]		= { category = "Display",	text = "Fixed Width Small Frame",	checked = true,	tooltip = "Floating Small Frame won't adjust size horizontally and remain the same width as the Objective Tracker.", module = "Guides"},
					[DGV_OBJECTIVECOUNTER]		= { category = "Display",	text = "Show Quest Objectives",	checked = true,		tooltip = "Display quest objectives in small/anchored frame instead of the watch frame", module = "Guides"},
					[DGV_MULTISTEPMODE]		= { category = "Display",	text = "Multi-step Mode",	checked = true,	tooltip = "Allow status frame to show all currently relevant quests.", module = "Guides"},
					[DGV_FIXEDWIDEFRAME]		= { category = "Display",	text = "Wider Objective Tracker",	checked = false,	tooltip = "Increases the width of the Objective tracker", module = "Hide"},
					[DGV_AUTOEQUIPSMARTSET]		= { category = "Gear Set",		text = "Auto Equip Smart Set",	checked = true,		tooltip = "Automatically maintain the best item for each slot as player level, active spec and inventory changes occur.", module = "GearAdvisor"},
					[DGV_SHOWAUTOEQUIPPROMPT]	= { category = "Gear Set",		text = "Show Auto Equip Prompt",checked = true,		tooltip = "Display a prompt to verify before committing auto equip changes", module = "GearAdvisor"},
					[DGV_DISABLEWATCHFRAMEMOD]	= { category = "Frames",		text = "Lock Objective Tracker", showOnRightColumn = true, indent = true, checked = true,		tooltip = "Lock the objective tracker frame.", module = "DugisWatchFrame"},
					[DGV_MANUALWAYPOINT]		= { category = "Dugi Arrow",		text = "Manual Waypoints",checked = true,		tooltip = "Enable user placed waypoints on the world map by pressing Ctrl + Right click or Shift + Right click to link them together, disable this option if the hotkey conflict with another addon",},
					[DGV_TOMTOMEMULATION]		= { category = "Dugi Arrow",		text = "TomTom Addon Emulation",checked = true,		tooltip = "Enable /way commands and compatibility with other addons that use TomTom addon (eg LightHeaded)",},					
					[DGV_LOCKMODELFRAME]		= { category = "Frames", text = "Lock Model Frame",  checked = true,  tooltip = "Lock model viewer frame into place", module = "ModelViewer"},
					[DGV_JOURNALFRAME]			= { category = "Frames",		text = "NPC Journal Button", checked = true,		tooltip = "Enable NPC Journal Frame", module = "NPCJournalFrame"},					
                    [DGV_JOURNALFRAMEBUTTONSTICKED]			= { category = "Frames",		text = "Floating NPC Journal Button", checked = false, tooltip = "Allow NPC Journal to float anywhere on the screen", indent=true, module = "NPCJournalFrame"},	
					[DGV_FISHINGPOLE]			= { category = "Gear Set",		text = "Ignore Fishing Items", checked = true, tooltip = "Don't suggest to replace fishing pole or items with +fishing stats if equipped", module = "GearAdvisor"},					
					[DGV_COOKINGITEM]			= { category = "Gear Set",		text = "Ignore Cooking Items", checked = true, tooltip = "Don't suggest to replace items with +cooking stats if equipped", module = "GearAdvisor"},
					[DGV_DAILYITEM]			= { category = "Gear Set",		text = "Ignore Daily Quest Items", checked = true, tooltip = "Don't suggest to replace quest items for completing daily quest", module = "GearAdvisor"},
					[DGV_WATCHLOCALQUEST]			= { category = "Questing",		text = "Auto Track Local Quest", checked = false, tooltip = "Automatically remove non-local (not in current map) quest and track local quest to the objective tracker. This will trigger when you accept a quest or during a zone change event"},
					[DGV_TARGETBUTTONCUSTOM]	= { category = "Target",	text = "Customize Macro",		checked = false,	tooltip = "Customize Target Macro", module = "Target", indent = true, editBox = "",},
					[DGV_TRGET_BUTTON_FIXED_MODE] = { category = "Target", text = "Fixed Mode", position = DGV_TARGETBUTTONSHOW + 1, indent = true, checked = true, default = true, tooltip = "",},					
					[DGV_TARGETTOOLTIP]			= { category = "Target",		text = "Target Button Tooltip", checked = true, tooltip = "Display a tooltip for the target button to display the target name and model", indent = true, module = "Target"},						
					[DGV_WAYPOINT_PING]			= { category = "Dugi Arrow",		text = "Waypoint Reached Sound", checked = true, tooltip = "Plays a ping sound upon reaching each waypoint", showOnRightColumn = true},													
					
					[DGV_BAD_COLOR]			= { category = "Dugi Arrow",	text = "Bad Color", checked = false, tooltip = "", showOnRightColumn = true},													
					[DGV_MIDDLE_COLOR]			= { category = "Dugi Arrow",	dX = 120, dY = 26,		text = "Middle Color", checked = false, tooltip = "", showOnRightColumn = true},													
					[DGV_GOOD_COLOR]			= { category = "Dugi Arrow",		text = "Good Color", checked = false, tooltip = "", showOnRightColumn = true},													
					[DGV_EXACT_COLOR]			= { category = "Dugi Arrow",	dX = 120, dY = 26,		text = "Exact Color", checked = false, tooltip = "", showOnRightColumn = true},													
					[DGV_QUESTING_AREA_COLOR]	= { category = "Dugi Arrow",	dX = 0, dY = -5,		text = "Questing Area Color", checked = false, tooltip = "", showOnRightColumn = true},													
				
					[DGV_WAY_SEGMENT_COLOR]		= { category = "Dugi Arrow",	position = DGV_TOMTOMEMULATION + 1,	text = "Ant Trail Color", dY = -18, dX = 100, checked = false,	tooltip = "",},					
					[DGV_ENABLED_GPS_ARROW]		= { category = "Dugi Zone Map", text = "Enable Zone Map", checked = true,	tooltip = "Turn on / off the Dugi Zone Map feature",},					
					[DGV_GPS_ARROW_AUTOZOOM]		= { category = "Dugi Zone Map", text = "Enable Auto Zoom", checked = true, default = true,	tooltip = "Automatically Zoom in / out the map based on the current waypoint",},					
					[DGV_GPS_ARROW_POIS]		= { category = "Dugi Zone Map", text = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|tShow Quests POI", checked = true, default = true,	tooltip = "Turn on /off the point of interest icons for quests on the map.\n\nNOTE: May reduce FPS",},					
					[DGV_GPS_AUTO_HIDE]		= { category = "Dugi Zone Map", text = "Auto Hide Zone Map", checked = true, default = true,	tooltip = "Automatically hides Dugi Map in case there are no waypoints.",},					
					[DGV_GPS_MERGE_WITH_DUGI_ARROW]		= { category = "Dugi Zone Map", text = "Merge With Dugi Arrow", checked = true, default = true,	tooltip = "Dugi Arrow text is displayed underneath the Zone Map and Dugi arrow is automatically shown within close range of the waypoints",},					
					[DGV_GPS_MINIMAP_TERRAIN_DETAIL]		= { category = "Dugi Zone Map", text = "Minimap Terrain Detail", checked = true, default = true,	tooltip = "Turns minimap terrain details on.",},					
					
					[DGV_ENABLED_GEAR_NOTIFICATIONS]			= { category = "Notifications",		text = "Gear Advisor Suggestions as Notifications", checked = true, tooltip = "If disabled standard gear suggestion prompts will be shown.", module = "GearAdvisor"},													
					[DGV_ENABLED_GUIDE_NOTIFICATIONS]			= { category = "Notifications",		text = "Leveling Guide Suggestions as Notifications", checked = true, tooltip = "If disabled standard guide suggestion prompts will be shown.", module = "Guides"},													
					[DGV_ENABLED_JOURNAL_NOTIFICATIONS]			= { category = "Notifications",		text = "NPC Journal Frame targets as Notifications", checked = true, tooltip = "If enabled NPC Journal Frame prompts will be shown.", module = "Guides"},													
					[DGV_USE_NOTIFICATIONS_MARK]			= { category = "Notifications",		text = "Show |TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\notification.tga:20:20:0:0:64:64:39:64:0:25|t mark for new Notifications.", checked = true, tooltip = "If enabled |TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\notification.tga:16:16:0:0:64:64:39:64:0:25|t mark will be shown when new Notifications come.", module = "Guides"},													
					
					[DGV_ALWAYS_SHOW_STANDARD_PROMPT_GEAR]			= { category = "Notifications", indent = true, position = DGV_ENABLED_GEAR_NOTIFICATIONS + 1, text = "Always Show Standard Prompt", checked = true, tooltip = "", module = "Guides"},													
					[DGV_ALWAYS_SHOW_STANDARD_PROMPT_GUIDE]			= { category = "Notifications", indent = true, text = "Always Show Standard Prompt", checked = true, tooltip = "", module = "Guides"},													
					
					[DGV_GAWINCRITERIACUSTOM] = {category = "Gear Scoring", text = L["Loot Suggestion Priority"], tooltip = "Determines how gear should be scored, in order of greatest to least importance.", module = "GearAdvisor",
						options = {
							"Active Talent Specialization",
							--"Inactive Talent Specialization", --Secondary spec removed in Legion
							"Highest Vendor Price"
						}
					},
					
					[DGV_GASTATCAPLEVELDIFFERENCE] = {category = "Gear Scoring", text = "Stat Cap Level Difference", tooltip = "Player/Target level difference. Used in determining caps for hit and expertise.", module = "Hide",
						checked = 2,
						options = {
							{	text = "Even (PvP)", value = 0, },
							{	text = "+1", value = 1, },
							{	text = "+2 (Heroic Dungeon)", value = 2, },
							{	text = "+3 (Raid)", value = 3, },
						}
					},
					
					[DGV_GASMARTSETTARGET] = {category = "Gear Set", text = "Smart Gear Set", tooltip = "Determines which scoring configuration should be used to equip gear with Dugi Smart Set.", module = "GearAdvisor",
						checked = "Active Talent Specialization",
						options = {}
					},

					[DGV_GUIDEDIFFICULTY]		= { category = "Questing",	text = "Leveling Mode",			checked = "Normal", module = "Hidden",
						options = {
							{	text = "Easy", colorCode = GREEN_FONT_COLOR_CODE, },
							{	text = "Normal", colorCode = YELLOW_FONT_COLOR_CODE, },
							{	text = "Hard", colorCode = ORANGE_FONT_COLOR_CODE, },
						}
					},
					[DGV_SMALLFRAMETRANSITION] 	= { category = "Frames",		text = "Small Frame Effect",	checked = "Flash", module = "SmallFrame",
						options = {
							{	text = "None", },
							{	text = "Flash", },
						}
					},
					[DGV_MAIN_FRAME_BACKGROUND] 	= { category = "Display",		text = "Background",	checked = "Solid", module = "SmallFrame",
						options = {
							{	text = "Solid", },
							{	text = "Transparent", },
						}
					}, 
					[DGV_ROUTE_STYLE] 	= { category = "Dugi Arrow",		text = "Ant Trail",	checked = "Dotted",
						options = {
							{	text = "Dotted", },
							{	text = "Solid", },
						}
					}, 
					[DGV_LARGEFRAMEBORDER] 		= { category = "Frames",		text = "Borders",	checked = "BlackGold",
						options = {
							{	text = "Default", },
							{	text = "BlackGold", },
							{	text = "Bronze", },
							{	text = "DarkWood", },
							{	text = "ElvUI", value = "ElvUI", textFunc = function() 
								if Tukui then
									return "ElvUI/Tukui";
								else
									return "ElvUI";
								end
							end     },
							{	text = "Eternium", },
							{	text = "Gold", },
							{	text = "Metal", },
							{	text = "MetalRust", },
							{	text = "OnePixel", },
							{	text = "Stone", },
							{	text = "StonePattern", },
							{	text = "Thin", },
							{	text = "Wood", },
						}
					}, 
					[DGV_GPS_BORDER] 		= { category = "Dugi Zone Map",  text = "Dugi Map Borders",	checked = "TextPanel", default = 1,
						options = {
							{	text = "TextPanel", },
							{	text = "ElvUI2", },
						}
					},
					[DGV_STEPCOMPLETESOUND]		= { category = "Questing",	text = "Step Complete Sound", checked = "Sound\\Interface\\MapPing.ogg", module = "Guides",
						options = {
							{	text = "None", 			value	= nil },
							{	text = "Map Ping", 		value = [[Sound\Interface\MapPing.ogg]]},
							{	text = "Window Close", 		value = [[Sound\Interface\AuctionWindowClose.ogg]]},
							{	text = "Window Open", 		value = [[Sound\Interface\AuctionWindowOpen.ogg]]},
							{	text = "Boat Docked", 		value = [[Sound\Doodad\BoatDockedWarning.ogg]]},
							{	text = "Bell Toll Alliance", 	value = [[Sound\Doodad\BellTollAlliance.ogg]]},
							{	text = "Bell Toll Horde",	value = [[Sound\Doodad\BellTollHorde.ogg]]},
							{	text = "Explosion",		value = [[Sound\Doodad\Hellfire_Raid_FX_Explosion05.ogg]]},
							{	text = "Shing!",		value = [[Sound\Doodad\PortcullisActive_Closed.ogg]]},
							{	text = "Wham!",			value = [[Sound\Doodad\PVP_Lordaeron_Door_Open.ogg]]},
							{	text = "Simon Chime",		value = [[Sound\Doodad\SimonGame_LargeBlueTree.ogg]]},
							{	text = "War Drums",		value = [[Sound\Event Sounds\Event_wardrum_ogre.ogg]]},
							{	text = "Humm",			value = [[Sound\Spells\SimonGame_Visual_GameStart.ogg]]},
							{	text = "Short Circuit",		value = [[Sound\Spells\SimonGame_Visual_BadPress.ogg]]},
						}
					},
					[DGV_TAXIFLIGHTMASTERS]		= { category = "Taxi System",	text = "Use Flightmasters", checked = "Auto",
						options = {
							{	text = "Auto", colorCode = GREEN_FONT_COLOR_CODE, value = "Auto" },
							{	text = "Always", colorCode = YELLOW_FONT_COLOR_CODE, value = "Always" },
							{	text = "Never", colorCode = RED_FONT_COLOR_CODE, value = "Never" },
						}
					},						
					[DGV_QUESTCOMPLETESOUND]		= { category = "Questing",	text = "Quest Complete Sound", checked = "Sound\\Creature\\Peon\\PeonBuildingComplete1.ogg", module = "DugisWatchFrame",
						options = {
							{	text = "None", 			value	= nil },
							{	text = "Default", 		value = [[Sound\Creature\Peon\PeonBuildingComplete1.ogg]]},
							{	text = "Troll Male", 		value = [[Sound\Character\Troll\TrollVocalMale\TrollMaleCongratulations01.ogg]]},
							{	text = "Troll Female",		value = [[Sound\Character\Troll\TrollVocalFemale\TrollFemaleCongratulations01.ogg]]},
							{	text = "Tauren Male",		value = [[Sound\Creature\Tauren\TaurenYes3.ogg]]},
							{	text = "Tauren Female",		value = [[Sound\Character\Tauren\TaurenVocalFemale\TaurenFemaleCongratulations01.ogg]]},
							{	text = "Undead Male",		value = [[Sound\Character\Scourge\ScourgeVocalMale\UndeadMaleCongratulations02.ogg]]},
							{	text = "Undead Female",		value = [[Sound\Character\Scourge\ScourgeVocalFemale\UndeadFemaleCongratulations01.ogg]]},
							{	text = "Orc Male",		value = [[Sound\Character\Orc\OrcVocalMale\OrcMaleCongratulations02.ogg]]},
							{	text = "Orc Female",		value = [[Sound\Character\Orc\OrcVocalFemale\OrcFemaleCongratulations01.ogg]]},
							{	text = "NightElf Female",	value = [[Sound\Character\NightElf\NightElfVocalFemale\NightElfFemaleCongratulations02.ogg]]},
							{	text = "NightElf Male",		value = [[Sound\Character\NightElf\NightElfVocalMale\NightElfMaleCongratulations01.ogg]]},
							{	text = "Human Female",		value = [[Sound\Character\Human\HumanVocalFemale\HumanFemaleCongratulations01.ogg]]},
							{	text = "Human Male",		value = [[Sound\Character\Human\HumanVocalMale\HumanMaleCongratulations01.ogg]]},
							{	text = "Gnome Male",		value = [[Sound\Character\Gnome\GnomeVocalMale\GnomeMaleCongratulations03.ogg]]},
							{	text = "Gnome Female",		value = [[Sound\Character\Gnome\GnomeVocalFemale\GnomeFemaleCongratulations01.ogg]]},
							{	text = "Dwarf Male",		value = [[Sound\Character\Dwarf\DwarfVocalMale\DwarfMaleCongratulations04.ogg]]},
							{	text = "Dwarf Female",		value = [[Sound\Character\Dwarf\DwarfVocalFemale\DwarfFemaleCongratulations01.ogg]]},
							{	text = "Draenei Male",		value = [[Sound\Character\Draenei\DraeneiMaleCongratulations02.ogg]]},
							{	text = "Draenei Female",	value = [[Sound\Character\Draenei\DraeneiFemaleCongratulations03.ogg]]},
							{	text = "BloodElf Female",	value = [[Sound\Character\BloodElf\BloodElfFemaleCongratulations03.ogg]]},
							{	text = "BloodElf Male",		value = [[Sound\Character\BloodElf\BloodElfMaleCongratulations02.ogg]]},
							{	text = "Worgen Male",		value = [[Sound\Character\PCWorgenMale\VO_PCWorgenMale_Congratulations01.ogg]]},
							{	text = "Worgen Female",		value = [[Sound\Character\PCWorgenFemale\VO_PCWorgenFemale_Congratulations01.ogg]]},
							{	text = "Goblin Male",		value = [[Sound\Character\PCGoblinMale\VO_PCGoblinMale_Congratulations01.ogg]]},
							{	text = "Goblin Female",		value = [[Sound\Character\PCGoblinFemale\VO_PCGoblinFemale_Congratulations01.ogg]]},
							{	text = "Pandaren Male",		value = [[Sound\Character\PCPandarenMale\VO_PCPandarenMale_Congratulations02.ogg]]},
							{	text = "Pandaren Female",		value = [[Sound\Character\PCPandarenFemale\VO_PCPandarenFemale_Congratulations02.ogg]]},						
							{	text = "Void Elf Male",	value = [[Sound\Character\pc_-_void_elf_male\vo_735_pc_-_void_elf_male_28_m.ogg]]},
							{	text = "Void Elf Female",	value = [[Sound\Character\pc_-_void_elf_female\vo_735_pc_-_void_elf_female_28_f.ogg]]},
							{	text = "Highmountain Tauren Male",	value = [[Sound\Character\pc_-_highmountain_tauren_male\vo_735_pc_-_highmountain_tauren_male_28_m.ogg]]},
							{	text = "Highmountain Tauren Female",	value = [[Sound\Character\pc_-_highmountain_tauren_female\vo_735_pc_-_highmountain_tauren_female_28_f.ogg]]},
							{	text = "Lightforged Draenei Male",	value = [[Sound\Character\pc_-_lightforged_draenei_male\vo_735_pc_-_lightforged_draenei_male_28_m.ogg]]},
							{	text = "Lightforged Draenei Female",	value = [[sound\character\pc_-_lightforged_draenei_female\vo_735_pc_-_lightforged_draenei_female_28_f.ogg]]},
							{	text = "Nightborne Male",	value = [[Sound\Character\pc_-_nightborne_elf_male\vo_735_pc_-_nightborne_elf_male_28_m.ogg]]},
							{	text = "Nightborne Female",	value = [[Sound\Character\pc_-_nightborne_elf_female\vo_735_pc_-_nightborne_elf_female_28_f.ogg]]},							
						}
					},
					[DGV_TOOLTIPANCHOR]			= {category = "Tooltip",	text = "Tooltip Anchor", checked = "Default", module = "SmallFrame",
						options = {



							{	text = "Default", },
							{	text = "Bottom", },
							{	text = "Top", },
							{	text = "Left", },
							{	text = "Right", },
							{	text = "Bottom Left", },
							{	text = "Bottom Right", },
							{	text = "Top Left", },
							{	text = "Top Right", },
						}
					},
					[DGV_MAPPREVIEWPOIS]			= {category = "Maps",	text = "Quest Objectives", checked = "Single Quest",
						options = {
							{	text = "All Available Quests", },
							{	text = "All Tracked Quests", },
							{	text = "Single Quest", },
						}
					},
					[DGV_DISPLAYPRESET]			= {category = "Display",	text = "Recommended Preset Settings", checked = "Multi-step - Anchored", module = "SmallFrame",
						options = {
							{	text = "Minimal", },
							{	text = "Minimal - No Borders", },
							{	text = "Standard", },
							{	text = "Standard - Anchored", },
							{	text = "Multi-step", },
							{	text = "Multi-step - Anchored", },							
						}
					},
					[DGV_SMALLFRAMEDOCKING] = {category = "Frames", text = "Small Frame Behavior", checked = "Auto", module = "SmallFrame",
						tooltip = "Decides how the Small Frame will expand when it is not anchored inside the Watch Frame.",
						options = {
							{ text = "Auto", },
							{ text = "Relative to Watch Frame", },
							{ text = "Expand Down", },
							{ text = "Expand Up", },
							{ text = "Expand in Both Directions", },
						}
					},
					[DGV_WEAPONPREF]		= { category = "Gear Set",	text = "Dual Wield Preference", checked = "Auto", module = "GearAdvisor",
						tooltip = "Choose how gear advisor will decide which weapon to equip in the main hand and off hand slot when dual wielding. Auto option will decide based on the class and spec.",
						options = {
							{	text = "Auto", },
							{	text = "Fast / Slow", },
							{	text = "Slow / Fast", },
							{	text = "Never Swap", },							
						}
					},						
					[DGV_MINIBLOBQUALITY]		= { category = "Maps",	text = "Minimap Blob Quality",	checked = 0 },
					[DGV_SHOWTOOLTIP]			= { category = "Tooltip",	text = "Auto Tooltip (%.1fs)", checked = 5, module = "SmallFrame", tooltip ="Amount of time the Tooltip will remain in view from the last mouse over on small frame" },
					[DGV_MAPPREVIEWDURATION]	= {	category = "Maps",	text = "Duration (%.1fs)", checked = 5, tooltip = "Amount of time the Map Preview should remain in view (zero to disable).  Enabling this feature will automatically set the world map to windowed mode on reload." },
					[DGV_SMALLFRAMEFONTSIZE]	= {	category = "Display",	text = "Small Frame Font Size (%.1f)", checked = 12, module = "SmallFrame", tooltip = "Size of the font in the Small Frame." },
					[DGV_MOUNT_DELAY]	= {	category = "Auto Mount",	text = "Delay After Spell (%.1f)", checked = 6, tooltip = "" },
                    [DGV_DISPLAYGUIDESPROGRESS] 	= { category = "Display",	text = "Show Progress Bar", 	checked = true,	tooltip = "Show Progress Bar", module = "SmallFrame"},
                    [DGV_DISPLAYGUIDESPROGRESSTEXT] 	= { category = "Display",	text = "Show % text", 	checked = true, indent=true,	tooltip = "Show % text", module = "SmallFrame"},
                    [DGV_TARGETBUTTONSCALE]	    = {	category = "Target",	text = "Target Button Size (%.1f)", checked = 1, module = "Target", tooltip = "Size of the target button." },
					[DGV_ITEMBUTTONSCALE]	    = {	category = "Questing",	text = "Item Button Size (%.1f)",showOnRightColumn = true, checked = 1, tooltip = "Size of the item button." },
					[DGV_NAMEPLATES_TRACKING] = { category = "Questing", text = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|tNameplates Tracking", dY = -80, showOnRightColumn = true, checked = false, default = false, tooltip = "",},
					
					[DGV_NAMEPLATES_SHOW_ICON] = { category = "Questing", text = "Show icon", indent = true, showOnRightColumn = true, checked = true, default = true, tooltip = "",},
					[DGV_NAMEPLATES_SHOW_TEXT] = { category = "Questing", text = "Show text", indent = true, showOnRightColumn = true, checked = true, default = true, tooltip = "",},
					
					[DGV_NAMEPLATEICONSIZE]	    = {	category = "Questing",	text = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|tNameplate icon size (%.1f)",showOnRightColumn = true, checked = 5, tooltip = "" },
					[DGV_NAMEPLATETEXTSIZE]	    = {	category = "Questing",	text = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|tNameplate text size (%.1f)",showOnRightColumn = true, checked = 3, tooltip = "" },
                  
					[DGV_SHOWQUESTABANDONBUTTON]			= { category = "Questing",	showOnRightColumn = true,	text = "Abandon Quests Button",	checked = true,	tooltip = "Mass abandon quests button in your quest log to automatically abandon all quests by their category or zone",},
                    [DGV_SUGGESTTRINKET]			= { category = "Gear Set",	showOnRightColumn = true,	text = "Suggest Trinkets",	checked = false,	tooltip = "A trinket is scored by its stats and item level but not the 'use' or special effect which can make the trinket suggestion inaccurate.\n\nUnticking this setting will disable the trinkets suggestion.",},					
                    
                    [DGV_ENABLEDGEARFINDER]			= { category = "Gear Finder",	showOnRightColumn = false,	text = "Enable Gear Finder",	checked = true,	tooltip = "Gear Finder",},					
                      
                    [DGV_INCLUDE_DUNG_NORMAL]		= { category = "Gear Finder",	showOnRightColumn = false,	text = "Normal",	    checked = true,     tooltip = "",},					
                    [DGV_INCLUDE_DUNG_HEROIC]		= { category = "Gear Finder",	showOnRightColumn = false,	text = "Heroic",	    checked = false,     tooltip = "",},					
                    [DGV_INCLUDE_DUNG_MYTHIC]		= { category = "Gear Finder",	showOnRightColumn = false,	text = "Mythic",	    checked = false,     tooltip = "",},					
                    [DGV_INCLUDE_DUNG_TIMEWALKING]	= { category = "Gear Finder",	showOnRightColumn = false,	text = "Timewalking",	checked = false,     tooltip = "",},					
                    [DGV_INCLUDE_RAIDS_RAIDFINDER]	= { category = "Gear Finder",	showOnRightColumn = false,	text = "Raid Finder",	checked = false,     tooltip = "",},					
                    [DGV_INCLUDE_RAIDS_NORMAL]		= { category = "Gear Finder",	showOnRightColumn = false,	text = "Normal",	    checked = false,  	tooltip = "",},					
                    [DGV_INCLUDE_RAIDS_HEROIC]		= { category = "Gear Finder",	showOnRightColumn = false,	text = "Heroic",	    checked = false,  	tooltip = "",},					
                    [DGV_INCLUDE_RAIDS_MYTHIC]		= { category = "Gear Finder",	showOnRightColumn = false,	text = "Mythic",	    checked = false,  	tooltip = "",},					
                    
                    [DGV_GEARS_FROM_QUEST_GUIDES]		= { category = "Gear Finder",	showOnRightColumn = true,	text = "Search gears from Quest Guides",	    checked = true,  	tooltip = "",},					
                    
                    [DGV_DISPLAYALLSTATS]			= { category = "Gear Scoring",	showOnRightColumn = false,	text = "Display All Stats",	checked = false,	tooltip = "Display unused stats for gear scoring",},					
                  
                    [DGV_JOURNALFRAMEBUTTONSCALE]	    = {	category = "Frames",	text = "NPC Journal Button Size (%.1f)", checked = 4, module = "SmallFrame", tooltip = "Size of the NPC Journal Frame button." },
                    [DGV_SMALLFRAME_STEPS]	    = {	category = "Display",	text = "Maximum Multi Step (%.0f)", checked = 4, module = "SmallFrame", tooltip = "Maximum amout of steps in the Small Frame." },
                    [DGV_GPS_BORDER_OPACITY]	    = {	category = "Dugi Zone Map",	text = "Zone Map Border Opacity (%.1f)", checked = 1, default = 1, tooltip = "" },
                    [DGV_GPS_MAPS_OPACITY]	    = {	category = "Dugi Zone Map",	text = "Zone Map Opacity (%.1f)", checked = 0.4, default = 0.4, tooltip = "" },
                    [DGV_GPS_MAPS_SIZE]	    = {	category = "Dugi Zone Map",	text = "Zone Map Size (%.1f)", checked = 5, default = 5, tooltip = "" },
                    [DGV_GPS_ARROW_SIZE]	    = {	category = "Dugi Zone Map",	text = "Character Arrow Size (%.1f)", checked = 2, default = 2, tooltip = "" },
					[DGV_RECORDSIZE]			= { checked = 500 },
				},
			},
		}
	}
	
	
    --Number 100 for checkboxes was reached. It cannot be used because it would conflict with DGV_GUIDEDIFFICULTY.  
	local sz = defaults.profile.char.settings.sz
	
	LuaUtils:loop(99, function(val)
		sz[#sz + 1] = val
	end)
	
    --For new checkboxes their ids should be added here.
	sz[#sz + 1] = DGV_WAY_SEGMENT_COLOR
	sz[#sz + 1] = DGV_ENABLED_GPS_ARROW
	sz[#sz + 1] = DGV_GPS_ARROW_AUTOZOOM
	sz[#sz + 1] = DGV_GPS_ARROW_POIS
	sz[#sz + 1] = DGV_GPS_AUTO_HIDE
	sz[#sz + 1] = DGV_GPS_MERGE_WITH_DUGI_ARROW
	sz[#sz + 1] = DGV_GPS_MINIMAP_TERRAIN_DETAIL
	sz[#sz + 1] = DGV_TRGET_BUTTON_FIXED_MODE
	sz[#sz + 1] = DGV_NAMEPLATES_TRACKING
	sz[#sz + 1] = DGV_NAMEPLATES_SHOW_ICON
	sz[#sz + 1] = DGV_NAMEPLATES_SHOW_TEXT
		
	self.db 		= LibStub("AceDB-3.0"):New("DugisGuideViewerProfiles", defaults)
	self.chardb		= self.db.profile.char.settings
	self.db.RegisterCallback(self, "OnProfileChanged", "ProfileChanged")
	self.db.RegisterCallback(self, "OnProfileCopied", "ProfileChanged")
	self.db.RegisterCallback(self, "OnProfileReset", "ProfileChanged")
end

function DugisGuideViewer:GetDefaultValue(settingId)
	return DugisGuideViewer.chardb[settingId].default
end

function DugisGuideViewer:GuideOn()
	return DugisGuideViewer.chardb.GuideOn
end

function DugisGuideViewer:IsGoldMode()
	return DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode ~= 1
end

function DugisGuideViewer:ProfileChanged()
	self.chardb = self.db.profile.char.settings
	self:ForceAllSettingsTreeCategories()
	self:SettingFrameChkOnClick()
    DugisGuideViewer:RestoreFramesPositions()
	--After dugi fix in the copper mode Update is not available (clocking it: #128)
    if DugisGuideViewer.Modules.DugisWatchFrame.DelayUpdate then
        DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
    end
end

local function Dugi_Fix()
	CurrentTitle = nil
	DugisGuideViewer.CurrentTitle = nil
	DugisGuideUser.CurrentQuestIndex = nil
	CurrentQuestName = nil
	DugisGuideUser = (DugisGuideUser and wipe(DugisGuideUser)) or  {}
	DugisGuideUser.toskip = {}
	DugisGuideUser.QuestState = {}
	DugisGuideUser.turnedinquests = {}
	DugisGuideUser.removedQuests = {}
	DugisFlightmasterDataTable = {}
	DugisGuideViewerDB = nil
	DugisGuideViewer:ClearScreen()
	DugisGuideViewer.chardb.QuestRecordTable.framePositions = {}
	DugisGuideUser.SkipSaveFramesPosition = true	
    DugisGuideUser.userCustomWeights_v3 = nil
	DugisCharacterCache.CalculateScore_cache_v11 = {}
end

local function ResetDB()
	local essentials = DugisGuideViewer.chardb.EssentialsMode
	local rev = DugisGuideViewer.chardb.SettingsRevision
	local guid = DugisGuideUser.CharacterGUID
	Dugi_Fix()
	LoadSettings()
	DugisGuideViewer.chardb.FirstTime = true
	DugisGuideUser.CharacterGUID = UnitGUID("player") or guid or "PRIOR_RESET"
	DugisGuideViewer.chardb.SettingsRevision = SettingsRevision
	DugisGuideViewer.chardb.EssentialsMode = essentials
end

function DugisGuideViewer:IncompatibleAddonLoaded()
	return (DGV.carboniteloaded and Nx.Quest) or DGV.sexymaploaded or DGV.nuiloaded or DGV.elvuiloaded or DGV.tukuiloaded or DGV.shestakuiloaded or DugisGuideUser.PetBattleOn or DugisGuideViewer.dominosquestloaded or DugisGuideViewer.eskaquestloaded
end

function DugisGuideViewer:IsSmallFrameFloating()
	return (not DugisGuideViewer:UserSetting(DGV_ANCHOREDSMALLFRAME)) 
	or DugisGuideViewer:IncompatibleAddonLoaded()
end


local CATEGORY_TREE
function DugisGuideViewer:OnInitialize()
	DugisGuideViewer.Debug = DugisGuideViewer.Debug or DugisGuideUser.DebugOn
	self:RegisterEvent("PLAYER_LOGIN");
	self:RegisterEvent("ZONE_CHANGED");
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
	self:RegisterEvent("CHAT_MSG_SYSTEM");
	self:RegisterEvent("QUEST_ACCEPTED")
	self:RegisterEvent("QUEST_WATCH_UPDATE")
	self:RegisterEvent("QUEST_LOG_UPDATE")
	self:RegisterEvent("QUEST_TURNED_IN")
	self:RegisterEvent("UNIT_QUEST_LOG_CHANGED")	
	self:RegisterEvent("QUEST_AUTOCOMPLETE")
	self:RegisterEvent("QUEST_DETAIL")
	self:RegisterEvent("QUEST_COMPLETE")	
	self:RegisterEvent("UI_INFO_MESSAGE")
	--self:RegisterEvent("QUEST_QUERY_COMPLETE")
	self:RegisterEvent("ZONE_CHANGED_INDOORS")
	self:RegisterEvent("MINIMAP_UPDATE_ZOOM")	
	self:RegisterEvent("CHAT_MSG_LOOT")
	self:RegisterEvent("ACHIEVEMENT_EARNED")
	self:RegisterEvent("CRITERIA_UPDATE")
	--self:RegisterEvent("TRADE_SKILL_UPDATE")
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterEvent("PLAYER_XP_UPDATE")
	self:RegisterEvent("PLAYER_LOGOUT")
    self:RegisterEvent("PLAYER_LEAVING_WORLD")
	self:RegisterEvent("PET_BATTLE_OPENING_START")
	self:RegisterEvent("QUEST_WATCH_LIST_CHANGED")
	self:RegisterEvent("GARRISON_MISSION_NPC_OPENED")
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
	self:RegisterEvent("NAME_PLATE_UNIT_ADDED")
	self:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
	
	CATEGORY_TREE = { 

		{ value = "Search Locations", 	text = L["Search Locations"], 	icon = nil }, --1
		{ value = "Questing", 	text = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|t"..L["Questing"], 	icon = nil }, --2
		{ value = "Dugi Arrow", 	text = L["Dugi Arrow"], icon = nil }, --3
		{ value = "Dugi Zone Map", 	text = "|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|t"..L["Dugi Zone Map"], 	icon = nil  }, --4
		{ value = "Display", 	text = L["Display"], 	icon = nil }, --5
		{ value = "Frames", 	text = L["Frames"], 	icon = nil }, --6
		{ value = "Maps", 		text = L["Maps"], 		icon = nil }, --7
		{ value = "Taxi System",text = L["Taxi System"],icon = nil }, --8
		{ value = "Target",		text = L["Target Button"],	icon = nil }, --9
		{ value = "Tooltip", 	text = L["Tooltip"], 	icon = nil }, --10
		{ value = "Gear Set",		text = L["Gear Set"],		icon = nil },		 --11
		{ value = "Gear Scoring",		text = L["Gear Scoring"],		icon = nil }, --12
		{ value = "Gear Finder",		text = L["Gear Finder"],		icon = nil }, --13
		{ value = "Auto Mount", 		text = L["Auto Mount"], 	icon = nil }, --14
		{ value = "Notifications", 		text = L["Notifications"], 	icon = nil }, --15
		{ value = "Other", 		text = L["Other"], 	icon = nil }, --16
		{ value = "Profiles", 	text = L["Profiles"] }, --17
	}

    if not DugisGuideViewer:IsModuleRegistered("GearFinder") or not DugisGearFinder.allGearIds then tremove(CATEGORY_TREE, 13) end --Gear Finder 
	if not DugisGuideViewer:IsModuleRegistered("Guides") then tremove(CATEGORY_TREE, 10) end --Tooltip

	if not DugisGuideViewer:IsModuleRegistered("Target") then tremove(CATEGORY_TREE, 9) end --Target
	if not DugisGuideViewer:IsModuleRegistered("Guides") then tremove(CATEGORY_TREE, 5) end --Display
	
	LoadSettings()
	if DugisGuideViewerDB and DugisGuideViewerDB.char then --migrate old user data
		local settings = DugisGuideViewerDB.char[self.db.keys.profile] and DugisGuideViewerDB.char[self.db.keys.profile].settings
		if settings and settings.SettingsRevision==self.chardb.SettingsRevision then
			for k, v in pairs(settings) do
				self.db.profile.char.settings[k] = v
			end
		end
		DugisGuideViewerDB = nil
	end
	if self.chardb.SettingsRevision~=SettingsRevision then
		DugisGuideViewer:DebugFormat("resetting self.chardb.settings.SettingsRevision", "revision", self.chardb.SettingsRevision)
		ResetDB()
		self.chardb.SettingsRevision=SettingsRevision;
	end
	if not DugisGuideViewer:IsModuleRegistered("Guides") then
		self.chardb.EssentialsMode = 1
	end
	--self:InitMapping( )
	DugisGuideViewer:UpdateMainFrame()
    DugisGuideViewer:UpdateAutoMountEnabled()
    
    GUIUtils:CreatePreloader("MainFramePreloader", DugisMain)
    MainFramePreloader:SetFrameStrata("DIALOG")
    MainFramePreloader:SetFrameLevel(120)
    
end

function DugisGuideViewer:initAnts()
	local addon
	
	DugisGuideViewer.carboniteloaded = nil
	DugisGuideViewer.tomtomloaded = nil
	DugisGuideViewer.sexymaploaded = nil
	DugisGuideViewer.nuiloaded = nil
	DugisGuideViewer.tukuiloaded = nil
	DugisGuideViewer.elvuiloaded = nil
	DugisGuideViewer.shestakuiloaded = nil
	DugisGuideViewer.mapsterloaded = nil
	DugisGuideViewer.armoryloaded = nil
	DugisGuideViewer.outfitterloaded = nil
	DugisGuideViewer.arkinventoryloaded = nil
	DugisGuideViewer.zygorloaded = nil
	DugisGuideViewer.wqtloaded = nil	
	DugisGuideViewer.dominosquestloaded = nil	
	DugisGuideViewer.eskaquestloaded = nil		

	for addon=1, GetNumAddOns() do
		local name, _, _, enabled = GetAddOnInfo(addon)
		local loaded = IsAddOnLoaded(addon)
		
		if name == "Carbonite" and loaded then DugisGuideViewer.carboniteloaded = false 
		elseif name == "TomTom" and loaded then DugisGuideViewer.tomtomloaded = false
--		elseif name == "SexyMap" and loaded then DugisGuideViewer.sexymaploaded = true
		elseif name == "nUI" and loaded then DugisGuideViewer.nuiloaded = true
		elseif name == "Tukui" and loaded then DugisGuideViewer.tukuiloaded = true
--		elseif name == "ElvUI" and loaded then DugisGuideViewer.elvuiloaded = true
		elseif name == "LUI" and loaded then DugisGuideViewer.luiloaded = true
		elseif name == "ShestakUI" and loaded then DugisGuideViewer.shestakuiloaded = true
		elseif name == "Mapster" and loaded then DugisGuideViewer.mapsterloaded = true
		elseif name == "Armory" and loaded then DugisGuideViewer.armoryloaded = true
		elseif name == "Outfitter" and loaded then DugisGuideViewer.outfitterloaded = true
		elseif name == "Wholly" and loaded then DugisGuideViewer.whollyloaded = true
		elseif name == "ArkInventory" and loaded then DugisGuideViewer.arkinventoryloaded = true 
		elseif name == "ZygorGuidesViewer" and loaded then DugisGuideViewer.zygorloaded = true
		elseif name == "Dominos_Quest" and loaded then DugisGuideViewer.dominosquestloaded = true	
		elseif name == "EskaQuestTracker" and loaded then DugisGuideViewer.eskaquestloaded = true				
		elseif name == "WorldQuestTracker" and loaded then 
			DugisGuideViewer.wqtloaded = true 
			if WQTrackerDB then 
				if WQTrackerDB.profiles.Default.enable_doubletap then
					WQTrackerDB.profiles.Default.enable_doubletap = false
					print(L["|cff11ff11" .. "Dugi: Disabled WorldQuestTracker's \"Auto World Map\" option, this needs to be off for Dugi waypoint."])
				end
			end
		end	
	end
	
	--if DugisGuideViewer.tomtomloaded then TomTom.profile.persistence.cleardistance = 0 end
end

function DugisGuideViewer:GetFontWidth(text, fonttype)
	local font = fonttype or "GameFontNormal"

	if not DugisFW then CreateFrame( "GameTooltip", "DugisFW" ) end
	local frame = DugisFW
	local fontstring = frame:CreateFontString("tmpfontstr","ARTWORK", font)
	fontstring:SetText(text)
	local fontwidth = fontstring:GetStringWidth()
	return fontwidth
end

function DugisGuideViewer:PrintTable( tbl )
	local key, val, val2
	
	DebugPrint("Table Contents:")
	
	if not tbl then DebugPrint("Table Empty") return end
	
	for key, val in pairs(tbl) do
		if type(val) == "table" then
			for _, val2 in pairs(val) do
				self:PrintBoolTbl(key,val2)
			end
		else
			self:PrintBoolTbl(key,val)
		end
	end
end

function DugisGuideViewer:PrintBoolTbl(key, val)
	local printstr = "key: "
	if type(key) == "boolean" then
		if key == true then printstr = printstr.."true" else printstr = printstr.."false" end
	else

		printstr = printstr..key
	end
	
	printstr = printstr.." val: "
	if type(val) == "boolean" then
		if val == true then printstr = printstr.."true" else printstr = printstr.."false" end
	else
		printstr = printstr..val
	end
	
	DebugPrint(printstr)
end

function DugisGuideViewer:ObjectiveTrackerOriginal()
	return 
	not DugisGuideViewer:UserSetting(DGV_WATCHFRAMEBORDER)
	and not DugisGuideViewer:UserSetting(DGV_MOVEWATCHFRAME)  
	and (
		not DugisGuideViewer:IsGoldMode() or ( DugisGuideViewer:IsGoldMode() and not DugisGuideViewer:UserSetting(DGV_ANCHOREDSMALLFRAME) )
	) 
end

function DugisGuideViewer:RestoreFramesPositions()
--todo: uncomment this
	if DugisGuideViewer.chardb.QuestRecordTable.framePositions then
		LuaUtils:foreach(savablePositionsFrameNames, function(frameName)
			local framePosition = DugisGuideViewer.chardb.QuestRecordTable.framePositions[frameName]
			if framePosition and not (frameName == "ObjectiveTrackerFrame" and (DugisGuideViewer:IncompatibleAddonLoaded() or not DGV:GuideOn() or DGV:ObjectiveTrackerOriginal())) then
				local frame = _G[frameName]
				if frame then
					frame:ClearAllPoints( )
					if framePosition.point then
						if type(framePosition.relativeTo) == "string" and not _G[framePosition.relativeTo] then
							return;
						end
						frame:SetPoint(framePosition.point, framePosition.relativeTo, framePosition.relativePoint, framePosition.xOfs, framePosition.yOfs)
						
						if frameName == "ObjectiveTrackerFrame" and DugisGuideViewer.Modules.DugisWatchFrame then
							local WF = DugisGuideViewer.Modules.DugisWatchFrame
							WF.objectiveTrackerX, WF.objectiveTrackerY = GUIUtils:GetRealFeamePos(ObjectiveTrackerFrame)
						end
						
					end
				end
			end
		end)
	end
end

function DugisGuideViewer:NotificationsEnabled()
    return DugisGuideViewer:UserSetting(DGV_DISABLE_QUICK_SETTINGS) ~= true
end

function DugisGuideViewer:UpdateNotificationsMarkVisibility()
    local notifications = DugisGuideViewer:GetNotifications()
    
    if #notifications > 0 and DugisGuideViewer:UserSetting(DGV_USE_NOTIFICATIONS_MARK) then
        NotificationsMark:Show()
    else
        NotificationsMark:Hide()
    end
end

local notificationsData = {}

function DugisGuideViewer:GetNotifications()
    return notificationsData
end

function DugisGuideViewer:SetNotifications(notifications)
    notificationsData = notifications
    DugisGuideViewer:UpdateNotificationsMarkVisibility()
end

local visualNotifications = {}

function DugisGuideViewer:NotificationsVisible()
    return true
end

function DugisGuideViewer:Notification2VisualNotification(id)
    local result
    LuaUtils:foreach(visualNotifications, function(visualNotification)
        if visualNotification.id == id then
            result = visualNotification
            return "break"
        end
    end)
    return result
end

local lastUsedId = 1
function DugisGuideViewer:AddNotification(definition, limitPerNotificationType)
    local notifications = DugisGuideViewer:GetNotifications()
    
    --Check if some gear suggestion already exists. In case it does remove it. 
    --This ensures that only one gear-suggestion is shown
    if definition.notificationType == "gear-suggestion" then
        LuaUtils:foreach(notifications, function(notification, index)
            if notification.notificationType == "gear-suggestion" then
                DugisGuideViewer:RemoveNotification(notification.id)
            end
        end)
    end
    
    definition = definition or {}
    
    --Check if the same notification already exists
    if definition.notificationType == "journal-frame-notification" then
        local alreadyExisting = DugisGuideViewer:GetNotificationsBy(function(notification) 
            return notification.journalData and notification.journalData.guideObjectId == definition.guideObjectId and notification.journalData.guideType == definition.guideType  
        end)
        
        if alreadyExisting and #alreadyExisting > 0 then
            return 
        end
    end
    
    --Removing items above the limit
    if limitPerNotificationType then
        local oldAmount = DugisGuideViewer:CountNotificationsByType(definition.notificationType)
        while oldAmount >= limitPerNotificationType do
            local theOldest = DugisGuideViewer:GetTheOldestNotification()
            DugisGuideViewer:RemoveNotification(theOldest.id)
            oldAmount = DugisGuideViewer:CountNotificationsByType(definition.notificationType)
        end
    end
    
    notifications[#notifications + 1] = {
        title = definition.title
        , notificationType = definition.notificationType
        , id = lastUsedId
        , created = GetTime()
    }
    
    if definition.notificationType == "journal-frame-notification" then
        notifications[#notifications].journalData = {guideObjectId = definition.guideObjectId, guideType = definition.guideType}
    end
    
    lastUsedId = lastUsedId + 1
    
    DugisGuideViewer:SetNotifications(notifications)
	
	return notifications[#notifications]
end

function DugisGuideViewer:RemoveNotification(id)
    local notifications = DugisGuideViewer:GetNotifications()
    
    LuaUtils:foreach(notifications, function(notification, index)
        if notification.id == id then
            table.remove(notifications, index)
        end
    end)
    
    DugisGuideViewer:SetNotifications(notifications)
end

function DugisGuideViewer:RemoveGuideSuggestionNotifications()
	local notification = DugisGuideViewer:GetNotificationByType("guide-suggestion")
	if notification then
		self:RemoveNotification(notification.id)
	end	
end

function DugisGuideViewer:RemoveNotificationWithAnimation(id)
    local visualNotification = DugisGuideViewer:Notification2VisualNotification(id)
    if visualNotification then
        LuaUtils:FadeOut(visualNotification, 1, 0, 0.7, 
        function()
            DugisGuideViewer:RemoveNotification(id)
            DugisGuideViewer:ShowNotifications()
            DugisGuideViewer.RefreshMainMenu()
        end)
    else
		DugisGuideViewer:RemoveNotification(id)
	end
end

function DugisGuideViewer:GetNotification(id)
    local notifications = DugisGuideViewer:GetNotifications()
    local result
    
    LuaUtils:foreach(notifications, function(notification, index)
        if notification.id == id then
            result = notification
            return "break"
        end
    end)
    
    return result
end

function DugisGuideViewer:GetNotificationByTitle(title)
    local notifications = DugisGuideViewer:GetNotificationsBy(function(notification)
        return notification.title == title
    end)
    
    return notifications and notifications[1]
end


function DugisGuideViewer:GetTheOldestNotification()
    local notifications = DugisGuideViewer:GetNotifications()
    local theOldest
    LuaUtils:foreach(notifications, function(notification, index)
        if theOldest == nil or notification.created < theOldest.created then
            theOldest = notification
        end
    end)
    
    return theOldest
end

function DugisGuideViewer:CountNotificationsByType(notificationType)
    return #DugisGuideViewer:GetNotificationsByType(notificationType)
end


function DugisGuideViewer:GetNotificationsBy(filterFunction)
    local notifications = DugisGuideViewer:GetNotifications()
    local result = {}

    LuaUtils:foreach(notifications, function(notification, index)
        if filterFunction(notification) then
            result[#result + 1] = notification
        end
    end)
    
    return result
end

function DugisGuideViewer:GetNotificationsByType(notificationType)
    return DugisGuideViewer:GetNotificationsBy(function(notification)
        return notification.notificationType == notificationType
    end)
end

function DugisGuideViewer:GetNotificationByType(notificationType)
    local result = DugisGuideViewer:GetNotificationsByType(notificationType)
    if #result > 0 then
        return result[1]
    end
end

local lastNotificationParent = nil
local lastNotificationsConfig = nil

function DugisGuideViewer:ShowNotifications(parent, config)

    if not parent and not lastNotificationParent then
        return
    end
    
    lastNotificationParent = parent or lastNotificationParent
    lastNotificationsConfig = config or lastNotificationsConfig or {}

    local notifications = DugisGuideViewer:GetNotifications()
    
    local dY = 0
    
    DugisGuideViewer:HideNotifications()
    
    if not self.NotificationsHeader then
        self.NotificationsHeaderParent = CreateFrame("Frame", nil, lastNotificationParent)
        self.NotificationsHeaderParent:SetPoint("TOPLEFT", lastNotificationParent, "TOPLEFT", 15, -12) 
        self.NotificationsHeaderParent:Show()
        self.NotificationsHeaderParent:SetWidth(100)
        self.NotificationsHeaderParent:SetHeight(20)
        
        self.NotificationsHeader = self.NotificationsHeaderParent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmallLeft") 
        self.NotificationsHeader:SetText(L["Notifications"])
        self.NotificationsHeader:Show()
        self.NotificationsHeader:SetPoint("TOPLEFT", self.NotificationsHeaderParent, "TOPLEFT", 0, 0)    
        self.NotificationsHeader:SetAlpha(1) 
    end
    
    if #notifications > 0 then
        dY = -20
        self.NotificationsHeaderParent:Show()
    else
        self.NotificationsHeaderParent:Hide()
    end
    
    LuaUtils:foreach(notifications, function(notification, index)
        --Building notification 
        local visualNotification
        
        if visualNotifications[index] then
            visualNotification = visualNotifications[index]
        else
            visualNotifications[index] = CreateFrame("Button", nil, lastNotificationParent, "NotificationItemTemplate")
            visualNotification = visualNotifications[index]
        end
        
        if DugisGuideViewer:NotificationsVisible() then
            visualNotification:Show()
        end
        
        visualNotification:SetAlpha(1)
        visualNotification:ClearAllPoints()       
        
        visualNotification:SetPoint("TOPLEFT", lastNotificationParent, "TOPLEFT", (lastNotificationsConfig.dX or 0), dY + (lastNotificationsConfig.dY or 0))
        visualNotification:SetPoint("RIGHT", lastNotificationParent, "RIGHT", -(lastNotificationsConfig.dX or 0), 0)

        visualNotification.Title:SetText(notification.title)  
        
        local height = visualNotification.Title:GetHeight() + 5
        
        if height < 20 then 
            height = 20
        end        
        
        visualNotification:SetHeight(height)        
        visualNotification.Background:SetHeight(height)  

        dY = dY - height - 1                
        
        visualNotification.id = notification.id
    end)
    
    DugisGuideViewer:UpdateNotificationsMarkVisibility()
    
    return -dY
end

function DugisGuideViewer:HideNotifications()
    LuaUtils:foreach(visualNotifications, function(visualNotification)
        visualNotification:Hide()
    end)
end

function DugisGuideViewer:OnNotificationClicked(notification)

    if notification.notificationType == "journal-frame-notification" then
        local guideType = notification.journalData.guideType
        local guideObjectId = notification.journalData.guideObjectId
        
        DugisGuideViewer.NPCJournalFrame:SetGuideData(guideType, guideObjectId, true)
        
        LuaUtils:FadeOut(LibDugi_DropDownList1, 1, 0, 0.7, 
        function()
            DugisGuideViewer:RemoveNotification(notification.id)
            DugisGuideViewer:UpdateNotificationsMarkVisibility()
            LibDugi_DropDownList1:Hide()
            LibDugi_DropDownList1:SetAlpha(1)
        end)
		return
        
    end    


    if notification.notificationType == "gear-suggestion" then
        DugisEquipPromptFrame:Show()
        DugisEquipPromptFrame.notificationId = notification.id
        
        LuaUtils:FadeOut(LibDugi_DropDownList1, 1, 0, 0.7, 
        function()
            DugisGuideViewer:RemoveNotification(notification.id)
            DugisGuideViewer:UpdateNotificationsMarkVisibility()
            LibDugi_DropDownList1:Hide()
            LibDugi_DropDownList1:SetAlpha(1)
        end)
		return
        
    end    
	
    if notification.notificationType == "guide-suggestion" then
        DugisGuideViewer:AskGuideSuggest(UnitLevel("player"))
        LuaUtils:FadeOut(LibDugi_DropDownList1, 1, 0, 0.7, 
        function()
            DugisGuideViewer:RemoveNotification(notification.id)
            DugisGuideViewer:UpdateNotificationsMarkVisibility()
            LibDugi_DropDownList1:Hide()
            LibDugi_DropDownList1:SetAlpha(1)
        end)
		return
    end
	
    DugisGuideViewer:RemoveNotificationWithAnimation(notification.id)
end

function DugisGuideViewer:OnNotificationDismissClicked(notification)
    if notification.notificationType == "gear-suggestion" then
        DugisEquipPromptFrame:Show()
        DugisEquipPromptFrameCancelButton:Click()
    end
end

--/run TestNotifications()
function TestNotifications()
    DugisGuideViewer:AddNotification({title = "Test notification 1"})
    DugisGuideViewer:AddNotification({title = "Test notification 2"})
    DugisGuideViewer:AddNotification({title = "Test notification 3"})
    DugisGuideViewer:AddNotification({title = "Test notification 4"})
    DugisGuideViewer:ShowNotifications()
    DugisGuideViewer.RefreshMainMenu()
end

function DugisGuideViewer:OnLoad()
	--DugisGuideViewer.Target:Init( )
	--DugisGuideViewer.chardb.GuideOn = true
	--DugisGuideViewer.StickyFrame:Init( )
	
    --TestNotifications()
    
	self:SetAllBorders()
	DugisGuideViewer:SetMemoryOptions()

	DugisGuideViewer:SetEssentialsOnCancelReload()
    DugiGuidesOnLoadingStart()

LuaUtils:PostCombatRun("LoadingModules", function(threading)
    if not DugisGuideViewer:GuideOn() then
        DugiGuidesIsLoading = false
    end

	DugisGuideViewer.chardb.GuideOn = DugisGuideViewer:GuideOn() and DugisGuideViewer:ReloadModules(threading)
	DugisGuideViewer:SettingFrameChkOnClick(_, true)
	
	if ((DugisGuideViewer.carboniteloaded and Nx.Quest) or DugisGuideViewer.sexymaploaded or DugisGuideViewer.nuiloaded or DugisGuideViewer.elvuiloaded or DugisGuideViewer.tukuiloaded or DugisGuideViewer.shestakuiloaded or DugisGuideViewer.dominosquestloaded or DugisGuideViewer.eskaquestloaded) then 
		DugisGuideViewer:SetDB(false, DGV_ANCHOREDSMALLFRAME)

		DugisGuideViewer:SetDB(false, DGV_WATCHFRAMEBORDER)
		--DugisGuideViewer:SetDB(false, DGV_MOVEWATCHFRAME)
		DugisGuideViewer:UpdateCompletionVisuals()
	end

    LuaUtils:collectgarbage(threading)
	DugisGuideViewer:UpdateIconStatus()
	--if DugisGuideViewer.GuideOn and DugisGuideViewer.chardb.EssentialsMode ~= 1 then DelayandMoveToNextQuest(3) end
	if DugisGuideViewer:IsModuleLoaded("DugisWatchFrame") and self:UserSetting(DGV_DISABLEWATCHFRAMEMOD) then
		DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
	end
	DugisGuideViewer:RefreshQuestWatch()
	DugisGuideUser.PetBattleOn = false
	
	if DugisGuideViewer:UserSetting(DGV_ENABLENPCNAMEDB) == false then
		DugisGuideViewer:SetDB(true, DGV_ENABLENPCNAMEDB)
	end
    
    DugisGuideViewer:RestoreFramesPositions()
    
    --bugfix #128 Fix unclickable DG icon bug
    if DugisOnOffButton:GetTop() == nil then
        DugisOnOffButton:ClearAllPoints();
        DugisOnOffButton:SetPoint("TOPLEFT", "Minimap", "TOPLEFT", -13, -20)
    end
end)
    

end

function DugisGuideViewer:SetMemoryOptions()
	--[[if not DugisGuideViewer:UserSetting(DGV_ENABLEMODELDB) then 
		--table.wipe(self.ModelViewer.npcDB)
		--table.wipe(self.ModelViewer.objDB)
		--self.ModelViewer.npcDB = {}

		--self.ModelViewer.objDB = {}
		--DebugPrint("#Wipe Objects")
		DugisGuideViewer.UnloadModule("NpcsF")
		DugisGuideViewer.UnloadModule("ObjectsF")
		DugisGuideViewer.UnloadModule("NpcsT")
		DugisGuideViewer.UnloadModule("ObjectsT")
		DugisGuideViewer.UnloadModule("ModelViewer")
	elseif DugisGuideViewer.GuideOn then
		DugisGuideViewer:LoadModule("ModelViewer")
		DugisGuideViewer.LoadModule("NpcsF")
		DugisGuideViewer.LoadModule("ObjectsF")
		DugisGuideViewer.LoadModule("NpcsT")
		DugisGuideViewer.LoadModule("ObjectsT")
	end
	
	if not DugisGuideViewer:UserSetting(DGV_ENABLENPCNAMEDB) then 
		--table.wipe(DugisNPCs)
		DugisNPCs = {}
		DebugPrint("#Wipe NPC table")
	end
	
	if not DugisGuideViewer:UserSetting(DGV_ENABLEQUESTLEVELDB) then
		--table.wipe(self.ReqLevel)
		self.ReqLevel = {}
		DebugPrint("#Wipe ReqLevel table")
	end]]
	
	collectgarbage()
end

local function Disable(frame, dontChangeState)
	if frame then 
		--DebugPrint("frame type:"..frame:GetObjectType())
		if frame:GetObjectType() == "CheckButton" then
			if not dontChangeState then
				frame:SetChecked(false)
			end
			frame.Text:SetTextColor(0.5, 0.5, 0.5)
		end
		frame:Disable() 
	end
end

local function Enable(frame)
	if frame then
		if frame:GetObjectType() == "CheckButton" then
			frame.Text:SetTextColor(1, 1, 1) 
		end
		frame:Enable() 
	end
end

local profileCache = {}
local profileList = {}
local function getProfileList(noCurrent, noDefaults)
	wipe(profileList)
	if not noDefaults then
		profileList[1] = L["Default"]
		profileList[2] = DugisGuideViewer.db.keys.char
		profileList[3] = tinsert(profileList, DugisGuideViewer.db.keys.realm)
		profileList[4] = UnitClass("player")
	end
	
	wipe(profileCache)
	DugisGuideViewer.db:GetProfiles(profileCache)
	for _,v in ipairs(profileCache) do
		if not tContains(profileList, v) then
			tinsert(profileList, v)
		end
	end
	
	if noCurrent then
		for i,v in ipairs(profileList) do
			if v==DugisGuideViewer.db.keys.profile then
				tremove(profileList, i)
				break
			end
		end
	end
	
	return profileList
end

local function SetUseItem(index)
	DugisGuideViewer:SetUseItem(index)
end

local function SetUseItemByQID(questId)
	DugisGuideViewer:SetUseItemByQID(questId)
end

function DugisGuideViewer:UpdateOrderedListView(optionIndex, ...)
	local SettingsDB = 	DugisGuideViewer.chardb
	local container = _G["DGV_OrderedListContainer"..optionIndex]
	local height = 16*#SettingsDB[optionIndex].options
	if height==0 then height=1 end
	container:SetHeight(height)
	local lastShown
	for i=1,select("#", ...) do
		local option = SettingsDB[optionIndex].options[i]
		local child = select(i, ...)
		if option then
			if type(option)=="string" then
				child.text:SetText(L[option])
			else
				local _, specName = GetSpecializationInfo(option)
				child.text:SetText(specName)
			end
			child:Show()
			lastShown = child
		else
			child:Hide()
		end
	end
	return lastShown
end

local gearScoringCriteria = {}
local function GetGearScoringCriteria()
	wipe(gearScoringCriteria)
	for _, option in ipairs(DugisGuideViewer.chardb[DGV_GASMARTSETTARGET].options) do
		if option~="None" then
			tinsert(gearScoringCriteria, option)
		end
	end
	tinsert(gearScoringCriteria, "Highest Vendor Price")
	for _,option in ipairs(DugisGuideViewer.chardb[DGV_GAWINCRITERIACUSTOM].options) do
		local index = DugisGuideViewer.tIndexOfFirst(gearScoringCriteria, option)
		if index then tremove(gearScoringCriteria, index) end
	end
	return gearScoringCriteria
end

function DugisGuideViewer:GetNamedMountType(mountType)
    if  mountType == 230 then
        return "ground"
    end
    
    if mountType == 248  then
        return "flying"
    end
    
    if mountType == 254  or mountType == 231 or mountType == 232 then
        return "aquatic"
    end
    
    return "other"
end

function DugisGuideViewer:IsEquippedOneOfExcludedSets()
    local result = false

    local excludedSets = DugisGuideViewer.chardb["excludedSets"] or {}
    local equippedSets = {}
    
    local fn = (C_EquipmentSet and C_EquipmentSet.GetNumEquipmentSets) or GetNumEquipmentSets
    LuaUtils:loop(fn(), function(i)  
        local name, icon, setID, isEquipped
       
        if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetIDs then
           --For 7.2.0
           
           local equipmentSetIDs = C_EquipmentSet.GetEquipmentSetIDs();
           name, icon, setID, isEquipped = C_EquipmentSet.GetEquipmentSetInfo(equipmentSetIDs[i])
        else
            name, icon, setID, isEquipped = GetEquipmentSetInfo(i) 
        end
       
        if isEquipped then
            equippedSets[name] = true
        end
    end)

    LuaUtils:foreach(excludedSets, function(isExcluded, setName)
        if isExcluded and equippedSets[setName] == true then
            result = true 
        end
    end)
    
    return result
end

function DugisGuideViewer:UpdateSetsExcludingInSettings(frame)

    local function PrepareSetsForTree()
        local result = {}
        
        local fn = (C_EquipmentSet and C_EquipmentSet.GetNumEquipmentSets) or GetNumEquipmentSets
        LuaUtils:loop(fn(), function(i)  
            local name, icon
            
            if C_EquipmentSet and C_EquipmentSet.GetEquipmentSetInfo then
               --For 7.2.0
               local equipmentSetIDs = C_EquipmentSet.GetEquipmentSetIDs();
               name, icon = C_EquipmentSet.GetEquipmentSetInfo(equipmentSetIDs[i])
            else
               name, icon = GetEquipmentSetInfo(i) 
            end
            
            if name ~= "Dugi Smart Set" then
                result[#result + 1] = {name = name, icon = icon or "Interface\\ICONS\\INV_Misc_QuestionMark"}
            end
        end)
    
        return result
    end
    
    local data = PrepareSetsForTree()

    local config = {
      parent                  = frame
    , name                    = "setsList"
    , data                    = data
    , x                       = 323
    , y                       = -120
    , nodesOffsetY            = -10
    , width                   = 420
    , height                  = 228
    , onNodeClick             = function(visualNode)
          local excludedSets = DugisGuideViewer.chardb["excludedSets"] or {}
          excludedSets[visualNode.nodeData.name] = not excludedSets[visualNode.nodeData.name]
          DugisGuideViewer.chardb["excludedSets"] = excludedSets
          DugisGuideViewer:UpdateSetsExcludingInSettings(frame)
      end
    , iconSize                = 25
    , nodeHeight              = 29
    , noScrollMode            = false
    , columnWidth             = 240
    , nodeTextX               = 30
    , scrollX                 = 560
    , scrollY                 = -70
    , scrollHeight            = 190
    , nodeTextY               = -7
    , nodeTextProcessor = function(text, nodeData)
        local excludedSets = DugisGuideViewer.chardb["excludedSets"] or {}
        
        if excludedSets[nodeData.name] then
            return text
        else
            return "|cff555555" .. text .. "|r"
        end
     end }
        
    setsListScrollFrame = SetScrollableTreeFrame(config)
    
    setsListScrollFrame.scrollBar:ClearAllPoints()
    setsListScrollFrame.frame:ClearAllPoints()
    
    setsListScrollFrame.scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -55 + 43, -40 - 74)
    setsListScrollFrame.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 100 + 43, -20 - 74)   
    
    if #data > 6 then
        setsListScrollFrame.scrollBar:Show()
    else
        setsListScrollFrame.scrollBar:Hide()
        setsListScrollFrame.scrollBar:SetValue(0)
        setsListScrollFrame.scrollBar:SetMinMaxValues(0, 0) 
    end
    
    if not DugisGuideViewer.hooked_SaveEquipmentSet then
        if SaveEquipmentSet then
            hooksecurefunc("SaveEquipmentSet", function() 
                DugisGuideViewer:UpdateSetsExcludingInSettings(frame)
            end)
            
            hooksecurefunc("DeleteEquipmentSet", function() 
                DugisGuideViewer:UpdateSetsExcludingInSettings(frame)
            end)   
            
            hooksecurefunc("ModifyEquipmentSet", function() 
                DugisGuideViewer:UpdateSetsExcludingInSettings(frame)
            end)
        end
        
        if C_EquipmentSet and C_EquipmentSet.SaveEquipmentSet then
            --For > 7.2.0
            if C_EquipmentSet.SaveEquipmentSet then
                hooksecurefunc(C_EquipmentSet, "DeleteEquipmentSet", function() 
                    DugisGuideViewer:UpdateSetsExcludingInSettings(frame)
                end)   
                
                hooksecurefunc(C_EquipmentSet, "ModifyEquipmentSet", function() 
                    DugisGuideViewer:UpdateSetsExcludingInSettings(frame)
                end)
            end
        end
        
        DugisGuideViewer.hooked_SaveEquipmentSet = true
    end
    
end

--Configuration
local rightColumnX = 300
local columnPaddingLeft = 16

function DugisGuideViewer:InsertControlBeforeCheckbox(SettingNum, category, top, topRightColumn, frame)
	if category=="Maps" and SettingNum == DGV_MAPPREVIEWHIDEBORDER then
        --Map preview title
		local fontstring = frame:CreateFontString(nil,"ARTWORK", "GameFontNormalLarge")
		fontstring:SetText(L["Map Preview"])
		fontstring:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX + columnPaddingLeft, topRightColumn + 24)    
	end
	
    if category=="Frames" and SettingNum == DGV_SMALLFRAMEBORDER then
        --Borders
		local fontstring = frame:CreateFontString(nil,"ARTWORK", "GameFontNormalLarge")
		fontstring:SetText(L["Borders"])
		fontstring:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX + columnPaddingLeft, topRightColumn - 77)    
	end
	
	if category=="Dugi Arrow" and SettingNum == DGV_BAD_COLOR then
		local fontstring = frame:CreateFontString(nil,"ARTWORK", "GameFontNormal")
		fontstring:SetText(L["Dugi Arrow Colors"])
		fontstring:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX + columnPaddingLeft, topRightColumn - 7)   
	    topRightColumn = topRightColumn - 30
	end
	
	if category=="Other" and SettingNum == DGV_ENABLEQUESTLEVELDB and (DugisGuideViewer:IsModuleRegistered("Guides") 
	or DugisGuideViewer:IsModuleRegistered("ReqLevel") ) then
        --Memory
		local fontstring = frame:CreateFontString(nil,"ARTWORK", "GameFontNormalLarge")
		fontstring:SetText(L["Memory"])
		fontstring:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX + columnPaddingLeft, topRightColumn + 24)    
	end	
    
    return top, topRightColumn
end

function DugisGuideViewer:InsertControlAfterCheckbox(SettingNum, category, top, topRightColumn, frame)
	--Reset Profile Button
	if category=="Dugi Arrow" and not DGV_ResetColorsButton and SettingNum == DGV_QUESTING_AREA_COLOR then
	
		topRightColumn = topRightColumn - 15
		local button = CreateFrame("Button", "DGV_ResetColorsButton", frame, "UIPanelButtonTemplate")
		local btnText = L["Default Colors"]
		local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
		button:SetText(btnText)
		button:SetWidth(fontwidth + 30)
		button:SetHeight(22)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX + columnPaddingLeft, topRightColumn)
		button:RegisterForClicks("LeftButtonUP")
		button:SetScript("OnClick", function() 
			DugisGuideViewer.onColorChange("DGV_BAD_COLOR", unpack(DugisGuideViewer.defaultBadArrowColor))
			DugisGuideViewer.onColorChange("DGV_MIDDLE_COLOR", unpack(DugisGuideViewer.defaultMiddleArrowColor))
			DugisGuideViewer.onColorChange("DGV_GOOD_COLOR", unpack(DugisGuideViewer.defaultGoodArrowColor))
			DugisGuideViewer.onColorChange("DGV_EXACT_COLOR", unpack(DugisGuideViewer.defaultExactArrowColor))
			DugisGuideViewer.onColorChange("DGV_QUESTING_AREA_COLOR", unpack(DugisGuideViewer.defaultQuestingAreaColor))
		end)
	end
	
	if category=="Dugi Zone Map" and not DGV_ResetGPSButton and SettingNum == DGV_GPS_MERGE_WITH_DUGI_ARROW then
	
		local button = CreateFrame("Button", "DGV_ResetGPSButton", frame, "UIPanelButtonTemplate")
		local btnText = L["Default Setting"]
		local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
		button:SetText(btnText)
		button:SetWidth(fontwidth + 30)
		button:SetHeight(22)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, top - 90)
		button:RegisterForClicks("LeftButtonUP")
		button:SetScript("OnClick", function() 
			DugisGuideViewer.SetSettingDefaultValue(DGV_GPS_ARROW_AUTOZOOM)
			DugisGuideViewer.SetSettingDefaultValue(DGV_GPS_ARROW_POIS)
			DugisGuideViewer.SetSettingDefaultValue(DGV_GPS_AUTO_HIDE)
			DugisGuideViewer.SetSettingDefaultValue(DGV_GPS_MERGE_WITH_DUGI_ARROW)
			DugisGuideViewer.SetSettingDefaultValue(DGV_GPS_MINIMAP_TERRAIN_DETAIL)
			
			DugisGuideViewer.SetSettingDefaultValue(DGV_GPS_BORDER_OPACITY)
			DugisGuideViewer.SetSettingDefaultValue(DGV_GPS_MAPS_OPACITY)
			DugisGuideViewer.SetSettingDefaultValue(DGV_GPS_MAPS_SIZE)
			DugisGuideViewer.SetSettingDefaultValue(DGV_GPS_ARROW_SIZE)
			
			DugisGuideViewer.SetSettingDefaultValue(DGV_GPS_BORDER)
			
			DugisGuideViewer.Modules.GPSArrowModule.UpdateVisibility()
			DugisGuideViewer.Modules.GPSArrowModule.UpdateMerged()
			DugisGuideViewer.Modules.GPSArrowModule.UpdatePOISVisibility()
			DugisGuideViewer.Modules.GPSArrowModule:UpdateBorder()
			DugisGuideViewer.Modules.GPSArrowModule.UpdateMinimapAlpha()
		end)
	end
	
	if category=="Notifications" and SettingNum == DGV_USE_NOTIFICATIONS_MARK then
		top = top - 12
		if not enableNotificationsInfo then
			frame:CreateFontString("enableNotificationsInfo","ARTWORK", "GameFontHighlightSmall")
			enableNotificationsInfo:SetText(L["Enable Quick Settings option in 'Other' category to use Notifications."])
		end
		enableNotificationsInfo:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, top )    	
	end
    
    return top, topRightColumn
end

function DugisGuideViewer:UpdateCheckbox(SettingNum)
	if SettingNum == DGV_USE_NOTIFICATIONS_MARK then
		if DugisGuideViewer:NotificationsEnabled() then
			enableNotificationsInfo:Hide()
		else
			enableNotificationsInfo:Show()
		end
	end
end

function DugisGuideViewer.UpdateSettingsCheckbox(settingsId)
    local value = DugisGuideViewer:GetDB(settingsId)
    local chkBoxName = "DGV.ChkBox"..settingsId
    local chkBox = _G[chkBoxName]
    if chkBox then
        chkBox:SetChecked(value)
    end
end

function DugisGuideViewer.SetCheckboxChecked(settingsId, newValue)
	DugisGuideViewer:SetDB(newValue, settingsId)
	DugisGuideViewer.UpdateSettingsCheckbox(settingsId)
end

function DugisGuideViewer.SetSettingDefaultValue(settingsId)
	local defaultValue = DugisGuideViewer:GetDefaultValue(settingsId)
	if defaultValue ~= nil then
		if DugisGuideViewer.sliderControls[settingsId] then
			--Slider
			DugisGuideViewer.sliderControls[settingsId]:SetValue(defaultValue)
		elseif DugisGuideViewer.dropdownControls[settingsId] then
		
			local defaultIndex = defaultValue
			local defaultValue
			if type(DugisGuideViewer.chardb[settingsId].options[defaultIndex]) == "string" then
				defaultValue = DugisGuideViewer.chardb[settingsId].options[defaultIndex]
			else
				defaultValue = DugisGuideViewer.chardb[settingsId].options[defaultIndex].text
			end
			
			LibDugi_UIDropDownMenu_SetSelectedID(DugisGuideViewer.dropdownControls[settingsId], defaultIndex)
			LibDugi_UIDropDownMenu_SetSelectedValue(DugisGuideViewer.dropdownControls[settingsId], defaultValue)
			LibDugi_UIDropDownMenu_SetText(DugisGuideViewer.dropdownControls[settingsId], defaultValue)
			
			DugisGuideViewer:SetDB(defaultValue, settingsId)
		else
			--Checkbox
			DugisGuideViewer:SetDB(defaultValue, settingsId)
			DugisGuideViewer.UpdateSettingsCheckbox(settingsId)
		end
	end
end

local AceGUI = LibStub("AceGUI-3.0")
local function GetSettingsCategoryFrame(category, parent)
	local self = DugisGuideViewer
	local frameName = string.format("DGV_%sCategoryFrame", category)
	local frame = _G[frameName]
	if not frame then



		frame =  CreateFrame("Frame", frameName, parent)
		frame:SetAllPoints(parent)
	
		local fontstring = frame:CreateFontString(nil,"ARTWORK", "GameFontNormalLarge")
		fontstring:SetText(L[category])
		fontstring:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, -16)
	end
	
	local SettingsDB = 	DugisGuideViewer.chardb
	local top = -40
    local topRightColumn = -40
	
	local checkboxesInfo = {}
	
	LuaUtils:foreach(SettingsDB.sz, function(SettingNum)
		checkboxesInfo[#checkboxesInfo + 1] = {SettingNum = SettingNum, info = SettingsDB[SettingNum]}
	end)
	
    --Sorting table by ids (standard past behaviour). In case position parameter exists sorts by position.
    table.sort(checkboxesInfo, function(a, b)
		local position_a = a.info.position or a.SettingNum
		local position_b = b.info.position or b.SettingNum
		
		return position_a < position_b
    end)

	LuaUtils:foreach(checkboxesInfo, function(info)
		local SettingNum = info.SettingNum
		if SettingsDB[SettingNum].category==category
			and(not DugisGuideViewer:GetDB(SettingNum, "module") 
			or DugisGuideViewer:IsModuleRegistered(DugisGuideViewer:GetDB(SettingNum, "module")))
		then
			local chkBoxName = "DGV.ChkBox"..SettingNum
			local chkBox = _G[chkBoxName]
			if not chkBox then

				top, topRightColumn = DugisGuideViewer:InsertControlBeforeCheckbox(SettingNum, category, top, topRightColumn, frame)
				
				chkBox = CreateFrame("CheckButton", chkBoxName, frame, "InterfaceOptionsCheckButtonTemplate")
                
                local topValue = top
                local xShift = 0
                
                if SettingsDB[SettingNum].showOnRightColumn then
                    --Extra y shifts
                    if SettingNum == DGV_SUGGESTTRINKET then
                        topRightColumn = topRightColumn + 15
                    end     
                
                    xShift = rightColumnX
                    
                    if SettingNum == DGV_DISPLAYALLSTATS then
                       -- topRightColumn = topRightColumn + 25
                       -- xShift = 285
                    end
                    
                    topValue = topRightColumn
					
					topValue = topValue + (SettingsDB[SettingNum].dY or 0)
                    topRightColumn = topRightColumn - chkBox:GetHeight()
                    topRightColumn = topRightColumn + (SettingsDB[SettingNum].dY or 0)
				else
					topValue = topValue + (SettingsDB[SettingNum].dY or 0)
                    top = top - chkBox:GetHeight()
					top = top + (SettingsDB[SettingNum].dY or 0)
                end
                
				xShift = xShift + (SettingsDB[SettingNum].dX or 0)
				
				if SettingsDB[SettingNum].indent then
					chkBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 40 + xShift, topValue)
				else
					chkBox:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft + xShift, topValue)
				end
				chkBox.Text:SetText(L[SettingsDB[SettingNum].text])
				chkBox:SetHitRectInsets(0, 0, 0, 0)
				chkBox:RegisterForClicks("LeftButtonDown")
				chkBox:SetScript("OnClick", function() DugisGuideViewer:SettingFrameChkOnClick (chkBox) 	   end)
				chkBox:SetScript("OnEnter", function() DugisGuideViewer:SettingsTooltip_OnEnter(chkBox, event) end)
				chkBox:SetScript("OnLeave", function() DugisGuideViewer:SettingsTooltip_OnLeave(chkBox, event) end)
                
                --Extra separators/labels
                if SettingNum == DGV_ENABLEDGEARFINDER then
                    local fontstring = frame:CreateFontString("SearchGearsFromDungeonGuidesLabel","ARTWORK", "GameFontHighlightLeft")
                    fontstring:SetText("Search gears from dungeon guides:")
                    fontstring:SetPoint("TOPLEFT", frame, "TOPLEFT", 18 + xShift, top - 16)
                    top = top - fontstring:GetStringHeight() - 20
                end
                
                if SettingNum == DGV_INCLUDE_DUNG_TIMEWALKING then
                    local fontstring = frame:CreateFontString("SearchGearsFromRaidGuidesLabel","ARTWORK", "GameFontHighlightLeft")
                    fontstring:SetText("Search gears from raid guides:")
                    fontstring:SetPoint("TOPLEFT", frame, "TOPLEFT", 18 + xShift, top - 5)
                    top = top - fontstring:GetStringHeight() - 10
                end  

				top, topRightColumn = DugisGuideViewer:InsertControlAfterCheckbox(SettingNum, category, top, topRightColumn, frame)	
                
			end
			chkBox:SetChecked(SettingsDB[SettingNum].checked)
			
			DugisGuideViewer:UpdateCheckbox(SettingNum)
		end
	end)
	
	if category=="Dugi Arrow" then
		function DugisGuideViewer.onColorChange(id, r, g, b)
			DugisGuideUser[id] = {r, g, b}
			DugisArrowGlobal.lastAngle = -1000
			
			_G["DGV.ChkBox".._G[id]]:SetColor({r, g, b})
		end
	
		GUIUtils:MakeColorPicker(_G["DGV.ChkBox"..DGV_BAD_COLOR], DugisGuideUser.DGV_BAD_COLOR or DugisGuideViewer.defaultBadArrowColor , function(r, g, b)
			DugisGuideViewer.onColorChange("DGV_BAD_COLOR", r, g, b)
		end)
		
		GUIUtils:MakeColorPicker(_G["DGV.ChkBox"..DGV_MIDDLE_COLOR], DugisGuideUser.DGV_MIDDLE_COLOR or DugisGuideViewer.defaultMiddleArrowColor, function(r, g, b)
			DugisGuideViewer.onColorChange("DGV_MIDDLE_COLOR", r, g, b)
		end)	
		
		GUIUtils:MakeColorPicker(_G["DGV.ChkBox"..DGV_GOOD_COLOR], DugisGuideUser.DGV_GOOD_COLOR or DugisGuideViewer.defaultGoodArrowColor, function(r, g, b)
			DugisGuideViewer.onColorChange("DGV_GOOD_COLOR", r, g, b)
		end)
		
		GUIUtils:MakeColorPicker(_G["DGV.ChkBox"..DGV_EXACT_COLOR], DugisGuideUser.DGV_EXACT_COLOR or DugisGuideViewer.defaultExactArrowColor, function(r, g, b)
			DugisGuideViewer.onColorChange("DGV_EXACT_COLOR", r, g, b)
		end)
		
		GUIUtils:MakeColorPicker(_G["DGV.ChkBox"..DGV_QUESTING_AREA_COLOR], DugisGuideUser.DGV_QUESTING_AREA_COLOR or DugisGuideViewer.defaultQuestingAreaColor, function(r, g, b)
			DugisGuideViewer.onColorChange("DGV_QUESTING_AREA_COLOR", r, g, b)
		end)		
		
		GUIUtils:MakeColorPicker(_G["DGV.ChkBox"..DGV_WAY_SEGMENT_COLOR], DugisGuideUser.DGV_WAY_SEGMENT_COLOR or DugisGuideViewer.defaultWaySegmentColor(), function(r, g, b)
			DugisGuideViewer.onColorChange("DGV_WAY_SEGMENT_COLOR", r, g, b)
		end)
	end
	
	--Customize macro edit box
	if SettingsDB[DGV_TARGETBUTTONCUSTOM].category==category
		and(not DugisGuideViewer:GetDB(DGV_TARGETBUTTONCUSTOM, "module")
		or DugisGuideViewer:IsModuleRegistered(DugisGuideViewer:GetDB(DGV_TARGETBUTTONCUSTOM, "module")))
	then
		local macroFrame = _G["DGV.MacroFrame"]
		local textBox =  _G["DGV.InputBox"..DGV_TARGETBUTTONCUSTOM]
		local chkBox =  _G["DGV.ChkBox"..DGV_TARGETBUTTONCUSTOM]
		if not macroFrame then
			macroFrame = CreateFrame("Frame", "DGV.MacroFrame", frame)
			textBox = CreateFrame("EditBox", "DGV.InputBox"..DGV_TARGETBUTTONCUSTOM,  macroFrame, "InputBoxTemplate")
			chkBox = CreateFrame("CheckButton", "DGV.ChkBox"..DGV_TARGETBUTTONCUSTOM, frame, "InterfaceOptionsCheckButtonTemplate")
			if SettingsDB[DGV_TARGETBUTTONCUSTOM].indent then
				chkBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, top)
			else
				chkBox:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, top)
			end
			chkBox.Text:SetText(L[SettingsDB[DGV_TARGETBUTTONCUSTOM].text])
			chkBox:SetHitRectInsets(0, -200, 0, 0)
			chkBox:RegisterForClicks("LeftButtonDown")
			chkBox:SetScript("OnClick", function() DugisGuideViewer:SettingFrameChkOnClick (chkBox)	   end)
			chkBox:SetScript("OnEnter", function() DugisGuideViewer:SettingsTooltip_OnEnter(chkBox, event) end)
			chkBox:SetScript("OnLeave", function() DugisGuideViewer:SettingsTooltip_OnLeave(chkBox, event) end)

			top = top - chkBox:GetHeight()

			macroFrame:SetSize(260, 90)
			macroFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, top)
			DugisGuideViewer:SetFrameBackdrop(macroFrame, "Interface\\Tooltips\\UI-Tooltip-Background", "Interface\\Tooltips\\UI-Tooltip-Border", 5, 5, 5, 5)
			macroFrame:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b);
			macroFrame:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b);

			textBox:SetMultiLine(true)
			textBox:SetSize(260, 90)
			textBox:SetAutoFocus(false)
			textBox:ClearAllPoints( )
			textBox:SetPoint("TOPLEFT", macroFrame, "TOPLEFT", 10, -10)
			textBox:SetPoint("BOTTOMRIGHT", macroFrame, "BOTTOMRIGHT", -10, -10)
			textBox:SetMaxLetters(215)
			local filename, _, _ = textBox:GetFont()
			textBox:SetFont(filename, 11)
			textBox.Left:SetTexture(nil)
			textBox.Middle:SetTexture(nil)
			textBox.Right:SetTexture(nil)
			
			textBox:Show()
			
			top = top - macroFrame:GetHeight()
			
			local button = DugisGuideViewer:CreateButton("DGV_ApplyMacroButton", frame, "Apply", function() DugisGuideViewer.Modules.Target:CustomizeMacro() end)
			button:SetPoint("TOPLEFT", frame, "TOPLEFT", 40, top-3)
			local right = button:GetWidth()
			
			button = DugisGuideViewer:CreateButton("DGV_ResetMacroButton", frame, "Default", function() DugisGuideViewer.Modules.Target:ResetMacro() end)
			button:SetPoint("TOPLEFT", frame, "TOPLEFT", 40 + right, top-3)
			local right2 = button:GetWidth()
			
			button = DugisGuideViewer:CreateButton("DGV_ClearMacroButton", frame, "Clear", function() DugisGuideViewer.Modules.Target:ClearMacro() end)

			button:SetPoint("TOPLEFT", frame, "TOPLEFT", 40 + right + right2, top-3)

			
			top = top-3-button:GetHeight()
		end
		
		chkBox:SetChecked(SettingsDB[DGV_TARGETBUTTONCUSTOM].checked)
		textBox:SetText(self.chardb[DGV_TARGETBUTTONCUSTOM].editBox)
	end
	
	--Reset GA Blacklist Button
	if category=="Gear Set" and not DGV_ResetGABlacklistButton then
		local button = CreateFrame("Button", "DGV_ResetGABlacklistButton", frame, "UIPanelButtonTemplate")
		local btnText = L["Reset Ban List"]
		local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
		button:SetText(btnText)
		button:SetWidth(fontwidth + 30)
		button:SetHeight(22)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, top-3)
		top = top-3-button:GetHeight()
		button:RegisterForClicks("LeftButtonUP")
		button:SetScript("OnClick", 
			function() 
				if self.chardb.GA_Blacklist then
					wipe(self.chardb.GA_Blacklist)
					self.Modules.GearAdvisor.AutoEquipSmartSet(nil, true, true)
				end
			end)
	end
    
    
	if category == "Gear Set" then
        if not ignoredGearScores then
            topRightColumn = topRightColumn - 11
            local fontstring = frame:CreateFontString("ignoredGearScores","ARTWORK", "GameFontNormal")
            fontstring:SetText(L["|TInterface\\OptionsFrame\\UI-OptionsFrame-NewFeatureIcon:0:0:0:-1|tDisable suggestions if the highlighted\nsets are equipped:"])
            fontstring:SetPoint("TOPLEFT", frame, "TOPLEFT", 321, topRightColumn)
            fontstring:SetJustifyV("TOP")
            fontstring:SetJustifyH("LEFT")
            topRightColumn = topRightColumn - fontstring:GetStringHeight() - 5
        end

        DugisGuideViewer:UpdateSetsExcludingInSettings(frame)
	end
    
	if category == "Auto Mount" then
        if not DGV_MountIcon_ground then
        
            local function onMountIconEnter(node)
                local name = C_MountJournal.GetMountInfoByID(node.nodeData.data.mountId)
                local creatureDisplayID, descriptionText, sourceText, isSelfMount, mountType = C_MountJournal.GetMountInfoExtraByID(node.nodeData.data.mountId)
                
                if DugisGuideViewer:IsModuleLoaded("NPCJournalFrame") and DugisGuideViewer.NPCJournalFrame and name and creatureDisplayID then
                DugisGuideViewer.NPCJournalFrame:ShowGuideObjectPreview(name, creatureDisplayID)
                end
            end
            
            local function onMountIconLeave(node)
                if DugisGuideViewer:IsModuleLoaded("NPCJournalFrame") and DugisGuideViewer.NPCJournalFrame.hintFrame then
                    DugisGuideViewer.NPCJournalFrame.hintFrame.frame:Hide()   
                end
            end
        
            local function PrepareMountsForTree(requestedMountType)
                local result = {}
            
                local dontMountText = ""
  
            
                result[#result + 1] = {name = L["Don't mount"], icon = "Interface\\Buttons\\UI-GroupLoot-Pass-Up"
                , data = {mountType = requestedMountType, buttonType = "none"}}
                
                result[#result + 1] = {name = L["Random Favorite "] .. L[LuaUtils:CamelCase(requestedMountType)], icon = "Interface\\Icons\\achievement_guildperk_mountup"
                , data = {mountType = requestedMountType, buttonType = "auto"}}
            
            
                local firstContainer = {}
                local secondContainer = {}
                local unsortedTempFirstContainer = {}
                local unsortedTempSecondContainer = {}
            
                LuaUtils:foreach(C_MountJournal.GetMountIDs(), function(mountId)
                    local name, _, icon, _, isUsable, _, isFavorite, isFactionSpecific, faction, _, isCollected = C_MountJournal.GetMountInfoByID(mountId)
                    local _, _, _, _, mountType = C_MountJournal.GetMountInfoExtraByID(mountId)
                    
                                    
                    local _, _, _, _, isUsable, _, isFavorite, _, _, _, isCollected, mountID = C_MountJournal.GetMountInfoByID(mountId)
                    local _, _, _, _, mountTypeId = C_MountJournal.GetMountInfoExtraByID(mountId)       

                    local englishFaction, localizedFaction = UnitFactionGroup("player")
                    local rightFaction = (isFactionSpecific == false) or (englishFaction == "Alliance" and faction == 1) or (englishFaction == "Horde" and faction == 0)
                    
                    if isCollected and rightFaction then
                        --use requestedMountType for order purposes
                        local container = unsortedTempSecondContainer
                        if requestedMountType ==  DugisGuideViewer:GetNamedMountType(mountType) then
                            container = unsortedTempFirstContainer
                        end
                        
                        container[#container + 1] = {name = name, icon = icon, onMouseEnter = onMountIconEnter, onMouseLeave = onMountIconLeave,
                        data = {mountId = mountId, mountType = requestedMountType, buttonType = "mount-item"}}
                    end
                end)
                
                table.sort(unsortedTempFirstContainer, function(a,b) return a.name < b.name end)
                table.sort(unsortedTempSecondContainer, function(a,b) return a.name < b.name end)
                
                LuaUtils:foreach(unsortedTempFirstContainer, function(mount)
                    firstContainer[#firstContainer + 1] = mount
                end)                
                
                LuaUtils:foreach(unsortedTempSecondContainer, function(mount)
                    secondContainer[#secondContainer + 1] = mount
                end)
                
                LuaUtils:foreach(firstContainer, function(item)
                    result[#result + 1] = item
                end)
                
                LuaUtils:foreach(secondContainer, function(item)
                    result[#result + 1] = item
                end)
            
                return result
            end
            
            function DugisGuideViewer:UpdateMountSettingsIcons()
                LuaUtils:foreach({"ground", "flying", "aquatic"}, function(mountType)
            
                    local preferedMount =  DugisGuideViewer.chardb["prefered-auto-mount-"..mountType]
                 
                    if preferedMount == "auto" or preferedMount == nil then
                        _G["DGV_MountIcon_"..mountType]:SetNormalTexture("Interface\\Icons\\achievement_guildperk_mountup")
                        _G["DGV_MountIcon_"..mountType].Title:SetText(L["Random Favorite"])
                    elseif preferedMount == "none" then
                        _G["DGV_MountIcon_"..mountType]:SetNormalTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
                        _G["DGV_MountIcon_"..mountType].Title:SetText(L["None"])
                    else
                        local name, _, icon = C_MountJournal.GetMountInfoByID(preferedMount)
                        _G["DGV_MountIcon_"..mountType]:SetNormalTexture(icon)
                        _G["DGV_MountIcon_"..mountType].Title:SetText(name)
                    end
                
                end)
            end
            
            local mountListScrollFrame
            
            local function ShowMounts(mountType)
                local config = {
                      parent = frame
                    , name                    = "mountsList"
                    , data                    = PrepareMountsForTree(mountType)
                    , x                       = rightColumnX
                    , y                       = -10
                    , nodesOffsetY            = -10
                    , width                   = 420
                    , height                  = 308
                    , onNodeClick             = function(visualNode)
                            mountsListwrapper:Hide()
                            
                            if visualNode.nodeData.data.buttonType == "mount-item" then 
                                DugisGuideViewer.chardb["prefered-auto-mount-"..mountType] = visualNode.nodeData.data.mountId
                            elseif visualNode.nodeData.data.buttonType == "auto" then
                                DugisGuideViewer.chardb["prefered-auto-mount-"..mountType] = "auto"
                            elseif visualNode.nodeData.data.buttonType == "none" then
                                 DugisGuideViewer.chardb["prefered-auto-mount-"..mountType] = "none"
                            end
                            
                            DugisGuideViewer:UpdateMountSettingsIcons()
                            
                            mountListScrollFrame.scrollBar:Hide()
                      end
                    , iconSize                = 25
                    , nodeHeight              = 27
                    , noScrollMode            = false
                    , columnWidth             = 240
                    , nodeTextX               = 30
                    , scrollX                 = 560
                    , scrollY                 = -40
                    , scrollHeight            = 260
                    , nodeTextY               = -7 }
                
                mountListScrollFrame = SetScrollableTreeFrame(config)
                
                mountListScrollFrame.scrollBar:ClearAllPoints()
                mountListScrollFrame.frame:ClearAllPoints()
                
                mountListScrollFrame.scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -20, -40)
                mountListScrollFrame.frame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 100, -15)  
            end
        
            local function addText(y, name, title)
                local text = frame:CreateFontString(name, "ARTWORK", "GameFontHighlight")
                text:SetText(L[title])
                text:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 20, y)            
            end
            
            local function addIcon(y, mountType)
                local button = CreateFrame("Button", "DGV_MountIcon_"..mountType, frame, "DugisGuideTreeNodeTemplate")
                button.Title:SetText("None")
                button.Title:SetPoint("TOPLEFT", button, "TOPLEFT", 40, -10)
                button:SetWidth(150)
                button:SetHeight(32)
                button.normal:SetWidth(32)
                button.normal:SetHeight(32)
                button.highlight:SetWidth(32)
                button.highlight:SetHeight(32)
                button:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, y)
                button:Show()
                button:SetNormalTexture("Interface\\PaperDoll\\UI-Backpack-EmptySlot")
                button:SetScript("OnClick", function()
                    ShowMounts(mountType)
                end)
            end
            
            local space = -60
            local offset = -92
            local iconOffset = 3
            
            addText(space * 0 + offset, "flyingTitle", "Prefered mount in flyable areas")
            addIcon(space * 0 + offset - iconOffset, "flying")
            
            addText(space * 1 + offset,"groundTitle", "Prefered mount in non-flyable areas")
            addIcon(space * 1 + offset - iconOffset,"ground")
            
            addText(space * 2 + offset, "aquaticTitle", "Prefered mount in water")
            addIcon(space * 2 + offset - iconOffset, "aquatic")
            
            local button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
            local btnText = L["Key Bindings"]
            local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
            button:SetText(btnText)
            button:SetWidth(fontwidth + 20)
            button:SetHeight(22)
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, -rightColumnX)
            button:RegisterForClicks("LeftButtonUP")
            button:SetScript("OnClick", function() 
                GUIUtils:ShowBindings("Dugi Guides")
            end)
          
        end
        
        DugisGuideViewer:UpdateMountSettingsIcons()
	end
	
	--custom new profile
	if category=="Profiles" then
		local profileFrame = _G["DGV.CustomProfileFrame"]
		local textBox =  _G["DGV.InputBox"..DGV_PROFILECUSTOM]
		if not profileFrame then
			profileFrame = CreateFrame("Frame", "DGV.CustomProfileFrame", frame)
			profileFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 22, top)
			profileFrame:SetPoint("RIGHT")
			
			-- new profile
			textBox = CreateFrame("EditBox", "DGV.InputBox"..DGV_PROFILECUSTOM,  profileFrame, "InputBoxTemplate")
			local newButton = DugisGuideViewer:CreateButton("DGV_NewProfileButton", profileFrame, L["OK"], function() DugisGuideViewer.db:SetProfile(textBox:GetText()) end)
			textBox:SetMultiLine(false)
			textBox:SetSize(200, 15)
			textBox:SetAutoFocus(false)
			textBox:ClearAllPoints( )
			textBox:SetPoint("BOTTOMLEFT", 3, 0)
			newButton:SetPoint("LEFT", textBox, "RIGHT", 3)
			newButton:SetWidth(50)
			newButton:Show()
			textBox:Show()
			
			local dropdown_text = textBox:CreateFontString("DGV_CustomProfileFrameTitle", "ARTWORK", "GameFontHighlight")
			dropdown_text:SetText(L["New Profile"])
			dropdown_text:SetPoint("BOTTOMLEFT", textBox, "TOPLEFT", -5, 7)
			profileFrame:SetHeight(22+dropdown_text:GetHeight())
			
			top = top - 5 - profileFrame:GetHeight()
		end
		
		textBox:SetText(self.db.keys.profile)
	end
	
	--Weapon Preference Dropdown
	if SettingsDB[DGV_WEAPONPREF].category==category and not DGV_WeaponPreference then
		top = top - 24
		local dropdown = self:CreateDropdown("DGV_WeaponPreference", frame, SettingsDB[DGV_WEAPONPREF].text, DGV_WEAPONPREF, self.WeaponPreference_OnClick)
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, top)
		top = top-dropdown:GetHeight()
	end
	if DGV_WeaponPreference then
		LibDugi_UIDropDownMenu_Initialize(DGV_WeaponPreference, DGV_WeaponPreference.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_WeaponPreference, DugisGuideViewer:UserSetting(DGV_WEAPONPREF))
	end			
	
	--Smart Set Target Configuration Dropdown
	wipe(SettingsDB[DGV_GASMARTSETTARGET].options)
	local targetOptions = SettingsDB[DGV_GASMARTSETTARGET].options
	tinsert(targetOptions, "None")
	tinsert(targetOptions, "Active Talent Specialization")
	--tinsert(targetOptions, L["%s (PvP)"]:format("Active Talent Specialization"))
	if GetSpecialization(false, false, 2) then
		tinsert(targetOptions, "Inactive Talent Specialization")
		--tinsert(targetOptions, L["%s (PvP)"]:format("Inactive Talent Specialization"))
	end
	for specNum=1,GetNumSpecializations() do
		tinsert(targetOptions, (select(2,GetSpecializationInfo(specNum))))
		--tinsert(targetOptions, L["%s (PvP)"]:format(select(2,GetSpecializationInfo(specNum))))
	end
	if SettingsDB[DGV_GASMARTSETTARGET].category==category  and not DGV_GASmartSetTargetDropdown then
		top = top - 24
		local dropdown = self:CreateDropdown("DGV_GASmartSetTargetDropdown", frame, SettingsDB[DGV_GASMARTSETTARGET].text, DGV_GASMARTSETTARGET, self.GASmartSetTargetDropdown_OnClick)
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, top)
		top = top-dropdown:GetHeight()
	end
	if DGV_GASmartSetTargetDropdown then

		LibDugi_UIDropDownMenu_Initialize(DGV_GASmartSetTargetDropdown, DGV_GASmartSetTargetDropdown.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_GASmartSetTargetDropdown, DugisGuideViewer:UserSetting(DGV_GASMARTSETTARGET))
	end
	
	--Equip Set button

	if category=="Gear Set" and not DGV_EquipSetButton then
		local button = CreateFrame("Button", "DGV_EquipSetButton", frame, "UIPanelButtonTemplate")
		local btnText = L["Equip Set"]
		local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
		button:SetText(btnText)
		button:SetWidth(fontwidth + 30)
		button:SetHeight(22)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, top-3)
		top = top-3-button:GetHeight()
		--button:SetPoint("TOPLEFT", "DGV.ChkBox6", "BOTTOMLEFT", "0", "-3")
		button:RegisterForClicks("LeftButtonUP")
		button:SetScript("OnClick", function() DugisGuideViewer.Modules.GearAdvisor.AutoEquipSmartSet(nil, true, true) end)
	end
	
	--Stat Cap Level Difference Dropdown
	if SettingsDB[DGV_GASTATCAPLEVELDIFFERENCE].category==category
		and(not DugisGuideViewer:GetDB(DGV_GASTATCAPLEVELDIFFERENCE, "module")
		or DugisGuideViewer:IsModuleRegistered(DugisGuideViewer:GetDB(DGV_GASTATCAPLEVELDIFFERENCE, "module")))
		and not DGV_StatCapLevelDifferenceDropdown
	then
		top = top - 24
		local dropdown = self:CreateDropdown("DGV_StatCapLevelDifferenceDropdown", frame, "Stat Cap Level Difference", DGV_GASTATCAPLEVELDIFFERENCE, self.StatCapLevelDifferenceDropdown_OnClick)
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, top)
		top = top-dropdown:GetHeight()
	end
	if DGV_StatCapLevelDifferenceDropdown then
		LibDugi_UIDropDownMenu_Initialize(DGV_StatCapLevelDifferenceDropdown, DGV_StatCapLevelDifferenceDropdown.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_StatCapLevelDifferenceDropdown, DugisGuideViewer:UserSetting(DGV_GASTATCAPLEVELDIFFERENCE))
	end
	
	if SettingsDB[DGV_GAWINCRITERIACUSTOM].category==category and not DugisGearScoringLabel then
		top = top - 5
        local deltaY = 10
		local fontstring = frame:CreateFontString("DugisGearScoringLabel","ARTWORK", "GameFontNormalLarge")
		fontstring:SetText(SettingsDB[DGV_GAWINCRITERIACUSTOM].text)
		fontstring:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, -175 - deltaY, top)
		fontstring:SetJustifyV("TOP")
		top = top - fontstring:GetStringHeight() - 5
		
		local orderedListContainer = CreateFrame("Frame", "DGV_OrderedListContainer"..DGV_GAWINCRITERIACUSTOM, frame)
		orderedListContainer.optionIndex = DGV_GAWINCRITERIACUSTOM
		orderedListContainer:SetPoint("TOPLEFT", frame, "TOPLEFT", 27, -195 - deltaY, top)
		orderedListContainer:SetPoint("RIGHT", frame, "RIGHT", -10, -195)
		orderedListContainer:SetFrameLevel(1)
		local lastListItem
		for i=1,5+GetNumSpecializations()*2 do
			local listItem = CreateFrame("Frame", nil, orderedListContainer, "DugisOrderedListItemTemplate")
			listItem:SetID(i)
			if lastListItem then
				listItem:SetPoint("TOP", lastListItem, "BOTTOM")
			else
				listItem:SetPoint("TOP", orderedListContainer)
			end
			lastListItem = listItem
		end
		local lastShown = DugisGuideViewer:UpdateOrderedListView(DGV_GAWINCRITERIACUSTOM, orderedListContainer:GetChildren())
		top = top - orderedListContainer:GetHeight() - 5
		
		local addString = frame:CreateFontString("DugisGearScoringAddLabel","ARTWORK", "GameFontNormal")
		addString:SetText(L["Add"])
		addString:SetWidth(addString:GetStringWidth())
		addString:SetHeight(40)
		addString:SetPoint("TOPLEFT", orderedListContainer, "BOTTOMLEFT")
		
		local dropdown = self:CreateDropdown(
				"DugisGearScoringDropdown", 
				frame, 
				nil, 
				nil, 
				function(button)
					local options = DugisGuideViewer.chardb[DGV_GAWINCRITERIACUSTOM].options
					if not tContains(options, button.value) then
						local indexOfFalse = DugisGuideViewer.tIndexOfFirst(options, false)
						if indexOfFalse then
							options[indexOfFalse] = button.value
						else
							tinsert(options, button.value)
						end
						DugisGuideViewer:UpdateOrderedListView(DGV_GAWINCRITERIACUSTOM, orderedListContainer:GetChildren())
					end
				end, 
				function() 
					return GetGearScoringCriteria() 
				end)
		dropdown:SetPoint("LEFT", addString, "RIGHT", -10)
	end
    
    local function GetSelectedClassIdentifier()
        local result = ""
        LuaUtils:foreach(DugisGuideViewer.defaultLevelingSpec, function(info, key)
            if DugisGuideViewer.Modules.GearAdvisor.selectedClassIndex == info.orderIndex then
                result = key 
            end
        end)
        return result
    end
        
    local function TryToSetCurrentClass()
        local localizedClass, englishClass, classIndex = UnitClass("player")
        local classIndex = 1
        LuaUtils:foreach(DugisGuideViewer.defaultLevelingSpec, function(info, key)
            if key == englishClass then
                classIndex = info.orderIndex
            end
        end)
        
        LibDugi_UIDropDownMenu_Initialize(DugisGearWeightsClassDropdown, DugisGearWeightsClassDropdown.initFunc)
        LibDugi_UIDropDownMenu_SetSelectedID(DugisGearWeightsClassDropdown, classIndex)  
        DugisGuideViewer.Modules.GearAdvisor.selectedClassIndex = classIndex 
    end         
        
    local function TryToSetCurrentSpecialization()
        local localizedClass, englishClass, classIndex = UnitClass("player")
        local currentSpec = GetSpecialization()
        if currentSpec == nil or GetSelectedClassIdentifier() ~= englishClass then
            currentSpec = 1
        end
        
        LibDugi_UIDropDownMenu_Initialize(DugisGearWeightsSpecializationDropdown, DugisGearWeightsSpecializationDropdown.initFunc)
        LibDugi_UIDropDownMenu_SetSelectedID(DugisGearWeightsSpecializationDropdown, currentSpec)  
             
        DugisGuideViewer.Modules.GearAdvisor.selectedSpecIndex = currentSpec
    end 
    
    
    local function UpdateSettingsSearchHeight()
        local _max = SettingsSearchScroll.frame.wrapper.height
        
        if _max < 1 then
            _max = 1
        end
        
        SettingsSearchScroll.scrollBar:SetMinMaxValues(1, _max) 
    end
        
    if category == "Search Locations" and not DugisGearWeightsClassDropdownLabel then
        if not SettingsSearchScroll then
            SettingsSearchScroll = GUIUtils:CreateScrollFrame(frame)
                        
            SettingsSearchScroll.frame:SetWidth(388) 
            SettingsSearchScroll.scrollBar:SetPoint("TOPLEFT", parent, "TOPLEFT", 570, -52)
            SettingsSearchScroll.scrollBar:SetWidth(30)
            SettingsSearchScroll.scrollBar:Hide()
            
            
            
            SettingsSearchScroll.frame:EnableMouseWheel(true)
            SettingsSearchScroll.frame:SetScript("OnMouseWheel", function(self, delta)
                SettingsSearchScroll.scrollBar:SetValue(SettingsSearchScroll.scrollBar:GetValue() - delta * 24)  
            end)     
            
        end
        
        
        if not SettingsSearch_SearchBox then
            CreateFrame("EditBox", "SettingsSearch_SearchBox", frame, "InputBoxTemplate")
        end
        
        SettingsSearch_SearchBox:SetAutoFocus(false)
        SettingsSearch_SearchBox:SetSize("150", "25")
        SettingsSearch_SearchBox:SetPoint("TOPLEFT", frame, "TOPLEFT", 180, -10)
        SettingsSearch_SearchBox:SetScript("OnLoad", function(self)  end)
        SettingsSearch_SearchBox:SetScript("OnEscapePressed", function(self) self:SetAutoFocus(false) self:ClearFocus() end)
        SettingsSearch_SearchBox:SetScript("OnTextChanged", function() 
            if SettingsSearch_SearchBox:GetNumLetters() > 1 then
                local nodes = DugisGuideViewer:GetLocationsAndPortalsByText(SettingsSearch_SearchBox:GetText())
                
                --Passing data to tree frame       
                GUIUtils:SetTreeData(SettingsSearchScroll.frame, nil, "SettingMenu", nodes, nil, nil, function(self)
                    UpdateSettingsSearchHeight()

                end, function(self)
                    
                    DugisGuideViewer:RemoveAllWaypoints()
                    local data = self.nodeData.data
                    if data.isPortal == true then
                        DugisGuideViewer:AddCustomWaypoint(data.x, data.y, L["Portal "] .. data.mapName, data.mapId, data.f)      
                    else
                        local mapId = DugisGuideViewer:GetMapIDFromName(data.zone)
                        DugisGuideViewer:AddCustomWaypoint(data.x / 100, data.y / 100, data.subzoneName, mapId, 0)      
                    end
					SettingsSearch_SearchBox:SetAutoFocus(false)
					SettingsSearch_SearchBox:ClearFocus()
                end)  
                
                UpdateSettingsSearchHeight()
                SettingsSearchScroll.frame.wrapper:UpdateTreeVisualization()
                
                if  SettingsSearchScroll.frame.wrapper.height > 200 then
                    SettingsSearchScroll.scrollBar:Show()

                else
                    SettingsSearchScroll.scrollBar:Hide()
                end
                 
                SettingsSearchScroll.scrollBar:SetPoint("TOPLEFT", SettingsSearchScroll.scrollBar:GetParent(), "TOPLEFT", 562, -17)

                SettingsSearchScroll.frame.wrapper:SetWidth(423)
                SettingsSearchScroll.frame:SetWidth(608)
                SettingsSearchScroll.frame.wrapper:SetHeight(64)
 
                SettingsSearchScroll.frame:SetHeight(291)
                SettingsSearchScroll.scrollBar:SetHeight(256)
                SettingsSearchScroll.scrollBar:SetFrameLevel(100)
                
                SettingsSearchScroll.frame.content =SettingsSearchScroll.frame.wrapper
                SettingsSearchScroll.frame:SetScrollChild(SettingsSearchScroll.frame.wrapper)  
            else
            end
        end)
        SettingsSearch_SearchBox:Show()
        
          
    end
    
    if category == "Gear Scoring" and not DugisGearWeightsClassDropdownLabel then
		top = -70

		local classDropDownLabel = frame:CreateFontString("DugisGearWeightsClassDropdownLabel","ARTWORK", "GameFontNormal")
		classDropDownLabel:SetText(L["Class"])
		classDropDownLabel:SetWidth(classDropDownLabel:GetStringWidth())
		classDropDownLabel:SetHeight(40)
		classDropDownLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, top)
        
		local dropdown = self:CreateDropdown(
				"DugisGearWeightsClassDropdown", 
				frame, 
				nil, 
				nil, 
				function(button)
                    LibDugi_UIDropDownMenu_Initialize(DugisGearWeightsClassDropdown, DugisGearWeightsClassDropdown.initFunc)
                    LibDugi_UIDropDownMenu_SetSelectedValue(DugisGearWeightsClassDropdown, button.value)
                    DugisGuideViewer.Modules.GearAdvisor.selectedClassIndex = LibDugi_UIDropDownMenu_GetSelectedID(DugisGearWeightsClassDropdown)
                    TryToSetCurrentSpecialization()
                    DugisGuideViewer.Modules.GearAdvisor:UpdateWeightsTextboxes()
				end, 
				function() 
                    local classesForDropDown = 
                    {
                        {["text"] = "Deathknight",["value"] = "Deathknight"} ,
                        {["text"] = "Monk" ,      ["value"] = "Monk"   },
                        {["text"] = "Warrior" ,   ["value"] = "Warrior" },
                        {["text"] = "Paladin" ,   ["value"] = "Paladin" },
                        {["text"] = "Druid" ,     ["value"] = "Druid"  },
                        {["text"] = "Rogue" ,     ["value"] = "Rogue"  },
                        {["text"] = "Shaman" ,    ["value"] = "Shaman" },
                        {["text"] = "Hunter" ,    ["value"] = "Hunter" },
                        {["text"] = "Mage" ,      ["value"] = "Mage"   },
                        {["text"] = "Priest" ,    ["value"] = "Priest" },
                        {["text"] = "Warlock" ,    ["value"] = "Warlock" },
						{["text"] = "Demon Hunter" ,     ["value"] = "DemonHunter"  },
                    }                    
					return classesForDropDown

				end)
		dropdown:SetPoint("LEFT", classDropDownLabel, "RIGHT", -10)
        
        TryToSetCurrentClass()        
        
        top = top - 40       

        local specizlizationDropDownLabel = frame:CreateFontString("DugisGearWeightsSpecializationDropdownLabel","ARTWORK", "GameFontNormal")
		specizlizationDropDownLabel:SetText(L["Specialization"])
		specizlizationDropDownLabel:SetWidth(specizlizationDropDownLabel:GetStringWidth())
		specizlizationDropDownLabel:SetHeight(40)
		specizlizationDropDownLabel:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, top)
        
        function IsSpecializationAvaliable(specIndex)
            return DugisGuideViewer.Modules.GearAdvisor:SpecExists(specIndex)
        end
        
		dropdown = self:CreateDropdown(
            "DugisGearWeightsSpecializationDropdown", 
            frame, 
            nil, 
            nil, 
            function(button)
                LibDugi_UIDropDownMenu_SetSelectedValue(DugisGearWeightsSpecializationDropdown, button.value)
                DugisGuideViewer.Modules.GearAdvisor.selectedSpecIndex = LibDugi_UIDropDownMenu_GetSelectedID(DugisGearWeightsSpecializationDropdown)
                DugisGuideViewer.Modules.GearAdvisor:UpdateWeightsTextboxes()
            end, 
            function() 
                local specializationNames = {}
                
                local class = DugisGuideViewer.Modules.GearAdvisor:GetCurrentSelectedClassIdentifier()
                local specializations = DugisGuideViewer.Modules.GearAdvisor.classIdentifier2SpecializationsMap[class]                
                LuaUtils:foreach(specializations, function(specialization)
                    local name =  specialization["name"]
                    specializationNames[#specializationNames + 1] = name
                end)
                
                LibDugi_UIDropDownMenu_SetWidth(DugisGearWeightsSpecializationDropdown, 100,0)
                return specializationNames
		end)
        
		dropdown:SetPoint("LEFT", specizlizationDropDownLabel, "RIGHT", -10)        
          
        top = top - 40
        
        local weightsTop = 10
        
        local scrollFrame = GUIUtils:CreateScrollFrame(frame)
        
		scrollFrame.frame:EnableMouseWheel(true)
		scrollFrame.frame:SetScript("OnMouseWheel", function(self, delta)
			DugisGuideViewer.Modules.GearAdvisor.scrollFrame.scrollBar:SetValue(DugisGuideViewer.Modules.GearAdvisor.scrollFrame.scrollBar:GetValue() - delta * 24)  
		end)          
        
        scrollFrame.frame:SetPoint("TOPLEFT", frame,"TOPLEFT", rightColumnX, -15)
        
        scrollFrame.scrollBar:SetHeight(250)
        scrollFrame.scrollBar:ClearAllPoints()
        scrollFrame.scrollBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 552, -27)
        
        local content = CreateFrame("Frame", nil, scrollFrame.frame)
        content:ClearAllPoints()
        content:SetSize(528, 440)
        scrollFrame.frame:SetHeight(273)
        
        local texture = content:CreateTexture()
        
        content:Show()
        
        LuaUtils:loop(28, function(item)
            local weightLabel = content:CreateFontString("GA_TextWeight"..item,"ARTWORK", "GameFontNormal")
            weightLabel:SetText(L["Weight"]..item)
            weightLabel:SetWidth(150)
            weightLabel:SetHeight(40)
            weightLabel:ClearAllPoints( )
            weightLabel:SetPoint("TOPLEFT", content, "TOPLEFT", 6, weightsTop)
            weightLabel:SetJustifyH("LEFT")
            weightLabel:Hide()
        
            -- new profile
            local textBox = CreateFrame("EditBox", "GA_EditBoxWeight"..item,  content, "InputBoxTemplate")
            textBox:SetMultiLine(false)
            textBox:SetSize(50, 15)
            textBox:SetAutoFocus(false)
            textBox:ClearAllPoints( )
            textBox:SetPoint("TOPLEFT",weightLabel,"TOPLEFT", 160, -12)
            textBox:Hide()
            textBox:SetText("0.4") 
            weightsTop = weightsTop - 22            
        end)
        
        scrollFrame.frame.content = content
		scrollFrame.frame:SetScrollChild(content) 
      
        DugisGuideViewer.Modules.GearAdvisor.scrollFrame = scrollFrame
      
		local button = CreateFrame("Button", "GA_ResetWeightsButton", frame, "UIPanelButtonTemplate")
		local btnText = L["Reset Scores"]
		local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
		button:SetText(btnText)
		button:SetWidth(fontwidth + 30)
		button:SetHeight(22)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, top-3)
		button:RegisterForClicks("LeftButtonUP")
		button:SetScript("OnClick", function() 
            DugisGuideViewer.Modules.GearAdvisor:ResetWeights()
		end)		
        
        button = CreateFrame("Button", "GA_ApplyWeightsButton", frame, "UIPanelButtonTemplate")
		local btnText = L["Apply"]
		local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
		button:SetText(btnText)
		button:SetWidth(fontwidth + 30)
		button:SetHeight(22)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 146, top-3)
		top = top-3-button:GetHeight()
		button:RegisterForClicks("LeftButtonUP")
		button:SetScript("OnClick", function() 
            DugisGuideViewer.Modules.GearAdvisor:ApplyWeights()
			DGV.GetCurrentBestInSlot_cache = {}
		end)

		local button = CreateFrame("Button", "GA_ImportWeightsButton", frame, "UIPanelButtonTemplate")
		local btnText = L["Import Scores"]
		local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
		button:SetText(btnText)
		button:SetWidth(fontwidth + 20)
		button:SetHeight(22)
		button:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -22, 13)
		button:RegisterForClicks("LeftButtonUP")
        
        StaticPopupDialogs["SCORES_IMPORT_DIALOG"] = {
            text = L["Paste below scores from another addon and press Import."],
            button1 = L["Import"],
            button2 = L["Cancel"],
            editBoxWidth = 400,
            OnShow = function(self)
                local textEditor = AceGUI:Create("MultiLineEditBox")
                textEditor.frame:SetParent(self)
                textEditor.editBox:SetCountInvisibleLetters(true)
                textEditor.frame:SetPoint("TOPLEFT", self, "TOPLEFT", 50, -40)
                textEditor.frame:SetWidth(370)
                textEditor.frame:SetHeight(170) 
                textEditor:SetFocus()
                self:SetHeight(320) 
                textEditor.frame:Show()
                textEditor.button:Hide()
                textEditor.label:Hide()
                
                self.insertedFrame = textEditor.frame
                self.textEditorObject = textEditor
                DugisGuideViewer:SetFrameBackdrop(self,  "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", DugisGuideViewer:GetBorderPath(), 10, 4, 12, 5)
                
                self:ClearAllPoints()
                self:SetParent(GA_ImportWeightsButton:GetParent())
                self:SetPoint("TOPLEFT", GA_ImportWeightsButton:GetParent(), "TOPLEFT", 70, -40)
                self:SetFrameStrata("TOOLTIP")
                self:SetFrameLevel(1000)
            end,
            OnHide = function()
            end,
            OnAccept = function(self)
                local text = self.textEditorObject:GetText()
                DugisGuideViewer.Modules.GearAdvisor:ImportScoresFromText(text)
            end,
            timeout = 0,
            whileDead = true,
            hideOnEscape = true,
            preferredIndex = 3,
        }

		button:SetScript("OnClick", function() 
            StaticPopup_Show ("SCORES_IMPORT_DIALOG")
		end)	 
        
	end
    
    if category == "Gear Scoring" then
        if DugisGearWeightsClassDropdownLabel then
            TryToSetCurrentClass()
            TryToSetCurrentSpecialization()
            DugisGuideViewer.Modules.GearAdvisor:UpdateWeightsTextboxes()    
        end
        
        StaticPopup_Hide("SCORES_IMPORT_DIALOG")
    end
    
    
		
	--Disable Ant Trail option

	if DugisGuideViewer.carboniteloaded and SettingsDB[DGV_SHOWANTS].category==category then
		local ChkBox = _G["DGV.ChkBox"..DGV_SHOWANTS]

		--ChkBox:SetChecked(false)
		ChkBox:Disable()
		ChkBox.Text:SetTextColor(0.5, 0.5, 0.5)
	
	elseif SettingsDB[DGV_CARBONITEARROW].category==category then
		local ChkBox = _G["DGV.ChkBox"..DGV_CARBONITEARROW]

		--ChkBox:SetChecked(false)
		ChkBox:Disable()
		ChkBox.Text:SetTextColor(0.5, 0.5, 0.5) 	
	end

	if not DugisGuideViewer.tomtomloaded and SettingsDB[DGV_TOMTOMARROW].category==category  then
		local ChkBox = _G["DGV.ChkBox"..DGV_TOMTOMARROW]		

		--ChkBox:SetChecked(false)
		ChkBox:Disable() 
		ChkBox.Text:SetTextColor(0.5, 0.5, 0.5) 		
	end
	
	if DugisGuideViewer.tomtomloaded and SettingsDB[DGV_TOMTOMEMULATION].category==category  then
		local ChkBox = _G["DGV.ChkBox"..DGV_TOMTOMEMULATION]		

		--ChkBox:SetChecked(false)
		ChkBox:Disable() 
		ChkBox.Text:SetTextColor(0.5, 0.5, 0.5) 		
	end	
	
	if (DugisGuideViewer.tomtomloaded or DugisGuideViewer.mapsterloaded) and SettingsDB[DGV_DISPLAYMAPCOORDINATES].category==category  then
		local ChkBox = _G["DGV.ChkBox"..DGV_DISPLAYMAPCOORDINATES]		

		ChkBox:SetChecked(false)
		ChkBox:Disable() 
		ChkBox.Text:SetTextColor(0.5, 0.5, 0.5) 		
	end	
	
	if DugisGuideViewer.mapsterloaded and SettingsDB[DGV_REMOVEMAPFOG].category==category  then
		local ChkBox = _G["DGV.ChkBox"..DGV_REMOVEMAPFOG]		

		ChkBox:SetChecked(false)
		ChkBox:Disable() 
		ChkBox.Text:SetTextColor(0.5, 0.5, 0.5) 		
	end		

	if ((DugisGuideViewer.carboniteloaded and Nx.Quest) or DugisGuideViewer.sexymaploaded or DugisGuideViewer.nuiloaded or DugisGuideViewer.elvuiloaded or DugisGuideViewer.tukuiloaded or DugisGuideViewer.shestakuiloaded or DugisGuideViewer.dominosquestloaded or DugisGuideViewer.eskaquestloaded) and SettingsDB[DGV_MOVEWATCHFRAME].category==category then
		DugisGuideViewer:SetDB(false, DGV_MOVEWATCHFRAME)
		Disable(_G["DGV.ChkBox"..DGV_MOVEWATCHFRAME]) 		

		DugisGuideViewer:SetDB(false, DGV_DISABLEWATCHFRAMEMOD)
		Disable(_G["DGV.ChkBox"..DGV_DISABLEWATCHFRAMEMOD])
	elseif SettingsDB[DGV_MOVEWATCHFRAME].category==category and not self:UserSetting(DGV_MOVEWATCHFRAME) then
		Disable(_G["DGV.ChkBox"..DGV_DISABLEWATCHFRAMEMOD])
	elseif SettingsDB[DGV_MOVEWATCHFRAME].category==category and self:UserSetting(DGV_MOVEWATCHFRAME) then
		Enable(_G["DGV.ChkBox"..DGV_DISABLEWATCHFRAMEMOD])		
	end
	
	if ((DugisGuideViewer.carboniteloaded and Nx.Quest) or DugisGuideViewer.sexymaploaded or DugisGuideViewer.nuiloaded or DugisGuideViewer.elvuiloaded or DugisGuideViewer.tukuiloaded or DugisGuideViewer.shestakuiloaded or DugisGuideViewer.dominosquestloaded or DugisGuideViewer.eskaquestloaded) and SettingsDB[DGV_WATCHFRAMEBORDER].category==category  then
		local ChkBox = _G["DGV.ChkBox"..DGV_WATCHFRAMEBORDER]		

		ChkBox:SetChecked(false)
		ChkBox:Disable() 
		ChkBox.Text:SetTextColor(0.5, 0.5, 0.5) 		
	end		
	
	if SettingsDB[DGV_ANCHOREDSMALLFRAME].category==category then
		local ChkBox = _G["DGV.ChkBox"..DGV_ANCHOREDSMALLFRAME]
		if not ((DugisGuideViewer.carboniteloaded and Nx.Quest) or DugisGuideViewer.sexymaploaded or DugisGuideViewer.nuiloaded or DugisGuideViewer.elvuiloaded or DugisGuideViewer.tukuiloaded or DugisGuideViewer.shestakuiloaded or DugisGuideViewer.dominosquestloaded or DugisGuideViewer.eskaquestloaded)
		then
			Enable(ChkBox)
		else
			Disable(ChkBox)
		end
	end
	
	local ChkBoxes = {
		 DGV_ALWAYS_SHOW_STANDARD_PROMPT_GEAR
		,DGV_ALWAYS_SHOW_STANDARD_PROMPT_GUIDE
		,DGV_ENABLED_GEAR_NOTIFICATIONS
		,DGV_ENABLED_GUIDE_NOTIFICATIONS
		,DGV_ENABLED_JOURNAL_NOTIFICATIONS
		,DGV_USE_NOTIFICATIONS_MARK
	}
	
	LuaUtils:foreach(ChkBoxes, function(checkboxId)
		if SettingsDB[checkboxId].category == category then
			local chkBox = _G["DGV.ChkBox"..checkboxId]
			if DugisGuideViewer:NotificationsEnabled() then
				Enable(chkBox)
			else
				Disable(chkBox, true)
			end
		end
	end)
	
	if not DugisGuideViewer:UserSetting(DGV_AUTOREPAIR) then
		DugisGuideViewer:SetDB(false, DGV_AUTOREPAIRGUILD)
		local Chk = _G["DGV.ChkBox"..DGV_AUTOREPAIRGUILD]
		Disable(Chk)
	else
		local Chk = _G["DGV.ChkBox"..DGV_AUTOREPAIRGUILD]
		Enable(Chk)
	end
	
	--Reset Frames Position Button
	if category=="Frames" and not DGV_ResetFramesButton then

		local button = CreateFrame("Button", "DGV_ResetFramesButton", frame, "UIPanelButtonTemplate")
		local btnText = L["Reset Frames Position"]
		local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
		button:SetText(btnText)
		button:SetWidth(fontwidth + 30)
		button:SetHeight(22)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, top-3)
		top = top-3-button:GetHeight()
		--button:SetPoint("TOPLEFT", "DGV.ChkBox6", "BOTTOMLEFT", "0", "-3")
		button:RegisterForClicks("LeftButtonUP")
		button:SetScript("OnClick", function() DugisGuideViewer:InitFramePositions() end)
	end	
    
	--Reset Tracking Points
	if category=="Maps" and not DGV_ResetTrackingPointsButton and DugisGuideViewer:IsModuleRegistered("Guides") then

		local button = CreateFrame("Button", "DGV_ResetTrackingPointsButton", frame, "UIPanelButtonTemplate")
		local btnText = L["Reset Tracking Points"]
		local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
		button:SetText(btnText)
		button:SetWidth(fontwidth + 30)
		button:SetHeight(22)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, top-3)
		top = top-3-button:GetHeight()
		--button:SetPoint("TOPLEFT", "DGV.ChkBox6", "BOTTOMLEFT", "0", "-3")
		button:RegisterForClicks("LeftButtonUP")
		button:SetScript("OnClick", function() 
            DugisGuideUser.excludedTrackingPoints = {}
            WorldMapFrame_UpdateMap()
        end)
	end
	
	--Reset Profile Button
	if category=="Profiles" and not DGV_ResetProfileButton then
		local button = CreateFrame("Button", "DGV_ResetProfileButton", frame, "UIPanelButtonTemplate")
		local btnText = L["Reset Profile"]
		local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
		button:SetText(btnText)
		button:SetWidth(fontwidth + 30)
		button:SetHeight(22)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", columnPaddingLeft, top-3)
		top = top-3-button:GetHeight()
		--button:SetPoint("TOPLEFT", "DGV.ChkBox6", "BOTTOMLEFT", "0", "-3")
		button:RegisterForClicks("LeftButtonUP")
		button:SetScript("OnClick", function() 
			DugisGuideViewer.db:ResetProfile()
		end)
	end
	
	--Memory settings Apply button
	if category=="Other" and not DGV_MemoryApplyButton and DugisGuideViewer:IsModuleRegistered("Guides") then
		local button = CreateFrame("Button", "DGV_MemoryApplyButton", frame, "UIPanelButtonTemplate")
		local btnText = L["Apply Memory Settings"]
		local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
		button:SetText(btnText)
		button:SetWidth(fontwidth + 30)
		button:SetHeight(22)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX + columnPaddingLeft, topRightColumn-3)
		topRightColumn = topRightColumn-3-button:GetHeight()
		button:RegisterForClicks("LeftButtonUP")
		button:SetScript("OnClick", function() DugisGuideViewer:ReloadModules() end)
	end
	
	--[[--Memory settings Garbage Collect
	if category=="Memory" then
		local button = CreateFrame("Button", "DGV_CollectGarbageButton", frame, "UIPanelButtonTemplate")
		local btnText = L["Collect Garbage"]
		local fontwidth = DugisGuideViewer:GetFontWidth(btnText, "GameFontHighlight")
		button:SetText(btnText)
		button:SetWidth(fontwidth + 30)
		button:SetHeight(22)
		button:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, top-3)
		top = top-3-button:GetHeight()
		button:RegisterForClicks("LeftButtonUP")
		button:SetScript("OnClick", function() collectgarbage() end)
	end]]

	top = top - 24
	--Guide Suggest Difficulty Dropdown
	if SettingsDB[DGV_GUIDEDIFFICULTY].category==category
		and(not DugisGuideViewer:GetDB(DGV_GUIDEDIFFICULTY, "module")
		or DugisGuideViewer:IsModuleRegistered(DugisGuideViewer:GetDB(DGV_GUIDEDIFFICULTY, "module")))
		and not DGV_GuideSuggestDropdown
	then
		local dropdown = self:CreateDropdown("DGV_GuideSuggestDropdown", frame, "Leveling Mode", DGV_GUIDEDIFFICULTY, self.GuideSuggestDropDown_OnClick)
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, top)
		--top = top-22-dropdown:GetHeight()
	end
	if DGV_GuideSuggestDropdown then
		LibDugi_UIDropDownMenu_Initialize(DGV_GuideSuggestDropdown, DGV_GuideSuggestDropdown.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_GuideSuggestDropdown, DugisGuideViewer:UserSetting(DGV_GUIDEDIFFICULTY))
	end
	
	--Status Frame Effect Dropdown
	if SettingsDB[DGV_SMALLFRAMETRANSITION].category==category 
		and(not DugisGuideViewer:GetDB(DGV_SMALLFRAMETRANSITION, "module") 
		or DugisGuideViewer:IsModuleRegistered(DugisGuideViewer:GetDB(DGV_SMALLFRAMETRANSITION, "module")))
		and not DGV_StatusFrameEffectDropdown
	then
		topRightColumn = topRightColumn-27
		local dropdown = self:CreateDropdown("DGV_StatusFrameEffectDropdown", frame, "Small Frame Effect", DGV_SMALLFRAMETRANSITION, self.StatusFrameEffectDropDown_OnClick)
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX, topRightColumn)
	end
	if DGV_StatusFrameEffectDropdown then
		LibDugi_UIDropDownMenu_Initialize(DGV_StatusFrameEffectDropdown, DGV_StatusFrameEffectDropdown.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_StatusFrameEffectDropdown, DugisGuideViewer:UserSetting(DGV_SMALLFRAMETRANSITION))
	end	
    
	if SettingsDB[DGV_MAIN_FRAME_BACKGROUND].category==category 
		and not DGV_Main_Frame_Background_Dropdown
	then
		local dropdown = self:CreateDropdown("DGV_Main_Frame_Background_Dropdown", frame, L["Large Frame Background"]
        , DGV_MAIN_FRAME_BACKGROUND, self.MainFrameBackgroundDropDown_OnClick)
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 333, -190)
	end
    
	if SettingsDB[DGV_ROUTE_STYLE].category==category 
		and not DGV_route_style
	then
		local dropdown = self:CreateDropdown("DGV_route_style", frame, L["Ant Trail"]
        , DGV_ROUTE_STYLE, self.RouteStyleDropDown_OnClick)
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -297)
	end

	--Large Frame Border  Dropdown
	if SettingsDB[DGV_LARGEFRAMEBORDER].category==category  and not DGV_LargeFrameBorderDropdown then
		local dropdown = self:CreateDropdown("DGV_LargeFrameBorderDropdown", frame, "Borders", DGV_LARGEFRAMEBORDER, self.LargeFrameBorderDropdown_OnClick)
		local left = 3
        
        if not DugisGuideViewer:IsModuleRegistered("SmallFrame") then
            topRightColumn = topRightColumn - 40
        end
        
		if DGV_StatusFrameEffectDropdownTitle then left = DGV_StatusFrameEffectDropdownTitle:GetWidth() + 20 end
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX + left, topRightColumn)
	end
	if DGV_LargeFrameBorderDropdown then
		LibDugi_UIDropDownMenu_Initialize(DGV_LargeFrameBorderDropdown, DGV_LargeFrameBorderDropdown.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_LargeFrameBorderDropdown, DugisGuideViewer:UserSetting(DGV_LARGEFRAMEBORDER))
	end
	
	--GPS Border  Dropdown
	if SettingsDB[DGV_GPS_BORDER].category==category  and not DGV_gps_border then
		local dropdown = self:CreateDropdown("DGV_gps_border", frame, "Zone Map Border", DGV_GPS_BORDER, self.GPSBorderDropdown_OnClick)
		local left = 3
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", left, top)
	end
	if DGV_gps_border then
		LibDugi_UIDropDownMenu_Initialize(DGV_gps_border, DGV_gps_border.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_gps_border, DugisGuideViewer:UserSetting(DGV_GPS_BORDER))
	end
	
	--Step Complete Sound Dropdown
	if SettingsDB[DGV_STEPCOMPLETESOUND].category==category
		and(not DugisGuideViewer:GetDB(DGV_STEPCOMPLETESOUND, "module")
		or DugisGuideViewer:IsModuleRegistered(DugisGuideViewer:GetDB(DGV_STEPCOMPLETESOUND, "module")))
		and not DGV_StepCompleteSoundDropdown
	then
		local dropdown = self:CreateDropdown("DGV_StepCompleteSoundDropdown", frame, "Step Complete Sound", DGV_STEPCOMPLETESOUND, self.StepCompleteSoundDropdown_OnClick)
		local left = 3
		if DGV_GuideSuggestDropdownTitle then left = DGV_GuideSuggestDropdownTitle:GetWidth() + 20 end
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", left, top)
		top = top-22-dropdown:GetHeight()
	elseif SettingsDB[DGV_STEPCOMPLETESOUND].category==category and DGV_GuideSuggestDropdown then
		top = top-22-DGV_GuideSuggestDropdown:GetHeight()
	end
	if DGV_StepCompleteSoundDropdown then
		LibDugi_UIDropDownMenu_Initialize(DGV_StepCompleteSoundDropdown, DGV_StepCompleteSoundDropdown.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_StepCompleteSoundDropdown, DugisGuideViewer:UserSetting(DGV_STEPCOMPLETESOUND))
	end
	
	--Flightmaster Handling Dropdown
	if SettingsDB[DGV_TAXIFLIGHTMASTERS].category==category and not DGV_TaxiFlightmasterDropdown then
		local dropdown = self:CreateDropdown("DGV_TaxiFlightmasterDropdown", frame, "Use Flightmasters", DGV_TAXIFLIGHTMASTERS, self.TaxiFlightmasterDropdown_OnClick)
		local left = 3
		if DGV_AntColorDropdownTitle then left = DGV_AntColorDropdownTitle:GetWidth() + 20 end
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", left, top)
		top = top-22-dropdown:GetHeight()
	end
	if DGV_TaxiFlightmasterDropdown then
		LibDugi_UIDropDownMenu_Initialize(DGV_TaxiFlightmasterDropdown, DGV_TaxiFlightmasterDropdown.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_TaxiFlightmasterDropdown, DugisGuideViewer:UserSetting(DGV_TAXIFLIGHTMASTERS))
	end	

	--Quest Complete Sound Dropdown
	if SettingsDB[DGV_QUESTCOMPLETESOUND].category==category
		and(not DugisGuideViewer:GetDB(DGV_QUESTCOMPLETESOUND, "module")
		or DugisGuideViewer:IsModuleRegistered(DugisGuideViewer:GetDB(DGV_QUESTCOMPLETESOUND, "module")))
		and not DGV_QuestCompleteSoundDropdown
	then
		local dropdown = self:CreateDropdown("DGV_QuestCompleteSoundDropdown", frame, "Quest Complete Sound", DGV_QUESTCOMPLETESOUND, self.QuestCompleteSoundDropdown_OnClick)
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, top)
		top = top-22-dropdown:GetHeight()
	end
	if DGV_QuestCompleteSoundDropdown then
		LibDugi_UIDropDownMenu_Initialize(DGV_QuestCompleteSoundDropdown, DGV_QuestCompleteSoundDropdown.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_QuestCompleteSoundDropdown, DugisGuideViewer:UserSetting(DGV_QUESTCOMPLETESOUND))
	end
	
	--Tooltip Anchor
	if SettingsDB[DGV_TOOLTIPANCHOR].category==category  and not DGV_TooltipAnchorDropdown then
		local dropdown = self:CreateDropdown("DGV_TooltipAnchorDropdown", frame, "Tooltip Anchor", DGV_TOOLTIPANCHOR, self.TooltipAnchorDropdown_OnClick)
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, top)
		top = top-22-dropdown:GetHeight()
	end
	if DGV_TooltipAnchorDropdown then
		LibDugi_UIDropDownMenu_Initialize(DGV_TooltipAnchorDropdown, DGV_TooltipAnchorDropdown.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_TooltipAnchorDropdown, DugisGuideViewer:UserSetting(DGV_TOOLTIPANCHOR))
	end
	
	--Map Preview POIs
	if SettingsDB[DGV_MAPPREVIEWPOIS].category==category and not DGV_MapPreviewPOIsDropdown then
		topRightColumn = topRightColumn-27
		local dropdown = self:CreateDropdown("DGV_MapPreviewPOIsDropdown", frame, "Preview Quest Objectives", DGV_MAPPREVIEWPOIS, self.MapPreviewPOIsDropdown_OnClick)
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX, topRightColumn)
		
		topRightColumn = topRightColumn-dropdown:GetHeight()
	end
	if DGV_MapPreviewPOIsDropdown then
		LibDugi_UIDropDownMenu_Initialize(DGV_MapPreviewPOIsDropdown, DGV_MapPreviewPOIsDropdown.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_MapPreviewPOIsDropdown, DugisGuideViewer:UserSetting(DGV_MAPPREVIEWPOIS))
	end

	if DugisGuideViewer:IsModuleRegistered("SmallFrame") and SettingsDB[DGV_DISPLAYPRESET].category==category and not DGV_DisplayPresetDropdown then
		local dropdown = self:CreateDropdown("DGV_DisplayPresetDropdown", frame, "Recommended Preset Settings", DGV_DISPLAYPRESET, self.DisplayPresetDropdown_OnClick)
		dropdown:SetPoint("TOPLEFT", frame, "TOPLEFT", 3, top)
		top = top-22-dropdown:GetHeight()
	end
	if DugisGuideViewer:IsModuleRegistered("SmallFrame") and DGV_DisplayPresetDropdown then
		LibDugi_UIDropDownMenu_Initialize(DGV_DisplayPresetDropdown, DGV_DisplayPresetDropdown.initFunc)
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_DisplayPresetDropdown, DugisGuideViewer:UserSetting(DGV_DISPLAYPRESET))
	end
	
	-- select profile
	if category=="Profiles" then
		local dropdown = DGV_SelectProfileDropdown
		if not dropdown then
			dropdown = self:CreateDropdown(
				"DGV_SelectProfileDropdown", 
				frame, 
				"Existing Profiles", 
				nil, 
				function(button) 
					DugisGuideViewer.db:SetProfile(button.value)
				end, 
				function() return getProfileList() end)
			dropdown:SetPoint("TOPLEFT", 3, top)
			top = top-22-dropdown:GetHeight()
		end
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_SelectProfileDropdown, DugisGuideViewer.db.keys.profile)
	end

	
	-- copy from profile
	if category=="Profiles" then
		local dropdown = DGV_CopyProfileDropdown
		if not dropdown then
			dropdown = self:CreateDropdown(
				"DGV_CopyProfileDropdown", 
				frame, 
				"Copy From", 
				nil, 
				function(button)
					DugisGuideViewer.db:CopyProfile(button.value)
				end, 
				function() return getProfileList(true, true) end)
			dropdown:SetPoint("TOPLEFT", 3, top)
			top = top-22-dropdown:GetHeight()
		end
	end
	
	-- delete a profile
	if category=="Profiles" then
		local dropdown = DGV_DeleteProfileDropdown
		if not dropdown then
			dropdown = self:CreateDropdown(
				"DGV_DeleteProfileDropdown", 
				frame, 
				"Delete a Profile", 
				nil, 
				function(button)
					DugisGuideViewer.db:DeleteProfile(button.value)
				end, 
				function() return getProfileList(true, true) end)
			dropdown:SetPoint("TOPLEFT", 3, top)
			top = top-22-dropdown:GetHeight()
		end
	end
	
	--Show Tooltip Slider
	if SettingsDB[DGV_SHOWTOOLTIP].category==category and not DGV_ShowTooltipSlider and DugisGuideViewer:IsModuleLoaded("SmallFrame") then
		local slider = self:CreateSlider("DGV_ShowTooltipSlider", frame, SettingsDB[DGV_SHOWTOOLTIP].text, 
			DGV_SHOWTOOLTIP, 0, 30, 1, 5, "0", "30", function() DugisGuideViewer:ShowAutoTooltip() end)
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 23, top)
		top = top-30-slider:GetHeight()
	end
	if DGV_ShowTooltipSlider then
		DGV_ShowTooltipSlider:SetValue(DugisGuideViewer:GetDB(DGV_SHOWTOOLTIP) or 5)
	end
	
	--DGV_SMALLFRAMEFONTSIZE
	if SettingsDB[DGV_SMALLFRAMEFONTSIZE].category==category and not DGV_SmallFrameFontSize then
		local slider = self:CreateSlider("DGV_SmallFrameFontSize", frame, SettingsDB[DGV_SMALLFRAMEFONTSIZE].text, 
			DGV_SMALLFRAMEFONTSIZE, 10, 20, 1, 8, "10", "20")
		slider:HookScript("OnMouseUp", function()
			if DugisGuideViewer:IsModuleLoaded("SmallFrame") then
				DugisGuideViewer:UpdateSmallFrame()
                DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
			end
		end)
		top = -57
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 350, top)
		top = top-35-slider:GetHeight()
	end
	if DGV_SmallFrameFontSize and DugisGuideViewer:IsModuleLoaded("SmallFrame") then
		DGV_SmallFrameFontSize:SetValue(DugisGuideViewer:GetDB(DGV_SMALLFRAMEFONTSIZE) or 5)
	end	
    
	--DGV_MOUNT_DELAY
	if SettingsDB[DGV_MOUNT_DELAY].category==category and not DGV_MountDelay then
		local slider = self:CreateSlider("DGV_MountDelay", frame, SettingsDB[DGV_MOUNT_DELAY].text, 
			DGV_MOUNT_DELAY, 1, 20, 1, 8, "1", "20")
		
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 23, -270)
	end
	if DGV_MountDelay then
		DGV_MountDelay:SetValue(DugisGuideViewer:GetDB(DGV_MOUNT_DELAY) or 6)
	end
    
	--DGV_TARGETBUTTONSCALE
	if SettingsDB[DGV_TARGETBUTTONSCALE].category==category and not DGV_TargetButtonScale then
		local slider = self:CreateSlider("DGV_TargetButtonScale", frame, SettingsDB[DGV_TARGETBUTTONSCALE].text, 
			DGV_TARGETBUTTONSCALE, 1, 10, 1, 1, "1", "10")
		slider:HookScript("OnMouseUp", function()
			if DugisGuideViewer:IsModuleLoaded("Target") then
				DugisGuideViewer:FinalizeTarget()
			end
		end)
		top = -57
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 350, top)
		top = top-35-slider:GetHeight()
	end
	if DGV_TargetButtonScale and DugisGuideViewer:IsModuleLoaded("Target") then
		DGV_TargetButtonScale:SetValue(DugisGuideViewer:GetDB(DGV_TARGETBUTTONSCALE) or 5)
	
	end
	
	--DGV_ITEMBUTTONSCALE
	if SettingsDB[DGV_ITEMBUTTONSCALE].category==category and not DGV_ItemButtonScale then
		local slider = self:CreateSlider("DGV_ItemButtonScale", frame, SettingsDB[DGV_ITEMBUTTONSCALE].text, 
			DGV_ITEMBUTTONSCALE, 1, 10, 1, 1, "1", "10")
		slider:HookScript("OnMouseUp", function()
			if DugisGuideViewer:IsModuleLoaded("Guides") then
				DugisGuideViewer.DoOutOfCombat(SetUseItem, DugisGuideUser.CurrentQuestIndex)
			elseif DugisGuideViewer:IsModuleLoaded("DugisArrow") then
				local questId = DugisGuideViewer.DugisArrow:GetFirstWaypointQuestId()
				DugisGuideViewer.DoOutOfCombat(SetUseItemByQID, questId)
			end
		end)
		top = -116
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 325, top)
		top = top-30-slider:GetHeight()
	end
	if DGV_ItemButtonScale then
		DGV_ItemButtonScale:SetValue(DugisGuideViewer:GetDB(DGV_ITEMBUTTONSCALE) or 5)
	end		
	
	--DGV_NAMEPLATEICONSIZE
	if SettingsDB[DGV_NAMEPLATEICONSIZE].category==category and not DGV_NameplateIconSize then
		local slider = self:CreateSlider("DGV_NameplateIconSize", frame, SettingsDB[DGV_NAMEPLATEICONSIZE].text, 
			DGV_NAMEPLATEICONSIZE, 1, 10, 1, 5, "1", "10")
		slider:HookScript("OnMouseUp", function()
			if DugisGuideViewer:IsModuleLoaded("NamePlate") then
				DugisGuideViewer.Modules.NamePlate:UpdateActivePlatesExtras()
			end
		end)
		
		top = top - 86
		
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 325, top)
		top = top-30-slider:GetHeight()
	end
	if DGV_NameplateIconSize then
		DGV_NameplateIconSize:SetValue(DugisGuideViewer:GetDB(DGV_NAMEPLATEICONSIZE) or 5)
	end	
	
	
	--DGV_NAMEPLATETEXTSIZE
	if SettingsDB[DGV_NAMEPLATETEXTSIZE].category==category and not DGV_NameplateTextSize then
		local slider = self:CreateSlider("DGV_NameplateTextSize", frame, SettingsDB[DGV_NAMEPLATETEXTSIZE].text, 
			DGV_NAMEPLATETEXTSIZE, 1, 10, 1, 3, "1", "10")
		slider:HookScript("OnMouseUp", function()
			if DugisGuideViewer:IsModuleLoaded("NamePlate") then
				DugisGuideViewer.Modules.NamePlate:UpdateActivePlatesExtras()
			end
		end)
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 325, top)
		top = top-30-slider:GetHeight()
	end
	if DGV_NameplateTextSize then
		DGV_NameplateTextSize:SetValue(DugisGuideViewer:GetDB(DGV_NAMEPLATETEXTSIZE) or 3)
	end	
    
	--DGV_SMALLFRAME_STEPS
	if SettingsDB[DGV_SMALLFRAME_STEPS].category==category and not DGV_Smallframe_Steps then
		local slider = self:CreateSlider("DGV_Smallframe_Steps", frame, SettingsDB[DGV_SMALLFRAME_STEPS].text, 
			DGV_SMALLFRAME_STEPS, 2, 8, 1, 1, "2", "8")
		slider:HookScript("OnMouseUp", function()
			DugisGuideViewer:UpdateCompletionVisuals()
		end)
		top = -122
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 350, top)
		top = top-30-slider:GetHeight()
	end
	if DGV_Smallframe_Steps then
		DGV_Smallframe_Steps:SetValue(DugisGuideViewer:GetDB(DGV_SMALLFRAME_STEPS) or 6)
	end	
	
	--DGV_GPS_MAPS_OPACITY
	if SettingsDB[DGV_GPS_MAPS_OPACITY].category==category and not DGV_gps_maps_opacity then
		local slider = self:CreateSlider("DGV_gps_maps_opacity", frame, SettingsDB[DGV_GPS_MAPS_OPACITY].text, 
			DGV_GPS_MAPS_OPACITY, 0, 1, 0.1, 0.1, "0", "1")
		slider:HookScript("OnValueChanged", function()
			if DugisGuideViewer.Modules.GPSArrowModule then
				DugisGuideViewer.Modules.GPSArrowModule.UpdateOpacity()
			end
		end)	
		
		slider:HookScript("OnMouseUp", function()
			if DugisGuideViewer.Modules.GPSArrowModule then
				DugisGuideViewer.Modules.GPSArrowModule.UpdateMinimapAlpha()
			end
		end)
		
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX + 50, topRightColumn)
		topRightColumn = topRightColumn-55
	end
	if DGV_gps_maps_opacity then
		DGV_gps_maps_opacity:SetValue(DugisGuideViewer:GetDB(DGV_GPS_MAPS_OPACITY) or DGV:GetDefaultValue(DGV_GPS_MAPS_OPACITY))
	end	
	
	
	--DGV_GPS_BORDER_OPACITY
	if SettingsDB[DGV_GPS_BORDER_OPACITY].category==category and not DGV_gps_border_opacity then
		local slider = self:CreateSlider("DGV_gps_border_opacity", frame, SettingsDB[DGV_GPS_BORDER_OPACITY].text, 
			DGV_GPS_BORDER_OPACITY, 0, 1, 0.1, 0.1, "0", "1")
		slider:HookScript("OnValueChanged", function()
			if DugisGuideViewer.Modules.GPSArrowModule then
				DugisGuideViewer.Modules.GPSArrowModule.UpdateOpacity()
			end
		end)
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX+ 50, topRightColumn)
		topRightColumn = topRightColumn+27
	end
	if DGV_gps_border_opacity then
		DGV_gps_border_opacity:SetValue(DugisGuideViewer:GetDB(DGV_GPS_BORDER_OPACITY) or DGV:GetDefaultValue(DGV_GPS_BORDER_OPACITY))
	end			
	
	--DGV_GPS_MAPS_SIZE
	if SettingsDB[DGV_GPS_MAPS_SIZE].category==category and not DGV_gps_maps_size then
		local slider = self:CreateSlider("DGV_gps_maps_size", frame, SettingsDB[DGV_GPS_MAPS_SIZE].text, 
			DGV_GPS_MAPS_SIZE, 1, 20, 0.1, 0.1, "1", "20")
		slider:HookScript("OnValueChanged", function()
			if DugisGuideViewer.Modules.GPSArrowModule then
				DugisGuideViewer.Modules.GPSArrowModule.UpdateSize()
			end
		end)
		topRightColumn = topRightColumn-77
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX+ 50, topRightColumn)
		topRightColumn = topRightColumn+27
	end
	if DGV_gps_maps_size then
		DGV_gps_maps_size:SetValue(DugisGuideViewer:GetDB(DGV_GPS_MAPS_SIZE) or DGV:GetDefaultValue(DGV_GPS_MAPS_SIZE))
	end		
	
	--DGV_GPS_ARROW_SIZE
	if SettingsDB[DGV_GPS_ARROW_SIZE].category==category and not DGV_gps_arrow_size then
		local slider = self:CreateSlider("DGV_gps_arrow_size", frame, SettingsDB[DGV_GPS_ARROW_SIZE].text, 
			DGV_GPS_ARROW_SIZE, 1, 10, 0.1, 0.1, "1", "10")
		slider:HookScript("OnValueChanged", function()
			if DugisGuideViewer.Modules.GPSArrowModule then
				DugisGuideViewer.Modules.GPSArrowModule.UpdateArrowSize()
			end
		end)
		topRightColumn = topRightColumn - 77
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX + 50, topRightColumn)
		topRightColumn = topRightColumn + 27
	end
	if DGV_gps_arrow_size then
		DGV_gps_arrow_size:SetValue(DugisGuideViewer:GetDB(DGV_GPS_ARROW_SIZE) or DGV:GetDefaultValue(DGV_GPS_ARROW_SIZE))
	end			
	
    
    local old_DGV_JOURNALFRAMEBUTTONSCALE = DugisGuideViewer:UserSetting(DGV_JOURNALFRAMEBUTTONSCALE)
    --DGV_JOURNALFRAMEBUTTONSCALE
	if SettingsDB[DGV_JOURNALFRAMEBUTTONSCALE].category==category and not DGV_JournalframeButtonScale and DugisGuideViewer:IsModuleLoaded("NPCJournalFrame") then
		local slider = self:CreateSlider("DGV_JournalframeButtonScale", frame, SettingsDB[DGV_JOURNALFRAMEBUTTONSCALE].text, 
			DGV_JOURNALFRAMEBUTTONSCALE, 1, 10, 1, 4, "1", "10", function()
                if old_DGV_JOURNALFRAMEBUTTONSCALE ~= DugisGuideViewer:UserSetting(DGV_JOURNALFRAMEBUTTONSCALE) then
                    DugisGuideViewer.NPCJournalFrame.sidebarButtonFrame:RestoreSidebarIconPosition()
                    old_DGV_JOURNALFRAMEBUTTONSCALE = DugisGuideViewer:UserSetting(DGV_JOURNALFRAMEBUTTONSCALE)
                end
            end)
		top = -117
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", 350, top)
		top = top-30-slider:GetHeight()
	end
	if DGV_JournalframeButtonScale then
		DGV_JournalframeButtonScale:SetValue(DugisGuideViewer:GetDB(DGV_JOURNALFRAMEBUTTONSCALE) or 4)
	end	    
	
	--Map Preview Slider
	if SettingsDB[DGV_MAPPREVIEWDURATION].category==category and not DGV_MapPreviewSlider then
		local slider = self:CreateSlider("DGV_MapPreviewSlider", frame, SettingsDB[DGV_MAPPREVIEWDURATION].text, 
			DGV_MAPPREVIEWDURATION, 0, 30, 1, 10, "0", "30")
		slider:HookScript("OnMouseUp", function()
			if DugisGuideViewer:IsModuleLoaded("MapPreview") then
				DugisGuideViewer.MapPreview:ConfigChanged()
			end
		end)
		topRightColumn = topRightColumn-27
		
		slider:SetPoint("TOPLEFT", frame, "TOPLEFT", rightColumnX + 20, topRightColumn)
		if DugisGuideViewer.carboniteloaded then
			_G[slider:GetName() .. 'Text']:SetTextColor(0.5, 0.5, 0.5)
			_G[slider:GetName() .. 'Low']:SetTextColor(0.5, 0.5, 0.5)
			_G[slider:GetName() .. 'High']:SetTextColor(0.5, 0.5, 0.5)
			slider:Disable()
		end
		topRightColumn = topRightColumn-slider:GetHeight()
	end
	if DGV_MapPreviewSlider then
		DGV_MapPreviewSlider:SetValue(DugisGuideViewer:GetDB(DGV_MAPPREVIEWDURATION) or 1)
	end
	
	--if SettingsDB[DGV_BLINKMINIMAPICONS].category==category and DugisGuideViewer.zygorloaded then
		--Disable(_G["DGV.ChkBox"..DGV_BLINKMINIMAPICONS])
	--end
	
	return frame
end

local function IterateReturns(...)
		local i, tbl = 0, {...}
		return function ()
			i = i + 1
			if i <= #(tbl) then return tbl[i] end
		end
	end

function DugisGuideViewer:CreateSettingsTree(parent)
	if DugisGuideViewer.SettingsTree then
		DugisGuideViewer.SettingsTree.frame:ClearAllPoints()
		DugisGuideViewer.SettingsTree.frame:Hide()
		AceGUI:Release(DugisGuideViewer.SettingsTree)
	end
	settingsMenuTreeGroup = AceGUI:Create("TreeGroup")
	settingsMenuTreeGroup:SetTree(CATEGORY_TREE)		
	settingsMenuTreeGroup:EnableButtonTooltips(false)
	--settingsMenuTreeGroup.frame:SetBackdrop(nil);
	settingsMenuTreeGroup.frame:SetParent(parent)
	settingsMenuTreeGroup.treeframe:SetBackdropColor(0,0,0,0);
	settingsMenuTreeGroup.border:SetBackdropColor(0,0,0,0);
	settingsMenuTreeGroup.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, 0)
	settingsMenuTreeGroup.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 12)
				
	settingsMenuTreeGroup:SetCallback("OnGroupSelected", function(group, event, value)
		for child in IterateReturns(settingsMenuTreeGroup.border:GetChildren()) do
			child:Hide()
		end
		GetSettingsCategoryFrame(value, settingsMenuTreeGroup.border):Show()

	end)
	settingsMenuTreeGroup:SelectByValue(CATEGORY_TREE[1].value)
	settingsMenuTreeGroup.frame:Show()
	settingsMenuTreeGroup.frame:GetScript("OnSizeChanged")(settingsMenuTreeGroup.frame)
	DugisGuideViewer.SettingsTree = settingsMenuTreeGroup;
    
    UpdateLeftMenu()    
end

function DugisGuideViewer:ForceAllSettingsTreeCategories()
	for _,node in ipairs(CATEGORY_TREE) do
        if DugisGuideViewer.SettingsTree then
            GetSettingsCategoryFrame(node.value, DugisGuideViewer.SettingsTree.border):Hide()
        end
	end
	local tree = DugisGuideViewer.SettingsTree
    if not tree then
        return
    end
	local status = tree.status or tree.localstatus
	tree:SelectByValue(status.selected)
end

--Weapon Preference Dropdown
function DugisGuideViewer.WeaponPreference_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedValue(DGV_WeaponPreference, button.value )
	DugisGuideViewer:SetDB(button.value, DGV_WEAPONPREF)
end

function DugisGuideViewer.SmartSetTargetOnClick(value)
	if DGV_GASmartSetTargetDropdown then
		LibDugi_UIDropDownMenu_SetSelectedValue(DGV_GASmartSetTargetDropdown, value)
	end
	DugisGuideViewer:SetDB(value, DGV_GASMARTSETTARGET)
	PaperDollEquipmentManagerPane_Update(true)
end

--Smart Set Target Dropdown
function DugisGuideViewer.GASmartSetTargetDropdown_OnClick(button)
	 DugisGuideViewer.SmartSetTargetOnClick(button.value)
end

--StatCapLevelDifferenceDropdown
function DugisGuideViewer.StatCapLevelDifferenceDropdown_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedValue(DGV_StatCapLevelDifferenceDropdown, button.value )
	DugisGuideViewer:SetDB(button.value, DGV_GASTATCAPLEVELDIFFERENCE)
	DugisGuideViewer.Modules.GearAdvisor.ResetCalculateScoreCache()
end


--Guide Suggest Dropdown
function DugisGuideViewer.GuideSuggestDropDown_OnClick(button)
	--LibDugi_UIDropDownMenu_SetSelectedID(DGV_GuideSuggestDropdown, button:GetID() )
	LibDugi_UIDropDownMenu_SetSelectedValue(DGV_GuideSuggestDropdown, button.value )
	
	DugisGuideViewer:SetDB(button.value, DGV_GUIDEDIFFICULTY)
	DebugPrint("button.value"..button.value.."button.id"..button:GetID())
	if DugisGuideViewer:IsModuleLoaded("Guides") then DugisGuideViewer:TabTextRefresh() end
end

--Status Frame Effect dropdown
function DugisGuideViewer.StatusFrameEffectDropDown_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedID(DGV_StatusFrameEffectDropdown, button:GetID() )
	DugisGuideViewer:SetDB(button.value, DGV_SMALLFRAMETRANSITION)
	
	local options = DugisGuideViewer:GetDB(DGV_SMALLFRAMETRANSITION, "options")
	if button.value == options[1].text then
		--UIFrameFadeIn(DugisSmallFrame, 0.8, 0, 1)
        if DugisGuideViewer.Modules.SmallFrame.PlayFlashAnimation then
            DugisGuideViewer.Modules.SmallFrame:PlayFlashAnimation( )
        end
		DugisGuideViewer.Modules.DugisWatchFrame:PlayFlashAnimation( )
	elseif button.value == options[2].text then
        if DugisGuideViewer.Modules.SmallFrame.StartFrameTransition then
            DugisGuideViewer.Modules.SmallFrame:StartFrameTransition( )
        end
	end
end

function DugisGuideViewer.MainFrameBackgroundDropDown_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedID(DGV_Main_Frame_Background_Dropdown, button:GetID() )
	DugisGuideViewer:SetDB(button.value, DGV_MAIN_FRAME_BACKGROUND)
    DugisGuideViewer:UpdateCurrentGuideExpanded()
end

function DugisGuideViewer.RouteStyleDropDown_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedID(DGV_route_style, button:GetID() )
	DugisGuideViewer:SetDB(button.value, DGV_ROUTE_STYLE)
    DugisGuideViewer:UpdateCurrentGuideExpanded()
end

function DugisGuideViewer:SetFrameBackdrop(frame, bgFile, edgeFile, left, right, top, bottom, edgeSize)
	if not frame then return end
	if not bgFile and not edgeFile then
		frame:SetBackdrop(nil)
	else
		frame:SetBackdrop( { 
			bgFile = bgFile, 
			edgeFile = edgeFile, tile = true, tileSize = 32, edgeSize = edgeSize or 32, 
			insets = { left = left, right = right, top = top, bottom = bottom }
		})
	end
	
	DugisGuideViewer.ApplyElvUIColor(frame)	
	
end

function DugisGuideViewer:GetBorderPath()
	return self.ARTWORK_PATH.."Border-"..DugisGuideViewer:UserSetting(DGV_LARGEFRAMEBORDER)
end

function DugisGuideViewer:GetGPSBorderPath()
	return self.ARTWORK_PATH.."Border-"..DugisGuideViewer:UserSetting(DGV_GPS_BORDER)
end

function DugisGuideViewer.ApplyElvUIColor(frame)
	local path = DugisGuideViewer:GetBorderPath()
	if frame and string.match(path, "ElvUI") then
		if ElvUI then
			local E = unpack(ElvUI);
			frame:SetBackdropBorderColor(unpack(E['media'].bordercolor));
			return
		end
		
		if DugisGuideViewer.tukuiloaded and Tukui then
			local _, C = unpack(Tukui);
			local general = C["General"]
			if general then
				local BorderColor = general["BorderColor"]
				if BorderColor then
					frame:SetBackdropBorderColor(unpack(BorderColor))
					return
				end
			end
		end

		frame:SetBackdropBorderColor(0,0,0);
	end
end

function DugisGuideViewer:SetAllBorders( )
	if ElvUI and not DugisGuideViewer.ElvUIhooked then
		LuaUtils:foreach({"UpdateAll",  "UpdateBorderColors"}, function(functionName)
			local E = unpack(ElvUI);
			hooksecurefunc(E, functionName, function()
				DugisGuideViewer:SetAllBorders()
				DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()	
			end)
		end)
		DugisGuideViewer.ElvUIhooked = true
	end

	self:SetSmallFrameBorder( )
	self:SetFrameBackdrop(DugisMainBorder, DugisGuideViewer.chardb.EssentialsMode>0 and self.BACKGRND_PATH, self:GetBorderPath(), 10, 3, 11, 5)
	if DugisGuideViewer:IsModuleLoaded("ModelViewer") then
		self:SetFrameBackdrop(self.Modules.ModelViewer.Frame, self.BACKGRND_PATH, self:GetBorderPath(), 10, 4, 12, 5)
	end
	self:SetFrameBackdrop(DugisGuideSuggestFrame,  self.BACKGRND_PATH, self:GetBorderPath(), 10, 4, 12, 5)
	self:SetFrameBackdrop(DugisEquipPromptFrame,  self.BACKGRND_PATH, self:GetBorderPath(), 10, 4, 12, 5)
	if DugisGuideViewer:IsModuleLoaded("StickyFrame") then
		self:SetFrameBackdrop(self.Modules.StickyFrame.Frame, "Interface\\DialogFrame\\UI-DialogBox-Gold-Background", self:GetBorderPath(), 10, 4, 12, 5)
	end
	self:SetFrameBackdrop(DugisRecordFrame,  self.BACKGRND_PATH, self:GetBorderPath(), 10, 4, 12, 5)
    if GearFinderExtraItemsFrame then
        self:SetFrameBackdrop(GearFinderExtraItemsFrame,  self.BACKGRND_PATH, self:GetBorderPath(), 10, 4, 12, 5)
    end   
    
    if GearFinderTooltipFrame then
        self:SetFrameBackdrop(GearFinderTooltipFrame,  self.BACKGRND_PATH, self:GetBorderPath(), 10, 4, 12, 5)
    end
end

function DugisGuideViewer:SetSmallFrameBorder( )
	--Use same border as large frame

	if DugisGuideViewer:UserSetting(DGV_SMALLFRAMEBORDER)  then
		self:SetFrameBackdrop(SmallFrameBkg, self.BACKGRND_PATH, self:GetBorderPath(), 10, 4, 12, 5)
	else
		self:SetFrameBackdrop(SmallFrameBkg, nil)
	end
	
	if DugisGuideViewer:UserSetting(DGV_WATCHFRAMEBORDER)  then
		self:SetFrameBackdrop(ObjectiveFrameDugiBkg, self.BACKGRND_PATH, self:GetBorderPath(), 10, 4, 12, 5)
	else
		self:SetFrameBackdrop(ObjectiveFrameDugiBkg, nil)
	end
end

function DugisGuideViewer:DisplayPreset()
	if DugisGuideViewer:GetDB(DGV_DISPLAYPRESET)=="Minimal - No Borders" then 
		DugisGuideViewer:SetDB(false, DGV_ANCHOREDSMALLFRAME)
		_G["DGV.ChkBox"..DGV_ANCHOREDSMALLFRAME]:SetChecked(false)
		DugisGuideViewer:SetDB(true, DGV_ENABLEQW)
		_G["DGV.ChkBox"..DGV_ENABLEQW]:SetChecked(true)
		DugisGuideViewer:SetDB(false, DGV_MULTISTEPMODE)
		_G["DGV.ChkBox"..DGV_MULTISTEPMODE]:SetChecked(false)
		DugisGuideViewer:SetDB(false, DGV_OBJECTIVECOUNTER)
		_G["DGV.ChkBox"..DGV_OBJECTIVECOUNTER]:SetChecked(false)
		DugisGuideViewer:SetDB(false, DGV_SMALLFRAMEBORDER)						
		DugisGuideViewer:SetDB(false, DGV_WATCHFRAMEBORDER)
		DugisGuideViewer:SetDB(false, DGV_EMBEDDEDTOOLTIP)
		_G["DGV.ChkBox"..DGV_EMBEDDEDTOOLTIP]:SetChecked(false)
		DugisGuideViewer:SetDB(false, DGV_FIXEDWIDTHSMALL)
		_G["DGV.ChkBox"..DGV_FIXEDWIDTHSMALL]:SetChecked(false)
		DugisGuideViewer:SetDB("Scroll", DGV_SMALLFRAMETRANSITION)
	elseif DugisGuideViewer:GetDB(DGV_DISPLAYPRESET)=="Minimal" then 
		DugisGuideViewer:SetDB(false, DGV_ANCHOREDSMALLFRAME)
		_G["DGV.ChkBox"..DGV_ANCHOREDSMALLFRAME]:SetChecked(false)
		DugisGuideViewer:SetDB(true, DGV_ENABLEQW)
		_G["DGV.ChkBox"..DGV_ENABLEQW]:SetChecked(true)
		DugisGuideViewer:SetDB(false, DGV_MULTISTEPMODE)
		_G["DGV.ChkBox"..DGV_MULTISTEPMODE]:SetChecked(false)
		DugisGuideViewer:SetDB(false, DGV_OBJECTIVECOUNTER)
		_G["DGV.ChkBox"..DGV_OBJECTIVECOUNTER]:SetChecked(false)
		DugisGuideViewer:SetDB(true, DGV_SMALLFRAMEBORDER)				
		DugisGuideViewer:SetDB(true, DGV_WATCHFRAMEBORDER)
		DugisGuideViewer:SetDB(false, DGV_EMBEDDEDTOOLTIP)
		_G["DGV.ChkBox"..DGV_EMBEDDEDTOOLTIP]:SetChecked(false)
		DugisGuideViewer:SetDB(false, DGV_FIXEDWIDTHSMALL)
		_G["DGV.ChkBox"..DGV_FIXEDWIDTHSMALL]:SetChecked(false)
		DugisGuideViewer:SetDB("Scroll", DGV_SMALLFRAMETRANSITION)
	elseif DugisGuideViewer:GetDB(DGV_DISPLAYPRESET)=="Standard" then 
		DugisGuideViewer:SetDB(false, DGV_ANCHOREDSMALLFRAME)
		_G["DGV.ChkBox"..DGV_ANCHOREDSMALLFRAME]:SetChecked(false)
		DugisGuideViewer:SetDB(true, DGV_ENABLEQW)
		_G["DGV.ChkBox"..DGV_ENABLEQW]:SetChecked(true)
		DugisGuideViewer:SetDB(false, DGV_MULTISTEPMODE)
		_G["DGV.ChkBox"..DGV_MULTISTEPMODE]:SetChecked(false)
		DugisGuideViewer:SetDB(false, DGV_OBJECTIVECOUNTER)
		_G["DGV.ChkBox"..DGV_OBJECTIVECOUNTER]:SetChecked(false)
		DugisGuideViewer:SetDB(true, DGV_SMALLFRAMEBORDER)						
		DugisGuideViewer:SetDB(true, DGV_WATCHFRAMEBORDER)
		DugisGuideViewer:SetDB(true, DGV_EMBEDDEDTOOLTIP)
		_G["DGV.ChkBox"..DGV_EMBEDDEDTOOLTIP]:SetChecked(true)
		DugisGuideViewer:SetDB(true, DGV_FIXEDWIDTHSMALL)
		_G["DGV.ChkBox"..DGV_FIXEDWIDTHSMALL]:SetChecked(true)	
		DugisGuideViewer:SetDB("Flash", DGV_SMALLFRAMETRANSITION)
	elseif DugisGuideViewer:GetDB(DGV_DISPLAYPRESET)=="Standard - Anchored" then 
	
		if not DugisGuideViewer.tukuiloaded then
			DugisGuideViewer:SetDB(true, DGV_ANCHOREDSMALLFRAME)
			_G["DGV.ChkBox"..DGV_ANCHOREDSMALLFRAME]:SetChecked(true)
		end
			
		DugisGuideViewer:SetDB(true, DGV_ENABLEQW)
		_G["DGV.ChkBox"..DGV_ENABLEQW]:SetChecked(true)
		DugisGuideViewer:SetDB(false, DGV_MULTISTEPMODE)
		_G["DGV.ChkBox"..DGV_MULTISTEPMODE]:SetChecked(false)
		DugisGuideViewer:SetDB(false, DGV_OBJECTIVECOUNTER)
		_G["DGV.ChkBox"..DGV_OBJECTIVECOUNTER]:SetChecked(false)
		DugisGuideViewer:SetDB(true, DGV_SMALLFRAMEBORDER)						
		DugisGuideViewer:SetDB(true, DGV_WATCHFRAMEBORDER)
		DugisGuideViewer:SetDB(true, DGV_EMBEDDEDTOOLTIP)
		_G["DGV.ChkBox"..DGV_EMBEDDEDTOOLTIP]:SetChecked(true)
		DugisGuideViewer:SetDB(true, DGV_FIXEDWIDTHSMALL)
		_G["DGV.ChkBox"..DGV_FIXEDWIDTHSMALL]:SetChecked(true)	
		DugisGuideViewer:SetDB("Flash", DGV_SMALLFRAMETRANSITION)
	elseif DugisGuideViewer:GetDB(DGV_DISPLAYPRESET)=="Multi-step" then 
		DugisGuideViewer:SetDB(false, DGV_ANCHOREDSMALLFRAME)
		_G["DGV.ChkBox"..DGV_ANCHOREDSMALLFRAME]:SetChecked(false)
		DugisGuideViewer:SetDB(true, DGV_ENABLEQW)
		_G["DGV.ChkBox"..DGV_ENABLEQW]:SetChecked(false)
		DugisGuideViewer:SetDB(true, DGV_MULTISTEPMODE)
		_G["DGV.ChkBox"..DGV_MULTISTEPMODE]:SetChecked(true)
		DugisGuideViewer:SetDB(true, DGV_OBJECTIVECOUNTER)
		_G["DGV.ChkBox"..DGV_OBJECTIVECOUNTER]:SetChecked(true)
		DugisGuideViewer:SetDB(true, DGV_SMALLFRAMEBORDER)						
		DugisGuideViewer:SetDB(true, DGV_WATCHFRAMEBORDER)
		DugisGuideViewer:SetDB(true, DGV_EMBEDDEDTOOLTIP)
		_G["DGV.ChkBox"..DGV_EMBEDDEDTOOLTIP]:SetChecked(true)
		DugisGuideViewer:SetDB(true, DGV_FIXEDWIDTHSMALL)
		_G["DGV.ChkBox"..DGV_FIXEDWIDTHSMALL]:SetChecked(true)	
		DugisGuideViewer:SetDB("Flash", DGV_SMALLFRAMETRANSITION)
	elseif DugisGuideViewer:GetDB(DGV_DISPLAYPRESET)=="Multi-step - Anchored" then
	
		if not DugisGuideViewer.tukuiloaded then
			DugisGuideViewer:SetDB(true, DGV_ANCHOREDSMALLFRAME)
			_G["DGV.ChkBox"..DGV_ANCHOREDSMALLFRAME]:SetChecked(true)
		end
		
		DugisGuideViewer:SetDB(true, DGV_ENABLEQW)
		_G["DGV.ChkBox"..DGV_ENABLEQW]:SetChecked(false)
		DugisGuideViewer:SetDB(true, DGV_MULTISTEPMODE)
		_G["DGV.ChkBox"..DGV_MULTISTEPMODE]:SetChecked(true)
		DugisGuideViewer:SetDB(true, DGV_OBJECTIVECOUNTER)
		_G["DGV.ChkBox"..DGV_OBJECTIVECOUNTER]:SetChecked(true)
		DugisGuideViewer:SetDB(true, DGV_SMALLFRAMEBORDER)						
		DugisGuideViewer:SetDB(true, DGV_WATCHFRAMEBORDER)
		DugisGuideViewer:SetDB(true, DGV_EMBEDDEDTOOLTIP)
		_G["DGV.ChkBox"..DGV_EMBEDDEDTOOLTIP]:SetChecked(true)
		DugisGuideViewer:SetDB(true, DGV_FIXEDWIDTHSMALL)
		_G["DGV.ChkBox"..DGV_FIXEDWIDTHSMALL]:SetChecked(true)	
		DugisGuideViewer:SetDB("Flash", DGV_SMALLFRAMETRANSITION)				
	end
	DugisGuideViewer:RefreshQuestWatch()
	DugisGuideViewer:UpdateSmallFrame()
end

function DugisGuideViewer:QUEST_ACCEPTED(self, event, qid)
	if not DugisGuideViewer:IsModuleLoaded("Guides") or not DugisGuideViewer:GuideOn() then return end
	local logindex = DugisGuideViewer:GetQuestLogIndexByQID(qid)
	if ( AUTO_QUEST_WATCH == "0" and GetNumQuestWatches() < MAX_WATCHABLE_QUESTS and (DugisGuideViewer:UserSetting(DGV_ENABLEQW) or DugisGuideViewer:UserSetting(DGV_AUTO_QUEST_TRACK))) then
		if DugisGuideViewer.chardb.EssentialsMode ~= 1 then 
			if DugisGuideViewer:UserSetting(DGV_OBJECTIVECOUNTER) and qid and not DugisGuideUser.removedQuests[qid] then 

				AddQuestWatch(logindex) -- this is to make quest appear when player first accepted the quest even with blizzard AUTO_QUEST_WATCH off.
				DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
			end
		elseif DugisGuideViewer.chardb.EssentialsMode == 1 then
			--AddQuestWatch(logindex);
			--DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
		end
	end
    
    LuaUtils:RunInThreadIfNeeded("QUEST_ACCEPTED", function(isInThread)   
        DugisGuideViewer:UpdateMainFrame(isInThread)
    end)
    
end

function DugisGuideViewer:QUEST_WATCH_UPDATE(arg1, arg2, arg3, arg4)
	if not DugisGuideViewer:IsModuleLoaded("Guides") or not DugisGuideViewer:GuideOn() then return end


	local qid = DugisGuideViewer:GetQIDByLogIndex(arg2)
	if ( AUTO_QUEST_WATCH == "0" and GetNumQuestLeaderBoards(arg2) > 0 and GetNumQuestWatches() < MAX_WATCHABLE_QUESTS and (DugisGuideViewer:UserSetting(DGV_ENABLEQW) or DugisGuideViewer:UserSetting(DGV_AUTO_QUEST_TRACK))) then
		if DugisGuideViewer.chardb.EssentialsMode ~= 1 then 
			if DugisGuideViewer:UserSetting(DGV_OBJECTIVECOUNTER) and qid and not DugisGuideUser.removedQuests[qid] then 
				AddQuestWatch(arg2,MAX_QUEST_WATCH_TIME);
				DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate();
			end
		elseif DugisGuideViewer.chardb.EssentialsMode == 1 then
			--AddQuestWatch(arg2,MAX_QUEST_WATCH_TIME);
			--DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
		end
	end
end

function DugisGuideViewer:QUEST_WATCH_LIST_CHANGED()
	if DugisGuideViewer:GuideOn() then
		if DugisGuideViewer:IsModuleLoaded("DugisArrow") then
			DugisGuideViewer.DugisArrow:OnQuestLogChanged()
		end
		
		if DugisGuideViewer:GetDB(DGV_WAYPOINTSON) and DugisGuideViewer.chardb.EssentialsMode == 1 and DugisGuideViewer:IsModuleLoaded("QuestPOI") then 
			DugisGuideViewer.Modules.QuestPOI:ObjectivesChangedDelay(3)
		end
	end	
end

function DugisGuideViewer:RefreshQuestWatch()
	if self:UserSetting(DGV_ENABLEQW) and DugisGuideViewer.chardb.EssentialsMode ~= 1 and DugisGuideViewer:IsModuleLoaded("Guides") and DugisGuideViewer.GuideOn() then
		if AUTO_QUEST_WATCH == "1" then
           -- JU this settings is not available anymore
           -- if InterfaceOptionsObjectivesPanelAutoQuestTracking then
           SetCVar("autoQuestWatch", 0)
           AUTO_QUEST_WATCH = "0"
           -- InterfaceOptionsObjectivesPanelAutoQuestTracking:SetChecked(false)
           -- InterfaceOptionsPanel_CheckButton_Update(InterfaceOptionsObjectivesPanelAutoQuestTracking)
           -- end
		end		
	elseif self:UserSetting(DGV_AUTO_QUEST_TRACK) and DugisGuideViewer.GuideOn() and AUTO_QUEST_WATCH == "0" then
		SetCVar("autoQuestWatch", 1)
		AUTO_QUEST_WATCH = "1"
	elseif not self:UserSetting(DGV_AUTO_QUEST_TRACK) and DugisGuideViewer.GuideOn() and AUTO_QUEST_WATCH == "1" then
		SetCVar("autoQuestWatch", 0)
		AUTO_QUEST_WATCH = "0"		
	end
	if DugisGuideViewer.chardb.EssentialsMode ~= 1 and DugisGuideViewer:IsModuleLoaded("Guides") then 
		DugisGuideViewer:WatchQuest()
	end 		
	
--	if self:UserSetting(DGV_ENABLEQW) and DugisGuideViewer.chardb.EssentialsMode == 1 and AUTO_QUEST_WATCH == "0" then
        -- JU this settings is not available anymore
        -- if InterfaceOptionsObjectivesPanelAutoQuestTracking then
--        SetCVar("autoQuestWatch", 1)
--        AUTO_QUEST_WATCH = "1"
        --    InterfaceOptionsObjectivesPanelAutoQuestTracking:SetChecked(true)
        --    InterfaceOptionsPanel_CheckButton_Update(InterfaceOptionsObjectivesPanelAutoQuestTracking)
        -- end
--	end
end 

--Large Frame Border Dropdown
function DugisGuideViewer.LargeFrameBorderDropdown_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedID(DGV_LargeFrameBorderDropdown, button:GetID() )
	DugisGuideViewer:SetDB(button.value, DGV_LARGEFRAMEBORDER)
	DugisGuideViewer:SetAllBorders( )
	DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
	if DugisGuideViewer.NPCJournalFrame and DugisGuideViewer.NPCJournalFrame.UpdateBorders then DugisGuideViewer.NPCJournalFrame:UpdateBorders() end
end

--GPS Frame Border Dropdown
function DugisGuideViewer.GPSBorderDropdown_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedID(DGV_gps_border, button:GetID() )
	DugisGuideViewer:SetDB(button.value, DGV_GPS_BORDER)
	if DugisGuideViewer.Modules.GPSArrowModule then
		DugisGuideViewer.Modules.GPSArrowModule:UpdateBorder()
	end	
end

--Step Complete Sound Dropdown
function DugisGuideViewer.StepCompleteSoundDropdown_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedID(DGV_StepCompleteSoundDropdown, button:GetID() )
	DebugPrint("Debug StepCompleteSoundDropdown_OnClick: button.text="..button.value)
	DugisGuideViewer:SetDB(button.value, DGV_STEPCOMPLETESOUND)
	--DugisGuideViewer:SetDB(button.value, DGV_STEPCOMPLETESOUND, "value")
	DebugPrint("Debug StepCompleteSoundDropdown_OnClick: DugisGuideViewer:GetDB(DGV_STEPCOMPLETESOUND)="..DugisGuideViewer:GetDB(DGV_STEPCOMPLETESOUND))
	PlaySoundFile(DugisGuideViewer:GetDB(DGV_STEPCOMPLETESOUND))
end

--Flightmaster Handling Dropdown
function DugisGuideViewer.TaxiFlightmasterDropdown_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedID(DGV_TaxiFlightmasterDropdown, button:GetID() )
	DugisGuideViewer:SetDB(button.value, DGV_TAXIFLIGHTMASTERS)
	if DugisGuideViewer.Modules.Taxi and DugisGuideViewer.Modules.Taxi.ResetMovementCache then
		DugisGuideViewer.Modules.Taxi:ResetMovementCache()
	end
end

--Quest Complete Sound Dropdown
function DugisGuideViewer.QuestCompleteSoundDropdown_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedID(DGV_QuestCompleteSoundDropdown, button:GetID() )
	DebugPrint("Debug QuestCompleteSoundDropdown_OnClick: button.text="..button.value)
	DugisGuideViewer:SetDB(button.value, DGV_QUESTCOMPLETESOUND)
	--DugisGuideViewer:SetDB(button.value, DGV_STEPCOMPLETESOUND, "value")
	DebugPrint("Debug QuestCompleteSoundDropdown_OnClick: DugisGuideViewer:GetDB(DGV_QUESTCOMPLETESOUND)="..DugisGuideViewer:GetDB(DGV_QUESTCOMPLETESOUND))
	PlaySoundFile(DugisGuideViewer:GetDB(DGV_QUESTCOMPLETESOUND))
end

function DugisGuideViewer.TooltipAnchorDropdown_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedID(DGV_TooltipAnchorDropdown, button:GetID() )
	DugisGuideViewer:SetDB(button.value, DGV_TOOLTIPANCHOR)
	DugisGuideViewer:UpdateCompletionVisuals()
end

function DugisGuideViewer.MapPreviewPOIsDropdown_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedID(DGV_MapPreviewPOIsDropdown, button:GetID() )
	DugisGuideViewer:SetDB(button.value, DGV_MAPPREVIEWPOIS)
	DugisGuideViewer.MapPreview:ConfigChanged()
end

function DugisGuideViewer.DisplayPresetDropdown_OnClick(button)
	LibDugi_UIDropDownMenu_SetSelectedID(DGV_DisplayPresetDropdown, button:GetID() )
	DugisGuideViewer:SetDB(button.value, DGV_DISPLAYPRESET)
	DugisGuideViewer:DisplayPreset()
end

-- 
-- Database
--
function DugisGuideViewer:GetDB(key, field)
	if not DugisGuideViewer.chardb[key] then
		--DebugPrint("key:"..key.." does not exist in database")
		return
	end
	
	if field then
		local func = loadstring("return DugisGuideViewer.chardb["..tostring(key).."]."..field)
		return func()
	else
		return DugisGuideViewer.chardb[key].checked
	end
end

function DugisGuideViewer:SetDB(value, key, field)
	if not DugisGuideViewer.chardb[key] then
		DebugPrint("key:"..key.." does not exist in database")
		return
	end
	
	if field then 
		local func = loadstring("DugisGuideViewer.chardb["..tostring(key).."]."..field.."="..tostring(value))
		--DebugPrint("func="..func)
		func()
	else
		--DebugPrint("DugisGuideViewer.chardb["..key.."].checked ="..value)
		DugisGuideViewer.chardb[key].checked = value
	end
end

function DugisGuideViewer:UserSetting(name)

	local settings = self.chardb
	
	if not settings[name] then 
		--DebugPrint("Error: UserSetting"..name.." not found")
	end

	return self:GetDB(name)--settings[name].checked
end

--Minimap icons blinking
local MinimapIconsDark = nil
local ticker
local function MinimapIconsBlink()
	if DugisGuideViewer:UserSetting(DGV_BLINKMINIMAPICONS) == false and ticker then
		ticker:Cancel()
		ticker = nil
		Minimap:SetBlipTexture("Interface\\MINIMAP\\ObjectIconsAtlas")
		return
	end
	if MinimapIconsDark then
        if MinimapIconsDark then
            Minimap:SetBlipTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\ObjectIconsAtlas") --Seems to reduce the flashing if we use our own file
        end
	else
		Minimap:SetBlipTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\ObjectIconsAtlas_dark")
	end
    MinimapIconsDark = not MinimapIconsDark
end

local function StartMinimapTicker()
	ticker = C_Timer.NewTicker(1, function() MinimapIconsBlink() end) 
end 

CreateFrame("FRAME","MinimapBlinkerFrame")

--Trick to prevent spoiled texture change
local textureObjectIcons = MinimapBlinkerFrame:CreateTexture("textureObjectIcons","OVERLAY") 
textureObjectIcons:SetTexture("Interface\\MINIMAP\\ObjectIcons") 
textureObjectIcons:SetNonBlocking(true) 
textureObjectIcons:Hide()
local textureObjectIconsDark = MinimapBlinkerFrame:CreateTexture("textureObjectIconsDark","OVERLAY")
textureObjectIconsDark:SetTexture("Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\ObjectIconsDark.blp") 
textureObjectIconsDark:SetNonBlocking(true) 
textureObjectIconsDark:Hide()

function DugisGuideViewer:SettingFrameChkOnClick(box, skip)
	local i, boxindex
	local NPCJournalFrame = DugisGuideViewer.NPCJournalFrame
	--local DGVsettings = self.chardb
	
	if box then
		_, _, boxindex = box:GetName():find("DGV.ChkBox([%d]*)")
		boxindex = tonumber(boxindex)
	end
	
	--Save to DB
	LuaUtils:foreach(self.chardb.sz, function(i)
		if _G["DGV.ChkBox"..i] then
		if _G["DGV.ChkBox"..i]:GetChecked() then self.chardb[i].checked = true else self.chardb[i].checked = false end
		end
	end)
	if _G["DGV.ChkBox"..DGV_TARGETBUTTONCUSTOM] then
		if _G["DGV.ChkBox"..DGV_TARGETBUTTONCUSTOM]:GetChecked() then 
			self.chardb[DGV_TARGETBUTTONCUSTOM].checked = true 
		else 
			self.chardb[DGV_TARGETBUTTONCUSTOM].checked = false 
		end
	end
	

	if not DugisGuideViewer:UserSetting(DGV_ENABLEQUESTLEVELDB) then
		DugisGuideViewer:SetDB(false, DGV_QUESTLEVELON)
		local Chk = _G["DGV.ChkBox"..DGV_QUESTLEVELON]
		Disable(Chk)
	else
		local Chk = _G["DGV.ChkBox"..DGV_QUESTLEVELON]
		Enable(Chk)
	end
	
	if not DugisGuideViewer:UserSetting(DGV_AUTOREPAIR) then
		DugisGuideViewer:SetDB(false, DGV_AUTOREPAIRGUILD)
		local Chk = _G["DGV.ChkBox"..DGV_AUTOREPAIRGUILD]
		Disable(Chk)
	else
		local Chk = _G["DGV.ChkBox"..DGV_AUTOREPAIRGUILD]
		Enable(Chk)
	end
	
	--Quest Level On
	if boxindex == DGV_QUESTLEVELON then
		if DugisGuideViewer:UserSetting(DGV_QUESTLEVELON) and DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode ~= 1 then
			DugisGuideViewer:ViewFrameUpdate()
			DugisGuideViewer:UpdateSmallFrame()
		elseif DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode ~= 1 then
			DugisGuideViewer:ViewFrameUpdate()
			DugisGuideViewer:UpdateSmallFrame()
		end
	end
	
	--Color Code On
	if boxindex == DGV_QUESTCOLORON then
		if DugisGuideViewer:UserSetting(DGV_QUESTCOLORON) and DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode ~= 1 then
			DugisGuideViewer:ViewFrameUpdate()
			DugisGuideViewer:UpdateSmallFrame()
		elseif DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode ~= 1 then
			DugisGuideViewer:ViewFrameUpdate()
			DugisGuideViewer:UpdateSmallFrame()
		end
	end
		
	--Large Frame Lock
	if DugisGuideViewer:UserSetting(DGV_LOCKLARGEFRAME) then 
		DugisMainBorder:EnableMouse(false)
		DugisMainBorder:SetMovable(false)
	else
		DugisMainBorder:EnableMouse(true)
		DugisMainBorder:SetMovable(true)
	end
	
	--Model Viewer Frame Lock
	if DugisGuideViewer:UserSetting(DGV_LOCKMODELFRAME) and DugisGuideViewer:IsModuleLoaded("ModelViewer") then 
		DGV.DoOutOfCombat(function()
			DugisGuideViewer.Modules.ModelViewer.Frame:SetMovable(false)
			DugisGuideViewer.Modules.ModelViewer.Frame:EnableMouse(false)
		end)
	elseif DugisGuideViewer:IsModuleLoaded("ModelViewer") then
		DGV.DoOutOfCombat(function()
			DugisGuideViewer.Modules.ModelViewer.Frame:SetMovable(true)
			DugisGuideViewer.Modules.ModelViewer.Frame:EnableMouse(true)
		end)
	end	
		
	if DugisGuideViewer:UserSetting(DGV_ITEMBUTTONON) then
		DugisGuideViewer.DoOutOfCombat(SetUseItem, DugisGuideUser.CurrentQuestIndex)
	else
		DugisGuideViewerActionItemFrame:Hide()		
		DugisSecureQuestButton:Hide()
	end
	
	if boxindex == DGV_ENABLEMODELDB then
		DugisGuideViewer:UpdateSmallFrame()
	end	
    
	if boxindex == DGV_FISHINGPOLE or boxindex == DGV_COOKINGITEM or boxindex == DGV_DAILYITEM or boxindex == DGV_SUGGESTTRINKET  then
        DugisGuideViewer.GetCurrentBestInSlot_cache = {}
        DugisGuideViewer.GetSpecDataTable_cache = {}
        DugisGuideViewer.GetCurrentRating_cache = {}
        DugisGuideViewer.CalculateScore_cache = {}
        DugisCharacterCache.CalculateScore_cache_v11 = {}
	end	
    
	if  LuaUtils:isInTable(boxindex, {
        DGV_INCLUDE_DUNG_NORMAL,
        DGV_INCLUDE_DUNG_HEROIC,
        DGV_INCLUDE_DUNG_MYTHIC,
        DGV_INCLUDE_DUNG_TIMEWALKING,
        DGV_INCLUDE_RAIDS_RAIDFINDER,
        DGV_INCLUDE_RAIDS_NORMAL,
        DGV_INCLUDE_RAIDS_HEROIC,
        DGV_INCLUDE_RAIDS_MYTHIC,
        DGV_GEARS_FROM_QUEST_GUIDES
    }) then
        OnGearFinderSettingsChanged()
	end
	
	if not self:UserSetting(DGV_ENABLENPCNAMEDB) then
		DugisGuideViewer:SetDB(false, DGV_TARGETBUTTON)
		--self.Target:Disable()
		local ChkBox = _G["DGV.ChkBox"..DGV_TARGETBUTTON]
		Disable(ChkBox)
	else
		local ChkBox = _G["DGV.ChkBox"..DGV_TARGETBUTTON]
		Enable(ChkBox)
	end

	
	if DugisGuideViewer:UserSetting(DGV_TARGETBUTTON) then
		DugisGuideViewer:SetTarget(DugisGuideUser.CurrentQuestIndex)
		
		local ChkBox = _G["DGV.ChkBox"..DGV_TARGETBUTTONSHOW]
		local ChkBox2 = _G["DGV.ChkBox"..DGV_TARGETBUTTONCUSTOM]
		local ChkBox3 = _G["DGV.ChkBox"..DGV_TARGETTOOLTIP]
		local ChkBox4 = _G["DGV.ChkBox"..DGV_TRGET_BUTTON_FIXED_MODE]
		Enable(ChkBox)
		Enable(ChkBox2)
		Enable(ChkBox3)
		Enable(ChkBox4)
	else
		local ChkBox = _G["DGV.ChkBox"..DGV_TARGETBUTTONSHOW]
		local ChkBox2 = _G["DGV.ChkBox"..DGV_TARGETBUTTONCUSTOM]
		local ChkBox3 = _G["DGV.ChkBox"..DGV_TARGETTOOLTIP]
		local ChkBox4 = _G["DGV.ChkBox"..DGV_TRGET_BUTTON_FIXED_MODE]
		Disable(ChkBox)
		Disable(ChkBox2)
		Disable(ChkBox3)		
		Disable(ChkBox4)		
	end

	if DugisGuideViewer:IsModuleLoaded("Target") then
-- 		if DugisGuideViewer:UserSetting(DGV_TARGETBUTTONSHOW) then
-- 			DugisGuideViewer.Modules.Target.Frame:Show()
-- 		else
-- 			DugisGuideViewer.Modules.Target.Frame:Hide()
-- 		end
		DugisGuideViewer:FinalizeTarget()
	end
	
	if self:UserSetting(DGV_TARGETBUTTONCUSTOM) then
		local inputBox = _G["DGV.InputBox"..DGV_TARGETBUTTONCUSTOM]
		Enable(inputBox)
	else
		local inputBox = _G["DGV.InputBox"..DGV_TARGETBUTTONCUSTOM]
		Disable(inputBox)
	end
	
	if self:UserSetting(DGV_SHOWONOFF) then
		DugisOnOffButton:Show()
	else
		DugisOnOffButton:Hide()
	end

	--Prevented Objective Frame resetting each time when user checks/unchecks some checkbox. That was annoying.
	if boxindex == DGV_ENABLEQW then
		if self:UserSetting(DGV_ENABLEQW) ~= DugisGuideUser.EnableQWStatus then
			DugisGuideViewer:RefreshQuestWatch()
			DugisGuideUser.EnableQWStatus = self:UserSetting(DGV_ENABLEQW)
		elseif DugisGuideViewer:IsModuleLoaded("Guides") and DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode ~= 1 then 
			DugisGuideViewer:WatchQuest() 
		end
	end
	
	if self:UserSetting(DGV_FIXEDWIDEFRAME) then
		--SetCVar( "watchFrameWidth", 1, InterfaceOptionsObjectivesPanelWatchFrameWidth.event);
		--InterfaceOptionsObjectivesPanelWatchFrameWidth:SetChecked(true)
		--InterfaceOptionsPanel_CheckButton_Update(InterfaceOptionsObjectivesPanelWatchFrameWidth)	
		--WatchFrame_SetWidth(GetCVar("watchFrameWidth"))
	else
		--SetCVar( "watchFrameWidth", 0, InterfaceOptionsObjectivesPanelWatchFrameWidth.event);
		--InterfaceOptionsObjectivesPanelWatchFrameWidth:SetChecked(false)
		--InterfaceOptionsPanel_CheckButton_Update(InterfaceOptionsObjectivesPanelWatchFrameWidth)	
		--WatchFrame_SetWidth(GetCVar("watchFrameWidth"))
	end
    
    if NPCJournalFrame and NPCJournalFrame.Enable then
        if self:UserSetting(DGV_JOURNALFRAME) then
            NPCJournalFrame:Enable()
        else
            NPCJournalFrame:Disable()
        end
    end
    
	if DugisGuideViewer:IsModuleLoaded("DugisArrow") then
		if self:UserSetting(DGV_DUGIARROW) then
			if self.Modules.DugisArrow and self.Modules.DugisArrow:getNumWaypoints()>0 then DugisArrowFrame:Show() end
			Enable(_G["DGV.ChkBox"..DGV_SHOWCORPSEARROW])
			Enable(_G["DGV.ChkBox"..DGV_CLASSICARROW])
		else
			Disable(_G["DGV.ChkBox"..DGV_SHOWCORPSEARROW])
			Disable(_G["DGV.ChkBox"..DGV_CLASSICARROW])
			DugisArrowFrame:Hide()
		end
		DugisGuideViewer.DugisArrow:setArrowTexture( )
	end

	if not self:UserSetting(DGV_WATCHFRAMEBORDER) and DugisGuideViewer:IsModuleLoaded("DugisWatchFrame") and self:UserSetting(DGV_DISABLEWATCHFRAMEMOD) then
		DugisGuideViewer.Modules.DugisWatchFrame:Reset()
	end		
	
	if boxindex == DGV_WATCHFRAMEBORDER then
		DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
		DugisGuideViewer:SetAllBorders()
	end
    
	if boxindex == DGV_AUTO_MOUNT then
		DugisGuideViewer:UpdateAutoMountEnabled()
	end    
	
	if boxindex == DGV_TOMTOMARROW or boxindex == DGV_CARBONITEARROW then
		DebugPrint("Switch arrow type")
		self:RemoveAllWaypoints()
		if DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode ~= 1 then
			self:MapCurrentObjective()
		end
	end

	DugisGuideViewer:UpdateStickyFrame( )
	if DugisGuideViewer:IsModuleLoaded("SmallFrame")  then
		DugisGuideViewer:SetSmallFrameBorder( )
		DugisGuideViewer.Modules.SmallFrame:ResetFloating()
		DugisGuideViewer:ShowAutoTooltip()
	end


	DugisGuideViewer.Modules.WorldMapTracking:UpdateTrackingMap()
    
    --OnObjectiveTracker_Update on DGV_MULTISTEPMODE and DGV_ANCHOREDSMALLFRAME and DGV_EMBEDDEDTOOLTIP and DGV_OBJECTIVECOUNTER
	if boxindex == DGV_MULTISTEPMODE or boxindex ==  DGV_ANCHOREDSMALLFRAME or boxindex == DGV_EMBEDDEDTOOLTIP or boxindex == DGV_OBJECTIVECOUNTER then
		DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
		if DugisGuideViewer.Modules.ModelViewer.Finalize then
			DugisGuideViewer.Modules.ModelViewer:Finalize()
		end
	end    
    
    if boxindex ==  DGV_ANCHOREDSMALLFRAME then
		DugisGuideViewer:UpdateSmallFrame()		
    end   
    
    if boxindex ==  DGV_DISPLAYGUIDESPROGRESS then
        local Chk = _G["DGV.ChkBox"..DGV_DISPLAYGUIDESPROGRESSTEXT]
        if DugisGuideViewer:UserSetting(DGV_DISPLAYGUIDESPROGRESS) then
            Enable(Chk)
        else
            Disable(Chk)
        end
    end    
    
    if boxindex ==  DGV_USE_NOTIFICATIONS_MARK then
        DugisGuideViewer:UpdateNotificationsMarkVisibility()
    end        
	
    if boxindex ==  DGV_ENABLED_GPS_ARROW then
        if DugisGuideViewer:UserSetting(DGV_ENABLED_GPS_ARROW) then
			DugisGuideViewer.Modules.GPSArrowModule:Initialize()
			DugisGuideViewer.Modules.GPSArrowModule.initialized = true
			
        else
			if DugisGuideViewer.Modules.GPSArrowModule then
				DugisGuideViewer.Modules.GPSArrowModule:Unload()
				DugisGuideViewer.Modules.GPSArrowModule.loaded = false
			end
        end
		
		DugisGuideViewer.Modules.GPSArrowModule.UpdateVisibility()
    end    
	
    if boxindex == DGV_TRGET_BUTTON_FIXED_MODE then
		if DugisGuideViewer:IsModuleLoaded("Target") then
			self.Modules.Target:UpdateMode()
		end
    end   

	if boxindex == DGV_GPS_ARROW_POIS then
		if DugisGuideViewer.Modules.GPSArrowModule then
			DugisGuideViewer.Modules.GPSArrowModule.UpdatePOISVisibility()
		end
    end   
	
	if boxindex == DGV_GPS_AUTO_HIDE then
		if DugisGuideViewer.Modules.GPSArrowModule then
			DugisGuideViewer.Modules.GPSArrowModule.UpdateVisibility()
		end
    end   
 	
	if boxindex == DGV_GPS_MERGE_WITH_DUGI_ARROW then
		if DugisGuideViewer.Modules.GPSArrowModule then
			DugisGuideViewer.Modules.GPSArrowModule.UpdateMerged()
		end
    end   	
	
	if boxindex == DGV_GPS_MINIMAP_TERRAIN_DETAIL then
		if DugisGuideViewer.Modules.GPSArrowModule then
			DugisGuideViewer.Modules.GPSArrowModule.UpdateMinimapAlpha()
		end
    end    
    
    if boxindex == DGV_STICKYFRAMESHOWDESCRIPTIONS then
		DugisGuideViewer:UpdateStickyFrame( )
	end       
	
    if boxindex == DGV_NAMEPLATES_TRACKING 
	or boxindex == DGV_NAMEPLATES_SHOW_TEXT 
	or boxindex == DGV_NAMEPLATES_SHOW_ICON then
		if DugisGuideViewer.NamePlate then
			DugisGuideViewer.NamePlate:UpdateActivePlatesExtras()
		end
		
		if self:UserSetting(DGV_NAMEPLATES_TRACKING) then
			Enable(_G["DGV.ChkBox"..DGV_NAMEPLATES_SHOW_TEXT])
			Enable(_G["DGV.ChkBox"..DGV_NAMEPLATES_SHOW_ICON])
		else
			Disable(_G["DGV.ChkBox"..DGV_NAMEPLATES_SHOW_TEXT])
			Disable(_G["DGV.ChkBox"..DGV_NAMEPLATES_SHOW_ICON])
		end
		
	end   
    
    if boxindex == DGV_JOURNALFRAMEBUTTONSTICKED and DugisGuideViewer.NPCJournalFrame.sidebarButtonFrame then
		DugisGuideViewer.NPCJournalFrame.sidebarButtonFrame:RestoreSidebarIconPosition()
	end   

    if boxindex == DGV_DISPLAYALLSTATS then
        DugisGuideViewer.Modules.GearAdvisor:UpdateWeightsTextboxes()
	end  
    
    if boxindex == DGV_ENABLEDGEARFINDER then
        if not DugisGuideViewer:UserSetting(DGV_ENABLEDGEARFINDER) then
            HideUIPanel(CharacterFrame)
        else
            InitializeGearFinder(true)            
        end
	end      

    if boxindex == DGV_MOVEWATCHFRAME then
		if not self:UserSetting(DGV_MOVEWATCHFRAME) then
			Disable(_G["DGV.ChkBox"..DGV_DISABLEWATCHFRAMEMOD])
		else
			Enable(_G["DGV.ChkBox"..DGV_DISABLEWATCHFRAMEMOD])
		end
		if DugisGuideViewer.Modules.DugisWatchFrame and DugisGuideViewer.Modules.DugisWatchFrame.UpdateWatchFrameMovable then
			DugisGuideViewer.Modules.DugisWatchFrame:UpdateWatchFrameMovable()
		end
		DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
	end 

    if boxindex == DGV_LOCKSMALLFRAME then
		if DugisGuideViewer.Modules.DugisWatchFrame and DugisGuideViewer.Modules.DugisWatchFrame.UpdateWatchFrameMovable then
			DugisGuideViewer.Modules.DugisWatchFrame:UpdateWatchFrameMovable()
		end
	end 
	
	if boxindex == DGV_DISABLEWATCHFRAMEMOD then
		if DugisGuideViewer.Modules.DugisWatchFrame and DugisGuideViewer.Modules.DugisWatchFrame.UpdateWatchFrameMovable then
			DugisGuideViewer.Modules.DugisWatchFrame:UpdateWatchFrameMovable()
		end
	end   
	
	if self:UserSetting(DGV_BLINKMINIMAPICONS) then
		--StartMinimapTicker()
	end 
	
	if boxindex == DGV_WATCHLOCALQUEST then
		DugisGuideViewer:WatchLocalQuest()
	end
	
	if boxindex == DGV_AUTO_QUEST_TRACK then
		if self:UserSetting(DGV_AUTO_QUEST_TRACK) and AUTO_QUEST_WATCH == "0" then
			SetCVar("autoQuestWatch", 1)
			AUTO_QUEST_WATCH = "1"
		elseif not self:UserSetting(DGV_AUTO_QUEST_TRACK) and AUTO_QUEST_WATCH == "1" then
			SetCVar("autoQuestWatch", 0)
			AUTO_QUEST_WATCH = "0"
		end
	end
end

function DugisGuideViewer:SettingsTooltip_OnEnter(chk, event)
	local _, _, boxindex = chk:GetName():find("DGV.ChkBox([%d]*)")
	boxindex = tonumber(boxindex)
	
	local DGVsettings = self.chardb
		
	if DGVsettings[boxindex].tooltip ~= "\"\"" then
		GameTooltip:SetOwner( chk, "ANCHOR_BOTTOMLEFT")
		GameTooltip:AddLine(L[DGVsettings[boxindex].tooltip], 1, 1, 1, 1, true)
		GameTooltip:Show()
		GameTooltip:ClearAllPoints()
		GameTooltip:SetPoint("BOTTOMLEFT", chk, "TOPLEFT", 25, 0)
	end
end

function DugisGuideViewer:SettingsTooltip_OnLeave(self, event)
	GameTooltip:Hide()
end

function DugisGuideViewer:RegisterData(uniqueDataName, getDataFunction)
    if not self.datas then
        self.datas = {}
    end

    self.datas[uniqueDataName] = getDataFunction
end   


function DugisGuideViewer:GetData(uniqueDataName)
    if self.datas and self.datas[uniqueDataName] then
        return self.datas[uniqueDataName]()
    end
    return ""
end     
     

local function ToggleConfig()
	if DugisMainBorder:IsVisible() then
		DugisGuideViewer:HideLargeWindow()
	elseif DugisGuideViewer:GuideOn() then
		--UIFrameFadeIn(DugisMainframe, 0.5, 0, 1)
		--UIFrameFadeIn(Dugis, 0.5, 0, 1)
        if InCombatLockdown() and not DugisGuideViewer.wasMainWindowShown then 
            print(L["|cff11ff11Dugi Guides: |r|cffcc0000Cannot open settings during combat.|r Please try again."]); 
            return 
        end
        
        DugisGuideViewer.wasMainWindowShown = true
		DugisGuideViewer:ShowLargeWindow()
	end
    local NPCJournalFrame = DugisGuideViewer.NPCJournalFrame
    if NPCJournalFrame and NPCJournalFrame.Update and not DugiGuidesIsLoading then
        NPCJournalFrame:Update()
    end
end

function DugisGuideViewer:ToogleAutoMount()
    local newValue = not DugisGuideViewer:UserSetting(DGV_AUTO_MOUNT)
    DugisGuideViewer:SetDB(newValue, DGV_AUTO_MOUNT)
    local ChkBox = _G["DGV.ChkBox"..DGV_AUTO_MOUNT]	
    if ChkBox then
        ChkBox:SetChecked(newValue)
    end
    DugisGuideViewer:UpdateAutoMountEnabled()
    
    if DugisGuideViewer:UserSetting(DGV_AUTO_MOUNT) then
        print(L["|cff11ff11Auto Mount is ON|r"])
    else
        print(L["|cff11ff11Auto Mount is OFF|r"])
    end   
end

SLASH_DG1 = "/dugi"
SlashCmdList["DG"] = function(msg)	
	if msg == "" then 				-- "/dg" command
		print(L["|cff11ff11/dugi way xx xx - |rPlace waypoint in current zone."])
		print(L["|cff11ff11/dugi fix - |rReset all Saved Variable setting."])
		print(L["|cff11ff11/dugi reset - |rReset all frame position."])
		print(L["|cff11ff11/dugi on - |rEnable Dugi Addon."])
		print(L["|cff11ff11/dugi off - |rDisable Dugi Addon."])
		print(L["|cff11ff11/dugi config - |rDisplay settings menu."])
		print(L["|cff11ff11/dugi automount - |rToogle Auto Mount on/off."])
	elseif msg  == "on" then
		DugisGuideViewer:TurnOn()
		DugisGuideViewer:UpdateIconStatus()
	elseif msg  == "off" then
		DugisGuideViewer:TurnOff()
		DugisGuideViewer:UpdateIconStatus()
	elseif msg  == "config" then
		ToggleConfig()
	elseif msg  == "reset" then 	--"/dg reset" command
		print(L["|cff11ff11" .. "Dugi: Frame Reset"] )
		DugisGuideViewer:InitFramePositions()
	elseif msg == "fix" then
		print(L["|cff11ff11" .. "Dugi: Cleared Saved Variables"] )
		ResetDB()
		DugisGuideViewer:InitFramePositions()
		DugisGuideViewer:ShowReloadUi()
        DugisGuideViewer.db:ResetProfile()
		--DugisGuideViewer:ReloadModules()
	elseif msg == "automount" then
		DugisGuideViewer:ToogleAutoMount()
	elseif msg == "dgr" then
		DugisGuideViewer:ShowRecord()
	elseif msg == "dgr limit" then
		DugisGuideViewer:ToggleRecordLimit()
	elseif string.find(msg, "dgr ")==1 then
		DugisGuideViewer:RecordNote(string.sub(msg, 5))	
	elseif string.find(msg, "way ")==1 then
		local x,y,zone = string.sub(msg, 5):match("%s*([%d.]+)[,%s?]+([%d.]+)%s*(.*)")
		if zone == "" then zone = DGV:GetCurrentMapID()  end
		if x and y then
			DugisGuideViewer:AddManualWaypoint(tonumber(x)/100, tonumber(y)/100, zone)
		end
	elseif msg == "way" then		
		local zone, mapFloor, x, y = DugisGuideViewer:GetPlayerPosition()
		DugisGuideViewer:AddManualWaypoint(x, y, zone, mapFloor)
	end
end

function DugisGuideViewer:RemoveParen(text)
	if text then
		local _, _, noparen = text:find("([^%(]*)")
		noparen = noparen:trim()
		
		return noparen
	end
end


function DugisGuideViewer:OnOff_OnClick(self, event)
	if event == "LeftButton" then
        if DugisGuideViewer:UserSetting(DGV_DISABLE_QUICK_SETTINGS) ~= true then
            if LibDugi_DropDownList1 and LibDugi_DropDownList1:IsVisible() then
                LibDugi_CloseDropDownMenus(1)
            else
                DugisGuideViewer.ShowMainMenu()  
            end
        else
            --Old switching
            DugisGuideViewer:ToggleOnOff()
        end
	elseif event == "RightButton" then
		ToggleConfig()
	end
end

local function SaveFramesPositions()
	if DugisGuideUser.SkipSaveFramesPosition then return end
    if DugisGuideViewer.chardb.QuestRecordTable.framePositions == nil then
        DugisGuideViewer.chardb.QuestRecordTable.framePositions = {}
    end
    LuaUtils:foreach(savablePositionsFrameNames, function(frameName)
        local framePosition = DugisGuideViewer.chardb.QuestRecordTable.framePositions[frameName]
        if framePosition == nil then
            DugisGuideViewer.chardb.QuestRecordTable.framePositions[frameName] = {}
            framePosition = DugisGuideViewer.chardb.QuestRecordTable.framePositions[frameName]
        end
        local frame = _G[frameName]
		if frame then 
			framePosition.point, framePosition.relativeTo, framePosition.relativePoint, framePosition.xOfs, framePosition.yOfs = frame:GetPoint()
			if framePosition.relativeTo then
				framePosition.relativeTo = framePosition.relativeTo:GetName()
			end
		end 
    end)
end

function UpdateLeftMenu()
    if not settingsMenuTreeGroup then return end
	if DugisGuideViewer.chardb.EssentialsMode ~= 1 then
        if settingsMenuTreeGroup.tree[1].value == "Search Locations" then
            tremove(settingsMenuTreeGroup.tree,1)
        end
        
        if settingsMenuTreeGroup.localstatus.selected == "Search Locations" then
            settingsMenuTreeGroup:SetSelected(settingsMenuTreeGroup.tree[1].value)
        end
    else
        if settingsMenuTreeGroup.tree[1].value ~= "Search Locations" then
            tinsert(settingsMenuTreeGroup.tree,1, { value = "Search Locations", text = L["Search Locations"], icon = nil })
        end
    end                
    
    settingsMenuTreeGroup:RefreshTree() 
end

function DugisGuideViewer:ToggleOnOff()
	if InCombatLockdown() then return end
	if DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode == 0 then
		SaveFramesPositions()
		DugisGuideViewer:TurnOnEssentials()
		DugisGuideViewer:RefreshQuestWatch()
	elseif DugisGuideViewer:GuideOn() then
		DugisGuideViewer:TurnOff()
	else
		DugisGuideViewer.chardb.EssentialsMode = 0
		DugisGuideViewer:TurnOn()
		--DugisGuideViewer:SettingFrameChkOnClick()
	end
	DugisGuideViewer:UpdateIconStatus()
    
   UpdateLeftMenu()
   DugisGuideViewer:UpdateAutoMountEnabled()
end

function DugisGuideViewer:TurnOnEssentials()
	if DugisGuideViewer.Modules.DugisWatchFrame then
		DugisGuideViewer.Modules.DugisWatchFrame:OnBeforeEssentialModeActive()
	end

	--In the copper mode RemoveAllWaypoints is not available (clocking it: #128)
    if DugisGuideViewer.RemoveAllWaypoints then
        DugisGuideViewer:RemoveAllWaypoints()
    end
	DugisGuideViewer.chardb.GuideOn = true
	DugisGuideViewer.chardb.EssentialsMode = 1
	DugisGuideViewer:ReloadModules()
	--DugisGuideViewer:SettingFrameChkOnClick()
	DugisGuideViewer:UpdateIconStatus()
	DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
	for i=1, 6 do 
		local itembutton = _G["DugisSmallFrameStatus"..i.."Item"]
		if itembutton then 
			DugisGuideViewer.DoOutOfCombat(itembutton.Hide, itembutton)
		end
	end
	if DugisSecureQuestButton then
		DugisSecureQuestButton:Hide()			
	end
	DugisGuideViewer:CreateSettingsTree(DugisMainBorder)
	if DugisGuideViewer:IsModuleLoaded("Target") then DugisGuideViewer.Modules.Target.Frame:Hide() end
	if DugisGuideViewer:IsModuleLoaded("ModelViewer") then DugisGuideViewer.Modules.ModelViewer.Frame:Hide() end
	DugisGuideViewer.Modules.QuestPOI:ObjectivesChangedDelay(3)
	if DugisGuideViewer_ModelViewer and DugisGuideViewer_ModelViewer:IsShown() then DugisGuideViewer_ModelViewer:Hide() end
    
    DugisGuideViewer:UpdateAutoMountEnabled()
	print(L["|cff11ff11" .. "Dugi Guides Essential Mode"] )
end

function DugisGuideViewer:TurnOff(forceOff)
	--if DugisGuideViewer.Modules.DugisWatchFrame then
		--DugisGuideViewer.Modules.DugisWatchFrame:OnBeforePluginOff()
	--end

	if not DugisGuideViewer:GuideOn() and not forceOff then return end
	print(L["|cff11ff11" .. "Dugi Guides Off"] )
	DugisGuideViewer.chardb.GuideOn = false
	DugisGuideViewer.eventFrame:UnregisterAllEvents()
	DugisGuideViewer:HideLargeWindow()
	-- if DugisGuideViewer.ModelViewer.Frame then  --not created when memory setting is restricted
	--	DugisGuideViewer.ModelViewer.Frame:Hide()
	-- end
	--DugisSmallFrameLogo:Hide()
	--DugisGuideViewer.Canvas:Hide()
	--DugisGuideViewer.DugisArrow:Disable()
	--DugisGuideViewer.Target:Disable( )
	--DugisGuideViewer.StickyFrame:Disable()
	--DugisGuideViewer.SmallFrame:Disable()
	if DugisSecureQuestButton then DugisSecureQuestButton:Hide() end
	DugisGuideViewer:ReloadModules()
    
    DugisGuideViewer:UpdateAutoMountEnabled()
end

function DugisGuideViewer:TurnOn(forceOn)
	if DugisGuideViewer:GuideOn() and not forceOn then return end
	print("|cff11ff11" .. "Dugi Guides On" )
	if not DugisGuideViewer:IsModuleRegistered("Guides") then
		DugisGuideViewer.chardb.EssentialsMode = 1
	end
	DugisGuideViewer.chardb.GuideOn = true
	DugisGuideViewer:OnInitialize()	
	--DugisGuideViewer.ModelViewer:ShowCurrentModel()
	--DugisSmallFrameLogo:Show()
	--DugisGuideViewer.Canvas:Show()
	--DugisGuideViewer.DugisArrow:Enable()
	--DugisGuideViewer.Target:Enable( )
	--DugisGuideViewer.StickyFrame:Enable()
	--DugisGuideViewer.SmallFrame:Enable()
	DugisGuideViewer:SetEssentialsOnCancelReload()
	DugisGuideViewer.chardb.GuideOn = DugisGuideViewer:ReloadModules()
	if DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode ~= 1 then DugisGuideViewer:MoveToNextQuest() end
	--DugisGuideViewer:ShowLargeWindow()
	DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()		
	DugisGuideViewer:RefreshQuestWatch()	
    
    DugisGuideViewer:UpdateAutoMountEnabled()
end

if not DugisGuideViewerDelayFrame then
	DugisGuideViewerDelayFrame = CreateFrame("Frame")
	DugisGuideViewerDelayFrame:Hide()
end

if not DugisGuideViewerDelayFrameTwo then
	DugisGuideViewerDelayFrameTwo = CreateFrame("Frame")
	DugisGuideViewerDelayFrameTwo:Hide()
end

function DugisGuideViewer.DelayandMoveToNextQuest(delay, reload, func)
	if DugisGuideViewerDelayFrame:IsShown() then return end
	DugisGuideViewerDelayFrame.func = func
	DugisGuideViewerDelayFrame.delay = delay
	DugisGuideViewerDelayFrame.reload = reload
	DugisGuideViewerDelayFrame:Show()
end

function DugisGuideViewer.DelayandSetMapToCurrentZone(delay, func)
	if DugisGuideViewerDelayFrameTwo:IsShown() then return end
	DugisGuideViewerDelayFrameTwo.func = func
	DugisGuideViewerDelayFrameTwo.delay = delay
	DugisGuideViewerDelayFrameTwo:Show()
end

DugisGuideViewerDelayFrame:SetScript("OnUpdate", function(self, elapsed)
	self.delay = self.delay - elapsed
	if self.delay <= 0 then
		self:Hide()
		if DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode ~= 1 then
			DugisGuideViewer:MoveToNextQuest(DugisGuideViewer:FindNextUnchecked())
		end
	end
end)

DugisGuideViewerDelayFrameTwo:SetScript("OnUpdate", function(self, elapsed)
	self.delay = self.delay - elapsed
	if self.delay <= 0 then
		self:Hide()
		LuaUtils:DugiSetMapToCurrentZone()
	end
end)
			

--Occurs BEFORE QuestFrameCompleteQuestButton OnClick (works with questguru, doesn't work with carbonite)
function Dugis_RewardComplete_Click()
	DebugPrint("QuestRewardCompleteButton_OnClick")
	if IsAddOnLoaded("QuestGuru") and DugisGuideViewer:isValidGuide(CurrentTitle) == true then
		DugisGuideViewer:CompleteQuest()
	end
end
hooksecurefunc("QuestRewardCompleteButton_OnClick", Dugis_RewardComplete_Click);

--Change map, show
local function OnMapUpdate()
	if HookLandMarks then
		HookLandMarks()
	end	
	
	if OverrideMapOverlays then
		OverrideMapOverlays()
	end
end

local function OnMapChangedOrOpen()
	if DGV.Modules.WorldMapTracking and DGV.Modules.WorldMapTracking.OnMapChangedOrOpen then
		DugisGuideViewer.Modules.WorldMapTracking:OnMapChangedOrOpen()
	end

	if DGV.Modules.TaxiDB and DGV.Modules.TaxiDB.OnMapChangedOrOpen then
		DugisGuideViewer.Modules.TaxiDB:OnMapChangedOrOpen()
	end
end

hooksecurefunc(WorldMapFrame, "OnMapChanged", function(...)
	OnMapUpdate()
	if DugisArrowGlobal and DugisArrowGlobal.OnMapChanged then
		DugisArrowGlobal:OnMapChanged()
	end	
	
	OnMapChangedOrOpen()
end)

WorldMapFrame:HookScript("OnShow", function(...)
	OnMapUpdate()
	OnMapChangedOrOpen()
end)

--Occurs AFTER QuestFrameCompleteQuestButton OnClick (doesn't work with questguru, works with carbonite)
QuestFrameCompleteQuestButton:HookScript("OnClick", function(...)
	DebugPrint("QuestFrameCompleteQuestButton")
	if not IsAddOnLoaded("QuestGuru") and DugisGuideViewer:isValidGuide(CurrentTitle) == true then
		DugisGuideViewer:CompleteQuest()
	end
end)

function DugisGuideViewer:OnDragStart(frame)
  if not self:UserSetting(DGV_LOCKSMALLFRAME) then
    frame:StartMoving();
    frame.isMoving = true;
  end
end

function DugisGuideViewer:OnDragStop(self)
  self:StopMovingOrSizing();
  self.isMoving = false;
end

function DugisGuideViewer:WayPoint_OnClick(frame)
	DugisGuideUser.PreviewPointx = nil
	DugisGuideUser.PreviewPointy = nil	
	local rowNum = frame:GetParent().guideIndex
	if not rowNum then
		_, _, rowNum = frame:GetName():find("DGVRow([^ ]*)WayPoint")
		rowNum = tonumber(rowNum)
	end
	DugisGuideViewer:MapCurrentObjective(rowNum, true)
	DugisGuideViewer:ShowAutoTooltip()
	DugisGuideViewer:SafeSetMapQuestId(DugisGuideViewer.qid[rowNum]);
	--if not DugisGuideViewer:IsPlayerAtBlizzardDestination() then DugisGuideViewer.MapPreview:FadeInMap() end
    
    --[[local waypointAutoroutine = DugisGuideViewer.GetRunningAutoroutine("SetSmartWaypoint")
    if waypointAutoroutine then
        waypointAutoroutine.onCompletion = function()
         HideNonWaypointPOIs()
        end
    else
        HideNonWaypointPOIs()
    end]] -- this hijack can interrupt multiple waypoints placement fix later 
    --HideNonWaypointPOIs()
end

function DugisGuideViewer:Button_OnEnter(frame)
	if CurrentTitle == nil then return end
	local rowNum = frame:GetParent().guideIndex
	if not rowNum then
		_, _, rowNum = frame:GetName():find("DGVRow([^ ]*)Button")
		rowNum = tonumber(rowNum)
	end
	if not rowNum then return end
    
    if self.visualRows and self.visualRows[rowNum] and self.visualRows[rowNum].Button then
        id = self.visualRows[rowNum].Button.tag_id
        tagType = self.visualRows[rowNum].Button.tagType
        GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
        if tagType == "item" then
            GameTooltip:SetItemByID(id)
        elseif tagType == "spell" then
            GameTooltip:SetSpellByID(id)
        elseif tagType == "aid" then
            GameTooltip:SetAchievementByID(id)
        elseif tagType == "qid" then
            GameTooltip:SetHyperlink(("quest:%s"):format(tostring(id)))	
        end
    end
end

function DugisGuideViewer:HideLargeWindow()	
	DugisMainBorder:Hide()
	--Dugis:Hide()
	LuaUtils:PlaySound("igCharacterInfoClose")
end

function DugisGuideViewer_Close_ButtonClick()
	DugisGuideViewer:HideLargeWindow()
	--DugisSmallFrameLogo:Hide()
end

--[[
function DugisGuideViewer:MinimizeDungeonMap()
	DGV_DungeonFrame:Hide()
	DugisSmallFrameMaximize:Show()
end
--]]
-- 
-- Events
--

local function PetJournalShowEvent()
    LuaUtils:foreach(PetJournal.listScroll.buttons, function(parentButton)
        if parentButton.journalFrameButton == nil then
            local sidebarButton = GUIUtils:AddButton(parentButton, "", 180, -11, 20, 20, 20, 20, function(self)  
                local petId = select(4, C_PetJournal.GetPetInfoBySpeciesID(self.journalFrameButton.speciesID))
                DugisGuideViewer.NPCJournalFrame:SetGuideData("Pets", petId, true)
            end
            , [[Interface\EncounterJournal\UI-EJ-PortraitIcon]], [[Interface\Buttons\ButtonHilight-Square]], [[Interface\AddOns\DugisGuideViewerZ\Artwork\npcjournal_button.tga]])
        
            sidebarButton.button.journalFrameButton =  parentButton
            parentButton.journalFrameButton = sidebarButton
        end
    end)
end

local function MountJournalShowEvent()
    LuaUtils:foreach(MountJournal.ListScrollFrame.buttons, function(parentButton)
        if parentButton.journalFrameButton == nil then
            local sidebarButton = GUIUtils:AddButton(parentButton, "", 180, -11, 20, 20, 20, 20, function(self)  
                DugisGuideViewer.NPCJournalFrame:SetGuideData("Mounts", self.journalFrameButton.spellID, true)
            end
            , [[Interface\EncounterJournal\UI-EJ-PortraitIcon]], [[Interface\Buttons\ButtonHilight-Square]], [[Interface\AddOns\DugisGuideViewerZ\Artwork\npcjournal_button.tga]])
        
            sidebarButton.button.journalFrameButton =  parentButton
            parentButton.journalFrameButton = sidebarButton
        end
    end)
end

local function FollowersShowEvent()
  LuaUtils:foreach(GarrisonMissionFrame.FollowerList.listScroll.buttons, function(parentButton)
      if parentButton.journalFrameButton == nil then
          local sidebarButton = GUIUtils:AddButton(parentButton, "", 230, -15, 20, 20, 20, 20, function(self)  
              local followerID = self.journalFrameButton.info.followerID
			  if type(followerID) ~= "number" then
			  	followerID = tonumber(self.journalFrameButton.info.garrFollowerID, 16) 
			end
              DugisGuideViewer.NPCJournalFrame:SetGuideData("Followers", followerID, true)
              DugisGuideViewer.NPCJournalFrame.mainFrame:SetFrameStrata("HIGH")
          end , [[Interface\EncounterJournal\UI-EJ-PortraitIcon]], [[Interface\Buttons\ButtonHilight-Square]], [[Interface\AddOns\DugisGuideViewerZ\Artwork\npcjournal_button.tga]])
      
          sidebarButton.button:SetFrameStrata("HIGH")
          sidebarButton.button:SetAlpha(0.9);
      
          sidebarButton.button.journalFrameButton =  parentButton
          parentButton.journalFrameButton = sidebarButton
      end
		if GarrisonMissionFrame.selectedTab==1 then	
			parentButton.journalFrameButton.button:Hide()
		else
			parentButton.journalFrameButton.button:Show()
		end	  
  end)    
end

local function FollowersHideEvent()
    if DugisGuideViewer.NPCJournalFrame.mainFrame then DugisGuideViewer.NPCJournalFrame.mainFrame:SetFrameStrata("MEDIUM") end
end

local followerJournalParentShowEventFirstTime = true

local function FollowerJournalParentShowEvent()
    if followerJournalParentShowEventFirstTime then
        hooksecurefunc(GarrisonMissionFrame.FollowerList, "Show", function() 
              FollowersShowEvent()
        end)
        hooksecurefunc(GarrisonMissionFrame.FollowerList, "Hide", function() 
              FollowersHideEvent()
        end)
        hooksecurefunc(GarrisonMissionFrame.FollowerTab, "Show", function() 
              FollowersShowEvent()
        end)		
        followerJournalParentShowEventFirstTime = false
    end
end


local petJournalParentShowEventFirstTime = true

local function PetJournalParentShowEvent()
    if petJournalParentShowEventFirstTime then
        if MountJournal:IsShown() then
            MountJournalShowEvent()
        end
        
        if PetJournal:IsShown() then
            PetJournalShowEvent()
        end

        hooksecurefunc(MountJournal, "SetShown", function() 
              MountJournalShowEvent()
        end)
        
        hooksecurefunc(PetJournal, "SetShown", function() 
              PetJournalShowEvent()
        end)

        petJournalParentShowEventFirstTime = false
    end
end


function DugisGuideViewer:PLAYER_LOGIN()
	if DugisGuideUser.SkipSaveFramesPosition then DugisGuideUser.SkipSaveFramesPosition = nil end
	local guid = UnitGUID("player")
	if DugisGuideUser.CharacterGUID == "PRIOR_RESET" then DugisGuideUser.CharacterGUID = guid end
	if DugisGuideUser.CharacterGUID and DugisGuideUser.CharacterGUID~=guid then
		print("|cff11ff11Dugi Guides: |rNew character detected. Wiping settings.")
		ResetDB()
		--todo: check with Fransisco why for new users EssentialsMode was 1
		--self.chardb.EssentialsMode = 1
		self:ReloadModules()
		self:SettingFrameChkOnClick()
	end
	
	--QueryQuestsCompleted()
	DugisGuideViewer:InitializeMapOverlays()
	DugisGuideViewer:InitializeQuestPOI()
    DugisGuideViewer:initAnts()
    
	hooksecurefunc("ToggleCollectionsJournal", function() 
        if CollectionsJournal:IsShown() and self:UserSetting(DGV_JOURNALFRAME) and DugisGuideViewer:IsModuleRegistered("PetDataModule") then
             PetJournalParentShowEvent()
        end
    end)    
	
	hooksecurefunc("ToggleWorldMap", function() 
		DugisGuideViewer:WatchLocalQuest()
    end)
	
	DugisGuideViewer.specializaton = GetSpecialization()
end

function DugisGuideViewer:GARRISON_MISSION_NPC_OPENED( )
	if DugisGuideViewer:IsModuleRegistered("FollowerDataModule") then
	    FollowerJournalParentShowEvent()
	end
end

function DugisGuideViewer:ACTIVE_TALENT_GROUP_CHANGED( )
    if GetSpecialization_dugis then
        self.Modules.GearAdvisor.playerClass = select(2,UnitClass("player"))
        self.Modules.GearAdvisor.playerSpec = GetSpecialization_dugis()
    end
end

function DugisGuideViewer:NAME_PLATE_UNIT_ADDED(...)
	if self.Modules.NamePlate and self.Modules.NamePlate.OnNAME_PLATE_UNIT_ADDED then self.Modules.NamePlate:OnNAME_PLATE_UNIT_ADDED(...) end
end

function DugisGuideViewer:NAME_PLATE_UNIT_REMOVED(...)
	if self.NamePlate  and self.NamePlate.OnNAME_PLATE_UNIT_REMOVED then self.NamePlate:OnNAME_PLATE_UNIT_REMOVED(...) end
end

function DugisGuideViewer:PLAYER_LOGOUT( )
    SaveFramesPositions()
end

function DugisGuideViewer:PLAYER_LEAVING_WORLD( )
    SaveFramesPositions()
end

function DugisGuideViewer:ZONE_CHANGED()
	self:Zone_OnEvent()
	DugisGuideViewer:WatchLocalQuest()
end

function DugisGuideViewer:ZONE_CHANGED_NEW_AREA()
	self:Zone_OnEvent()
	DugisGuideViewer.OnMapChangeUpdateArrow()
	--DugisGuideViewer.DugisArrow:Show()
end

function DugisGuideViewer:ZONE_CHANGED_INDOORS()
	self:Zone_OnEvent()
end

function DugisGuideViewer:MINIMAP_UPDATE_ZOOM() --MINIMAP_UPDATE_ZOOM is only event that seems to trigger when entering a mic
	DugisGuideViewer.DelayandSetMapToCurrentZone(0.5) -- This is needed to update map floor for micro dungeons
	-- the delay is is also needed because SetMapToCurrentZone() on MINIMAP_UPDATE_ZOOM doesn't work straight away.
end


function DugisGuideViewer:QUEST_DETAIL()
	DugisGuideViewer:OnQuestDetail()
end

function DugisGuideViewer:QUEST_AUTOCOMPLETE(...)
	DugisGuideViewer:OnAutoComplete(...)
	DugisGuideViewer:UpdateCompletionVisuals()
end

function DugisGuideViewer:QUEST_COMPLETE()
	DugisGuideViewer:OnQuestComplete()
	DugisGuideViewer:UpdateCompletionVisuals()
	--if DugisGuideViewer.Modules.WorldMapTracking then
		--DugisGuideViewer.Modules.WorldMapTracking:UpdateTrackingMap()
	--end	
end

local function OnQuestObjectivesComplete()
	DugisGuideViewer:PlayCompletionSound(DGV_QUESTCOMPLETESOUND)
	DugisGuideViewer:UpdateCompletionVisuals()
end

local completedLogQuests,lastCompletedLogQuests = nil, {}

local QuestLogUpdateTrigger = true

if not DugiQuestLogDelayFrame then
	DugiQuestLogDelayFrame = CreateFrame("Frame")
	DugiQuestLogDelayFrame:Hide()
end

function DugisGuideViewer:UNIT_QUEST_LOG_CHANGED(unitID) 
	DugisGuideViewer:Dugi_QUEST_LOG_UPDATE()
	DugisGuideViewer:UpdateSmallFrame()	
	--todo: test more
	if DugisGuideViewer.NamePlate then
		DugisGuideViewer.NamePlate:UNIT_QUEST_LOG_CHANGED(unitID)
	end
end 

function DugisGuideViewer:QUEST_TURNED_IN(event, ...)
    local questID = ...;
    
    if QuestUtils_IsQuestWorldQuest(questID) then
        DugisGuideViewer:CompleteQuest(questID)
    end
end

function DugisGuideViewer.QUEST_LOG_UPDATE(func)
	DugisGuideViewer:UpdateRecord()
	if DugiQuestLogDelayFrame:IsShown() then return end
	DugiQuestLogDelayFrame.func = func
	DugiQuestLogDelayFrame.delay = 1
	DugiQuestLogDelayFrame:Show()
	if DugisGuideUser.NoQuestLogUpdateTrigger and not QuestLogUpdateTrigger then 
		DugisGuideUser.NoQuestLogUpdateTrigger = nil
		return 
	else
        if FirstTime then
            DugisGuideViewer:Dugi_QUEST_LOG_UPDATE()
        end
	end	
	
	if DugisGuideViewer.NamePlate then
		DugisGuideViewer.NamePlate:QUEST_LOG_UPDATE()
	end
end

DugiQuestLogDelayFrame:SetScript("OnUpdate", function(self, elapsed)
	self.delay = self.delay - elapsed
	if self.delay <= 0 then
		self:Hide()
	end
end)

function DugisGuideViewer:Dugi_QUEST_LOG_UPDATE()
	--PATCH: If I call OnLoad from PLAYER_LOGIN, 
	--GetNumQuestLogEntries == 0 when it is not.
	--Value seems to be stable after initial QLU event
    
    LuaUtils:RunInThreadIfNeeded("Dugi_QUEST_LOG_UPDATE", function(isInThread)   
    
	if FirstTime then  
		FirstTime = nil
		DugisGuideViewer:OnLoad()

	else
		DugisGuideViewer:UpdateMainFrame(isInThread)
		QuestLogUpdateTrigger = false -- need so that UpdateMainFrame will fire on load
		local i
		lastCompletedLogQuests, completedLogQuests = completedLogQuests, lastCompletedLogQuests
		if completedLogQuests then
			wipe(completedLogQuests)
		end
		for i=1,GetNumQuestLogEntries() do
            local _, _, _, _, _, _, _, id = GetQuestLogTitle(i)
			local link = GetQuestLink(id)
			local qid = link and tonumber(link:match("|Hquest:(%d+):"))
			if qid then
				local title, _, _, _, _, questFinished = GetQuestLogTitle(i)
				local n = GetNumQuestLeaderBoards(i)
				if n>1 then
					for j=1,n do
						local text, objtype, finished = GetQuestLogLeaderBoard(j, i)
                        LuaUtils:RestIfNeeded(isInThread)
						if not finished then
							questFinished = false
						end
					end
				end
				--DugisGuideViewer:DebugFormat("QUEST_LOG_UPDATE", "qid", qid, "title", title, "questFinished", questFinished, "lastCompletedLogQuests", lastCompletedLogQuests)

				if lastCompletedLogQuests and questFinished and not tContains(lastCompletedLogQuests, qid) then
					OnQuestObjectivesComplete()

					tinsert(completedLogQuests, qid)
				elseif questFinished then
					tinsert(completedLogQuests, qid)
				end
			end
		end
		if not lastCompletedLogQuests then lastCompletedLogQuests = {} end
	end

	if DugisGuideViewer:GuideOn() then
		if DugisGuideViewer:IsModuleLoaded("DugisArrow") then
			DugisGuideViewer.DugisArrow:OnQuestLogChanged(isInThread)
		end
		
		if DugisGuideViewer:GetDB(DGV_WAYPOINTSON) and DugisGuideViewer.chardb.EssentialsMode == 1 and DugisGuideViewer:IsModuleLoaded("QuestPOI") then 
			DugisGuideViewer.Modules.QuestPOI:ObjectivesChangedDelay(3)
		end
		
		if DugisGuideViewer.chardb.EssentialsMode ~= 1 and DugisGuideViewer:UserSetting(DGV_SHOWCORPSEARROW) and UnitIsDeadOrGhost("player") then
			if DugisGuideViewer.Modules.QuestPOI.ObjectivesChangedDelay then
				DugisGuideViewer.Modules.QuestPOI:ObjectivesChangedDelay(3)
			end
		end
	end
    
    end, nil, {}, true)
    
end

function DugisGuideViewer:TRADE_SKILL_UPDATE()
end

function DugisGuideViewer:ACHIEVEMENT_EARNED()
	DugisGuideViewer:UpdateAchieveFrame()
end

function DugisGuideViewer:PLAYER_ALIVE(event, addon)
	DugisArrowGlobal.DetectTeleportUsage()
end

hooksecurefunc("ShowUIPanel", function(arg)
    if arg == TradeSkillFrame then
        if DugisGuideViewer.OnTradeSkillFrameHide then
            DugisGuideViewer.OnTradeSkillFrameHide()
        end
    end
end)

function DugisGuideViewer:ADDON_LOADED(event, addon)
	if addon == "DugisGuideViewerZ" then
		if not DugisLastPosition then
			DugisLastPosition = {}
		end

		DugisArrowGlobal.DetectTeleportUsage()
	
		self:UnregisterEvent("ADDON_LOADED")
		DugisGuideViewer:OnInitialize()
		if DugisGuideViewer:GetDB(DGV_MAPPREVIEWDURATION) > 0 then
			SetCVar("miniWorldMap", 1)
		end
        
        if DugisGuideViewer.StartScanning then
            DugisGuideViewer.StartScanning()
        end
	end

end
 
--local lastAllAchProgress = 0 -- This create stuttering issue with some character, removed for now
function DugisGuideViewer:WORLD_MAP_UPDATE(event, addon)
    lastMapUpdate = GetTime()
--[[[	
	local checkedTable = {}
	
	if DugisGuideViewer.Modules.WorldMapTracking and DugisGuideViewer.Modules.WorldMapTracking.trackingPoints then
	
		local allAchProgress = 0
		for _,point in ipairs(DugisGuideViewer.Modules.WorldMapTracking.trackingPoints) do
			local trackingType = unpack(point.args)
			local id = point.args[3]
			
			if trackingType == "A" then
				if not checkedTable[id] then
					allAchProgress = allAchProgress + DugisGuideViewer.Modules.WorldMapTracking:GetAchievementProgress(id)
					checkedTable[id] = true
				end
			end
		end
		
		if allAchProgress ~= lastAllAchProgress then
			DugisGuideViewer.Modules.WorldMapTracking:UpdateTrackingMap()
		end
		lastAllAchProgress = allAchProgress
	end
	]] -- This create stuttering issue with some character, removed for now
end

function DugisGuideViewer:UpdateIconStatus()
	local icon = DugisGuideViewer.ARTWORK_PATH.."iconbutton"
	if DugisGuideViewer:GuideOn() and DugisGuideViewer.chardb.EssentialsMode == 1 then
		icon = DugisGuideViewer.ARTWORK_PATH.."iconbutton_s"
	elseif not DugisGuideViewer:GuideOn() then
		icon = DugisGuideViewer.ARTWORK_PATH.."iconbutton_c"
	end
	DugisOnOffButton:SetNormalTexture(icon)
	if DugisGuideViewer.LDB then
		DugisGuideViewer.LDB:SetIconStatus(icon)
	end

--[[    if DugiGuidesIsLoading then
        DugisOnOffButton:Hide()
    elseif DugisGuideViewer:UserSetting(DGV_SHOWONOFF) then
        DugisOnOffButton:Show()
    end]]
end

function DugisGuideViewer:GetQuestLogIndexByQID(qid)
	local i
	for i=1,GetNumQuestLogEntries() do
		local qid2 = select(8, GetQuestLogTitle(i))
		if qid2 == qid then return i end
	end
end

function DugisGuideViewer:WatchLocalQuest()
	if not DugisGuideViewer:UserSetting(DGV_WATCHLOCALQUEST) or
	(DugisGuideViewer:UserSetting(DGV_ENABLEQW) and DugisGuideViewer:IsModuleLoaded("Guides")) then 
		return 
	end
	local i, changes
	for i=1,GetNumQuestLogEntries() do
		local hasLocalPOI = select(12, GetQuestLogTitle(i))
		if hasLocalPOI and not IsQuestWatched(i) then 
			AddQuestWatch(i)
			changes = true
		elseif not hasLocalPOI and IsQuestWatched(i) then
			RemoveQuestWatch(i)
			changes = true
		end
	end
	if changes then 
		QuestSuperTracking_ChooseClosestQuest()
	end
end

function DugisGuideViewer:GetCarboniteQuestLogIndexByQID(qid)
	if not Nx.Quest then return end
	if not Nx.Quest.CurQ then return end
	local i
	for i=1,40 do
		if Nx.Quest.CurQ[i] then
			local curq = Nx.Quest.CurQ[i];
			local qid2 = curq.QId;
			if qid2 == qid then return i end
		end
	end
end

function DugisGuideViewer:GetItemIdFromLink(link)
	--|cff9d9d9d|Hitem:7073:0:0:0:0:0:0:0:80:0|h[Broken Fang]|h|r
	if link then return tonumber(link:match(".+|Hitem:([^:]+):.+")) end
end

function DugisGuideViewer:InitFramePositions()
	if DugisGuideViewer:IsModuleLoaded("StickyFrame") then
		self.Modules.StickyFrame.Frame:ClearAllPoints()
		self.Modules.StickyFrame.Frame:SetPoint("CENTER", 225, 180)
	end

	if DugisGuideViewer:IsModuleLoaded("NPCJournalFrame") then 
		sidebarButtonFrame.ResetSidebarIconPosition() 
	end
	
	DugisMainBorder:ClearAllPoints()
	DugisMainBorder:SetPoint("CENTER", 0, 0)
	
	if DugisGuideViewer:IsModuleLoaded("DugisWatchFrame") then
		DugisGuideViewer.Modules.DugisWatchFrame:Reset()
	end

	DugisGuideViewerActionItemFrame:ClearAllPoints()
	DugisSecureQuestButton:ClearAllPoints()
	DugisOnOffButton:ClearAllPoints()
	DugisGuideViewerActionItemFrame:SetPoint("BOTTOM", DugisArrowFrame, "TOP", 10, 4)
	DugisSecureQuestButton:SetPoint("BOTTOM", DugisArrowFrame, "TOP", 10, 4)
	DugisOnOffButton:SetPoint("BOTTOM", DugisArrowFrame, "TOP", -19, 0)

	local actionShown = DugisGuideViewerActionItemFrame:IsShown()
	local questShown = DugisSecureQuestButton:IsShown()
	DugisGuideViewerActionItemFrame:Show()
	DugisSecureQuestButton:Show()

	if not actionShown then
		DugisGuideViewerActionItemFrame:Hide()
	end
	if not questShown then
		DugisSecureQuestButton:Hide()
	end
	
	if DugisGuideViewer:IsModuleLoaded("ModelViewer") then
		DugisGuideViewer.Modules.ModelViewer:ResetPosition() 
	end

	if DugisGuideViewer:IsModuleLoaded("Target") then
		self.Modules.Target.Frame:ClearAllPoints()
		self.Modules.Target.Frame:SetPoint("LEFT", "DugisGuideViewerActionItemFrame", "RIGHT", "5", "0")
		self.Modules.Target.Frame:SetPoint("LEFT", "DugisSecureQuestButton", "RIGHT", "5", "0")
	end

	if DugisGuideViewer:IsModuleLoaded("DugisArrow") then
		DugisGuideViewer.DugisArrow:ResetPosition()
	end
    
	if DugisGuideViewer:IsModuleLoaded("DugisWatchFrame") then
	    DugisGuideViewer.Modules.DugisWatchFrame:ResetWatchFrameMovable()
	end
	
	if DugisGuideViewer:IsModuleLoaded("GPSArrowModule") then
	    DugisGuideViewer.Modules.GPSArrowModule.UpdateMerged(true)
	end
	
end

local function getQuestIndexByQuestName(name)
	local i
	local numq, _ = GetNumQuestLogEntries()
	for i=1,numq do
		local title, _, _, isHeader = GetQuestLogTitle(i)
		if not isHeader then
			if name == title then
				return i
			end

		end
	end
end

function DugisGuideViewer:GetQIDFromQuestName(name)
	local logindx = getQuestIndexByQuestName(name)
	local qid
	if logindx then
		qid = select(8, GetQuestLogTitle(logindx))
	end
	return qid
end

function DugisGuideViewer:CreateFlashFrame(parent)
	local frame = CreateFrame("Frame", nil, parent)
	frame:Hide()
	local texture = frame:CreateTexture()
	texture:SetAllPoints(frame)
	texture:SetColorTexture(1, 1, 1, 0.6)
	frame:SetBackdrop( { bgFile = nil, edgeFile = DugisGuideViewer.ARTWORK_PATH.."Border-Flash.tga", tile = true, tileSize = 32, edgeSize = 10, insets = { 0, 0, 0, 0 } })
	
	local flashGroup = frame:CreateAnimationGroup()
	local flash = flashGroup:CreateAnimation("Alpha")

	--SmallFrame:ResetFloating()

	flash:SetDuration(0.4)
	flash:SetFromAlpha(1)
	flash:SetToAlpha(0)
	flash:SetSmoothing("OUT")
	flash:SetScript("OnUpdate", function(self)
		local back = frame
		--DebugPrint("progress="..progress)
		local progress = 1 - self:GetSmoothProgress()
		back:SetAlpha(progress)

		if progress == 0 then
			--if progress >= 0.25 then
			flashGroup:Stop()
            back:Hide()
		end

		if flash:IsPlaying() then
			back:Show()
		elseif flash:IsStopped() then
			back:Hide()
		end
	end)

	frame:ClearAllPoints()

	frame:SetPoint("CENTER", parent, 1, -1)
	return flashGroup, flash, frame
end

function DugisGuideViewer:UpdateCompletionVisuals(headerAnim)
	if DugisGuideViewer:IsModuleRegistered("SmallFrame") and DugisGuideViewer:IsModuleRegistered("DugisWatchFrame") and DugisGuideViewer:GuideOn() then 
		DugisGuideViewer:UpdateSmallFrame(headerAnim)
        
        if DugisGuideViewer.Modules.DugisWatchFrame.DelayUpdate then
            DugisGuideViewer.Modules.DugisWatchFrame:DelayUpdate()
        end
		
		if DugisGuideViewer.NamePlate then
			DugisGuideViewer.NamePlate:UpdateActivePlatesExtras()
		end
	end
end

function DugisGuideViewer:CollapseCurrentGuide()
    DugisGuideUser.showLeftMenuForCurrentGuide = true
end

function DugisGuideViewer:ExpandCurrentGuide()
    DugisGuideUser.showLeftMenuForCurrentGuide = false
end

function DugisGuideViewer:ToggleCurrentGuide()
   if DugisGuideUser.showLeftMenuForCurrentGuide then
        DugisGuideViewer:ExpandCurrentGuide()
   else
        DugisGuideViewer:CollapseCurrentGuide()
   end
   DugisGuideViewer:UpdateCurrentGuideExpanded()
end

function DugisGuideViewer:GetScrollBackground()
    local isSolid = DugisGuideViewer:GetDB(DGV_MAIN_FRAME_BACKGROUND) == "Solid"
    if isSolid then
        return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\bg_home_solid"
    else
        return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\bg_home"
    end
end

function DugisGuideViewer:GetScrolllesBackground()
    local isSolid = DugisGuideViewer:GetDB(DGV_MAIN_FRAME_BACKGROUND) == "Solid"
    if isSolid then
        return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\bg_currentguide_solid"
    else
        return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\bg_currentguide"
    end
end

function DugisGuideViewer:MainFrameBackgroundOnChange()
    local isSolid = DugisGuideViewer:GetDB(DGV_MAIN_FRAME_BACKGROUND) == "Solid"
    if isSolid then
        DugisMainBorder.bg:SetTexture("Interface\\FrameGeneral\\UI-Background-Marble")
    end
end

function DugisGuideViewer:UpdateCurrentGuideExpanded()
    if DugisGuideUser.showLeftMenuForCurrentGuide == nil then
        DugisGuideUser.showLeftMenuForCurrentGuide = true
    end
    
    local shouldShowExpandButton = (DugisMainCurrentGuideTab:GetButtonState() == "DISABLED" and DugisGuideViewer.CurrentTitle ~= nil)

    if not shouldShowExpandButton then
        CurrentGuideExpandButton:Hide()
        
        if DugisGuideViewer.currentTabText == "Settings" then
            DugisMainRightFrameHost:SetPoint("TOPLEFT", DugisMain, -9, -49)
            DugisMainBorder.bg:SetTexture(DugisGuideViewer:GetScrolllesBackground())
            
            DugisMainLeftScrollFrame.bar:Hide()
        end

        return
    else
        CurrentGuideExpandButton:Show()
    end
    
    if DugisGuideViewer.visualRows == nil or DugisGuideViewer.visualRows[DugisGuideUser.CurrentQuestIndex] == nil then
        return
    end    

    local highlightedRowTexture = DugisGuideViewer.visualRows[DugisGuideUser.CurrentQuestIndex]:GetNormalTexture();
    
    if DugisGuideUser.showLeftMenuForCurrentGuide then
        DugisMainBorder.bg:SetTexture(DugisGuideViewer:GetScrollBackground())
        
        DugisMainLeftScrollFrame:Show()
        DugisMainLeftScrollFrame.bar:Show()
        DugisMainRightFrameHost:SetPoint("TOPLEFT", DugisMain, 395 - 15, -44)
        CurrentGuideExpandButton:SetPoint("BOTTOMLEFT", DugisMainRightFrameHost, -92 + 30, -1)
        CurrentGuideExpandButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up");
        CurrentGuideExpandButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down");
        CurrentGuideExpandButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled");
        if highlightedRowTexture then
            highlightedRowTexture:SetTexCoord(0, 2, 0, 1)
        end
        
        guidesMainScroll.frame:Show()
    else
        DugisMainBorder.bg:SetTexture(DugisGuideViewer:GetScrolllesBackground())
        
        DugisMainLeftScrollFrame:Hide()
        guidesMainScroll.frame:Hide()
        DugisMainRightFrameHost:SetPoint("TOPLEFT", DugisMain, 8, -44)
        DugisMainLeftScrollFrame:Hide()
        CurrentGuideExpandButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up");
        CurrentGuideExpandButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down");
        CurrentGuideExpandButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled");
        CurrentGuideExpandButton:SetPoint("BOTTOMLEFT", DugisMainRightFrameHost, 280 + 30 , -1)
        if highlightedRowTexture then
            highlightedRowTexture:SetTexCoord(0, 1, 0, 1)
        end
    end
    
    DugisGuideViewer:UpdateStepNumbersPositions()
end

local lastTime = GetTime()
function DugisGuideViewer:PlayCompletionSound(soundSetting)
	local now = GetTime()
	--DugisGuideViewer:DebugFormat("PlayCompletionSound", "lastTime", lastTime, "now", now, "sound", DugisGuideViewer:GetDB(soundSetting))
	if now-lastTime > 2 then
		PlaySoundFile(DugisGuideViewer:GetDB(soundSetting))
	end
	lastTime = now
end

local lastCUFire
function DugisGuideViewer:CRITERIA_UPDATE()
	local elapsed = GetTime()
	if lastCUFire==elapsed then return end
	lastCUFire = elapsed
	DugisGuideViewer:Guide_CRITERIA_UPDATE()
end


function DugisGuideViewer.TableAppend(t, ...)
	local n = select("#", ...)
	for i=1,n do
		tinsert(t, (select(i, ...)))
	end
end

function DugisGuideViewer:PET_BATTLE_OPENING_START()
	if self:UserSetting(DGV_SHOWONOFF) == true then	DugisOnOffButton:Hide() end
	if DugisGuideViewer:GuideOn() then 
		--DugisGuideViewer:TurnOff()
		if DugisGuideViewer:IsModuleLoaded("SmallFrame") then 
			DugisGuideViewer.Modules.SmallFrame.Frame:Hide()
			DugisGuideViewer.Modules.SmallFrame.collapseHeader.MinimizeButton:Hide()
		end
		if DugisGuideViewer:UserSetting(DGV_WATCHFRAMEBORDER) then
			ObjectiveFrameDugiBkg:Hide()
		end 		
		if DugisGuideViewer:IsModuleLoaded("DugisArrow") and DugisGuideViewer.Modules.DugisArrow.waypoints then
			DugisArrowFrame:Hide()
		end	
		if DugisGuideViewer:IsModuleLoaded("Target") and DugisGuideViewer.CurrentTitle then
			DugisGuideViewer.Modules.Target.Frame:Hide()
			DugisGuideViewerActionItemFrame:Hide()
			DugisSecureQuestButton:Hide()			
		end
		if DugisGuideViewer:IsModuleLoaded("ModelViewer") then
			DugisGuideViewer.Modules.ModelViewer.Frame:Hide()
		end
		if DugisGuideViewer:IsModuleLoaded("GPSArrowModule") and DugisGuideViewer.Modules.GPSArrowModule.ShuldBeGPSShown() then 
			GPSArrowScroll:Hide()
			GPSArrowTab:SetAlpha(0)
		end
		DugisGuideViewer:UpdateIconStatus()
	end
	DugisGuideUser.PetBattleOn = true
	DugisGuideViewer:RegisterEvent("PET_BATTLE_OVER")
end

function DugisGuideViewer:PET_BATTLE_OVER()
	DugisGuideUser.PetBattleOn = false
	if self:UserSetting(DGV_SHOWONOFF) then	DugisOnOffButton:Show() end
	if DugisGuideViewer:GuideOn() then
		if DugisGuideViewer:IsModuleLoaded("SmallFrame") then
			DugisGuideViewer.Modules.SmallFrame.Frame:Show()
			DugisGuideViewer.Modules.SmallFrame.collapseHeader.MinimizeButton:Show()
		end
		if DugisGuideViewer:UserSetting(DGV_WATCHFRAMEBORDER) then
			ObjectiveFrameDugiBkg:Show()
		end 
		if DugisGuideViewer:IsModuleLoaded("DugisArrow") and DugisGuideViewer.Modules.DugisArrow.waypoints and DugisGuideViewer:UserSetting(DGV_DUGIARROW) then
			DugisArrowFrame:Show()
		end

		if DugisGuideViewer:IsModuleLoaded("Target") and DugisGuideViewer.CurrentTitle then
			DugisGuideViewer:FinalizeTarget()		
		end
		if DugisGuideViewer:IsModuleLoaded("ModelViewer") then
			DugisGuideViewer.Modules.ModelViewer:Finalize()
		end		
		if DugisGuideViewer:IsModuleLoaded("GPSArrowModule") and DugisGuideViewer.Modules.GPSArrowModule.ShuldBeGPSShown() then 
			GPSArrowScroll:Show()
		end		
		--DugisGuideViewer:TurnOn()
		DugisGuideViewer:UpdateIconStatus()
	end
	DugisGuideViewer:UnregisterEvent("PET_BATTLE_OVER")
end

--2656
--/script DugisGuideViewer:isLearnedSpell(2656)
function DugisGuideViewer:isLearnedSpell(spellIdToCheck)
    local allButtons = {}
    allButtons[1] = PrimaryProfession1.button1
    allButtons[2] = PrimaryProfession1.button2    
    allButtons[3] = PrimaryProfession2.button1
    allButtons[4] = PrimaryProfession2.button2
    allButtons[5] = SecondaryProfession1.button1
    allButtons[6] = SecondaryProfession1.button2    
    allButtons[7] = SecondaryProfession2.button1
    allButtons[8] = SecondaryProfession2.button2    
    allButtons[9] = SecondaryProfession3.button1
    allButtons[10] = SecondaryProfession3.button2    
    allButtons[11] = SecondaryProfession4.button1
    allButtons[12] = SecondaryProfession4.button2
    
    local isLearned = false
    
    LuaUtils:foreach(allButtons, function(button)
        local parent =  button:GetParent()
        if parent ~= nil then
            local spellIndex = button:GetID() + (parent.spellOffset or 0)
            local texture = GetSpellBookItemTexture(spellIndex, SpellBookFrame.bookType)
            local spellName, subSpellName = GetSpellBookItemName(spellIndex, SpellBookFrame.bookType)
            local skillType, spellId = GetSpellBookItemInfo(spellIndex, SpellBookFrame.bookType) --or GetSpellBookItemInfo(spellName)
            local name, rank, icon, castingTime, minRange, maxRange, spellID = GetSpellInfo(spellId)
            local isShown = button:IsShown()
            if tonumber(spellId) == tonumber(spellIdToCheck) and isShown then
                isLearned = true
            end
        end
        
    end)
    return isLearned
end

--Returns structure for SetTreeData
function DugisGuideViewer:GetLocationsAndPortalsByText(text)
    local nodes = {}
    
    local onClickFunction = function(node)
            DugisGuideViewer:RemoveAllWaypoints()
            local data = node.nodeData.data
            if data.isPortal == true then
                DugisGuideViewer:AddCustomWaypoint(data.x, data.y, L["Portal "] .. data.mapName, data.mapId, data.f)      
            else
                local mapId = DugisGuideViewer:GetMapIDFromName(data.zone)
                DugisGuideViewer:AddCustomWaypoint(data.x / 100, data.y / 100, data.subzoneName, mapId, 0)      
            end
            SettingsSearch_SearchBox:SetAutoFocus(false)
            SettingsSearch_SearchBox:ClearFocus()            
        end
    
    local achevementsByLocation = searchAchievementWaypointsByMapName(text)   
    LuaUtils:foreach(achevementsByLocation, function(coordinates, areaName)
        local mapId = self:GetMapIDFromName(areaName)
        
        local localizedMapName
        
        if tonumber(mapId) then
            localizedMapName =  DGV:GetMapNameFromID(mapId)
        else
            localizedMapName =  mapId
        end
        
        nodes[#nodes+1] = {name = DugisLocals["Locations in"].. " " .. (localizedMapName or areaName), nodes = {}}
        LuaUtils:foreach(coordinates, function(value)
            local nodes = nodes[#nodes].nodes
            nodes[#nodes + 1] = {name = value.subzoneName or "", data = value, isLeaf = true, shownWaypointMark = true,
                onMouseClick = onClickFunction
            }
        end)
    end)
    
    --Searching for portals
    local portalNodeAlreadyAdded = false
    for mapId, value in pairs(self.Modules.TaxiData.InstancePortals) do
       local id_coord_aId_critIndex = LuaUtils:split(value, ":")
       local coordinates = id_coord_aId_critIndex[2]
        
       local destMapIdString, destFloorString, destLocString, sourceMapIdString, sourceFloorString, sourceLocString = strsplit(":", value)
       local mPort,fPort,xPort,yPort =  tonumber(destMapIdString), tonumber(destFloorString),  self:UnpackXY(destLocString)
    
       local mapName = DGV:GetMapNameFromID(mapId)
       local searchKey = strupper(text)
       
       if strupper(mapName):match(searchKey) then
           if not portalNodeAlreadyAdded then
               nodes[#nodes+1] = {name = DugisLocals["Instance Portal"], nodes = {}}
           end
           portalNodeAlreadyAdded = true
           
           local nodes = nodes[#nodes].nodes
           nodes[#nodes + 1] = {name = mapName, isLeaf = true, data = {mapName = mapName, x=xPort, y=yPort, mapId = mapId, f = fPort, isPortal = true}
           , shownWaypointMark = true, onMouseClick = onClickFunction}
       end
    end
    
    return nodes
end

if LibDugi_UIDROPDOWNMENU_MAXLEVELS then
    for i = 1, LibDugi_UIDROPDOWNMENU_MAXLEVELS do 
        local listFrameName = "LibDugi_DropDownList"..i
        if _G[listFrameName] then
            _G[listFrameName]:SetFrameStrata("TOOLTIP")
        end
    end
end

CreateFrame("GameTooltip", "DugisGuideTooltip", UIParent, "GameTooltipTemplate")
DugisGuideTooltip:SetFrameStrata("TOOLTIP")

--This function takes into account if user us currently swemming 
--Returns not exactly speed but speed "weight" 
function DugisGuideViewer:GetMountSpeed(mountId)
    local _, _, _, _, isUsable, _, isFavorite, _, _, _, isCollected, mountID = C_MountJournal.GetMountInfoByID(mountId)
    local _, _, _, _, mountTypeId = C_MountJournal.GetMountInfoExtraByID(mountId)
    
    --Skip if cannot be mounted or is not owned
    if not isUsable or not isCollected then
        return nil
    end
    
    local isInWater = IsSubmerged() or IsSwimming()
    local isFlayableArea = IsFlyableArea() and not isInWater
    local isNoneFlayableArea = not IsFlyableArea() and not isInWater
    
    local speed = 0
    
    local namedMountType = DugisGuideViewer:GetNamedMountType(mountTypeId)
    
    if isFlayableArea then
        local preferedMount =  DugisGuideViewer.chardb["prefered-auto-mount-flying"]
      
        if preferedMount == mountId then
            speed = 5
        else
            local type2speed_map = {flying = 4, ground = 3, aquatic = 2, other = 1}
            speed = type2speed_map[namedMountType]
        end
        
        if preferedMount == "none" then
            speed = nil
        end        
    end
    
    if isNoneFlayableArea then
   
        local preferedMount =  DugisGuideViewer.chardb["prefered-auto-mount-ground"]
        
        if preferedMount == mountId then
            speed = 5
        else
            local type2speed_map = {flying = 3, ground = 4, aquatic = 2, other = 1}
            speed = type2speed_map[namedMountType]
        end
        
        if preferedMount == "none" then
            speed = nil
        end        
    end
    
    if isInWater then
        local preferedMount =  DugisGuideViewer.chardb["prefered-auto-mount-aquatic"]
        
        if preferedMount == mountId then
            speed = 5
        else
            local type2speed_map = {flying = 3, ground = 2, aquatic = 4, other = 1}
            speed = type2speed_map[namedMountType]
        end
        
        if preferedMount == "none" then
            speed = nil
        end
    end

    --If two mounts have the same speed it will pick the favourite one
    if isFavorite and speed ~= nil then
        speed = speed + 0.1
    end

    return speed
end


--This function takes into account currently mounted mount
--mountTypeFilter:  "ground", "flying", "aquatic"
function DugisGuideViewer.GetTheFastestMount()
    local theFastestMountIds = {}
    local theHighestSpeed
    
    LuaUtils:foreach(C_MountJournal.GetMountIDs(), function(mountId)
    
        local _, _, _, _, mountType = C_MountJournal.GetMountInfoExtraByID(mountId)
        local _, _, _, _, isUsable, _, _, _, _, _, isCollected, _ = C_MountJournal.GetMountInfoByID(mountId)
        
        if isUsable and isCollected then
            
            local speed = DugisGuideViewer:GetMountSpeed(mountId)
            
            if speed and (theHighestSpeed == nil or speed >= theHighestSpeed) then
            
                if theHighestSpeed and speed > theHighestSpeed then
                    theFastestMountIds = {}
                end
                theFastestMountIds[#theFastestMountIds + 1] = mountId
                theHighestSpeed = speed
            end
        end
    end)
    
    return theFastestMountIds, theHighestSpeed
end

local function IsCasting()
    local name, nameSubtext, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo("player");
    return name ~= nil
end

local function IsLootFrameOpenend()
    return GetNumLootItems() > 0
end

local isInCombat = UnitAffectingCombat("player")
local lastCombatTime = GetTime()
local lastCastingNoneMountTime = GetTime()
local lastCastingMountTime = GetTime()
local lastMountedTime = GetTime()
local lastMovingTime = GetTime()

local mountId2exists = {}

LuaUtils:foreach(C_MountJournal.GetMountIDs(), function(mountId)
    local _, spellID = C_MountJournal.GetMountInfoByID(mountId)
    mountId2exists[spellID] = true
end)

local function IsMountSpell(spellID)
    return mountId2exists[spellID]
end

local function IsCastingNonMountSpell()
    local spellID = select(10, UnitCastingInfo("player"))  
    return spellID and not IsMountSpell(spellID)
end

function DugisGuideViewer:OnCastingSpell(spellID)
    if spellID and not IsMountSpell(spellID) then
	    if tonumber(spellID) ~= 219223 and tonumber(spellID) ~= 219222 and tonumber(spellID) ~= 197886 and tonumber(spellID) ~= 240022 -- Hunter Windrunning spell effect from Marksman Artifact Bow
		and tonumber(spellID) ~= 241330 and tonumber(spellID) ~= 242597 and tonumber(spellID) ~= 242599 and tonumber(spellID) ~= 242601 -- Rethu's Incessant Courage from Legendary
		and tonumber(spellID) ~= 241835 and tonumber(spellID) ~= 241334 and tonumber(spellID) ~= 242600 and tonumber(spellID) ~= 241836 --Starlight of Celumbra priest legendary
		then   
	        lastCastingNoneMountTime = GetTime()
		end
    end
end

local function IsCastingMountSpell()
    local spellID = select(10, UnitCastingInfo("player"))  
    return spellID and IsMountSpell(spellID)
end

local function WasCastingNoneMount()
    local delay = DugisGuideViewer:GetDB(DGV_MOUNT_DELAY)
    return (GetTime() - lastCastingNoneMountTime) <= delay
end

local function IsUsingSpecialBuff()
    local n1, n2 = UnitBuff("player", 1), UnitDebuff("player", 1)
    local i = 1
    
    while n1 or n2 do
        local name1, icon1, count, _, _, _, _, _, _, spellID = UnitBuff("player", i)
        local name2, icon2, count, _, _, _, _, _, _, spellID = UnitDebuff("player", i) 
        
        n1 = name1
        n2 = name2
		
		if (icon1 and icon1 == 774121) --inv_misc_fishing_raft
		or (icon2 and icon2 == 774121) --inv_misc_fishing_raft
		or (icon1 and icon1 == 134062) --inv_misc_fork&knife
		or (icon1 and icon1 == 132293) --ability_rogue_feigndeath
		or (icon1 and icon1 == 132320) --ability_stealth
		or (icon1 and icon1 == 266311) --ability_hunter_pet_raptor curse of jani
		or (icon1 and icon1 == 132805) then --inv_drink_18
            return true
        end
       
        i = i + 1
    end
end

local function IsFeignDeath()
	local mirrortimer = GetMirrorTimerInfo(3) == "FEIGNDEATH"
	if UnitIsFeignDeath("player") then
		return true 
	end 
       if mirrortimer == true then 
		return true
	end
end

local function IsShapeShift()
	if GetShapeshiftForm() == 1 then 
		if select(2, UnitClass("player")) == "SHAMAN" or select(2, UnitClass("player")) == "DRUID" then 
			return true 
		end
	end
end

local function MountTheFastestMount()
    --Preventing dropping from the height and  checking if player is not moving to allow mount
    if IsFlying() or IsPlayerMoving() or IsIndoors() 
       or IsMounted()
       or UnitIsDead("player") or UnitIsGhost("player")
       or C_PetBattles.IsInBattle() or UnitOnTaxi("player")
       or IsShapeShift()
       or (LootFrame and LootFrame:IsVisible()) 
       or IsCasting() or IsLootFrameOpenend() 
       or (GetTime() - lastCombatTime) <= 1
       or UnitInVehicle("player") or UnitUsingVehicle("player")
       or WasCastingNoneMount() 
       or (GetTime() - lastCastingMountTime) <= 4
       or (CastingBarFrame and CastingBarFrame:IsVisible())
       or (SpellBookProfessionFrame and SpellBookProfessionFrame:IsVisible()) 
       --For few first hundred milliseconds IsFlyableArea is not correct for example after leaving dungeon.
       or (GetTime() - lastMapUpdate) <= 1  
       or UnitAffectingCombat("player")
       or (GetTime() - lastMountedTime) <= 1
       or (GetTime() - lastMovingTime) <= 0.4
       or IsUsingSpecialBuff()
       or IsFeignDeath()
       or IsFalling() then 
        return 
    end

    local theFastestMountIds, theHighestSpeed = DugisGuideViewer.GetTheFastestMount()
    
    if #theFastestMountIds > 0  then
        local randomIndex = math.random(1, #theFastestMountIds)
        C_MountJournal.SummonByID(theFastestMountIds[randomIndex])
    end
end

local autoMountTicker = nil

local function CancelAutoMountingIfNeeded()
    if IsLootFrameOpenend() and not IsFlying() and not IsMounted() then
        C_MountJournal.Dismiss()
    end
end

function DugisGuideViewer:UpdateAutoMountEnabled()
    if DugisGuideViewer:UserSetting(DGV_AUTO_MOUNT) and DugisGuideViewer:GuideOn() then
        if not autoMountTicker then
            autoMountTicker = C_Timer.NewTicker(0.5, function()
            
                if IsCastingNonMountSpell() then
                    lastCastingNoneMountTime = GetTime()
                end     
                
                if IsMounted() then
                    lastMountedTime = GetTime()
                end    
                
                if IsPlayerMoving() then
                    lastMovingTime = GetTime()
                end
                
                if IsCastingMountSpell() then
                    lastCastingMountTime = GetTime()
                end
            
                if UnitAffectingCombat("player") then
                    lastCombatTime = GetTime()
                end
            
                CancelAutoMountingIfNeeded()
                MountTheFastestMount()
            end) 
        end
    else
        if autoMountTicker then
            autoMountTicker:Cancel()
            autoMountTicker = nil
        end
    end
end

function DugisGuideViewer.ClickedMenuItem(settingsId, itemInfo)
    local checked = itemInfo.checked
    
    if settingsId == DGV_AUTO_MOUNT
    or settingsId == DGV_AUTOEQUIPSMARTSET
    or settingsId == DGV_AUTOQUESTACCEPT
    or settingsId == DGV_AUTOFLIGHTPATHSELECT
    or settingsId == DGV_ENABLED_GPS_ARROW
    or settingsId == DGV_ENABLED_MAPPREVIEW
    or settingsId == DGV_NAMEPLATES_TRACKING then
        local newValue = not DugisGuideViewer:GetDB(settingsId)
    
        if settingsId == DGV_AUTOQUESTACCEPT then
            newValue = not (DugisGuideViewer:GetDB(settingsId) and DugisGuideViewer:GetDB(DGV_AUTOQUESTTURNIN))
        end
    
        DugisGuideViewer:SetDB(newValue, settingsId)
        DugisGuideViewer:UpdateAutoMountEnabled()
        
        --Updating checkbox in settings
        DugisGuideViewer.UpdateSettingsCheckbox(settingsId)
        
    end
	
	if  settingsId == DGV_NAMEPLATES_TRACKING then
		if DugisGuideViewer.NamePlate then
			DugisGuideViewer.NamePlate:UpdateActivePlatesExtras()
		end
	end

	if settingsId == DGV_AUTOEQUIPSMARTSET then
	
		local orderedListContainer = _G["DGV_OrderedListContainer"..DGV_GAWINCRITERIACUSTOM]
	
		if not DugisGuideViewer:GetDB(DGV_AUTOEQUIPSMARTSET) then
			--Saving the original valu for DGV_GASMARTSETTARGET:
			DugisGuideUser.lastDGV_GASmartSetTargetValue = DugisGuideViewer:GetDB(DGV_GASMARTSETTARGET)
			
			DugisGuideViewer.SmartSetTargetOnClick("None")
			
			if MainDugisMenuFrame:IsVisible() and ((DugisGuideViewer.SettingsTree or {}).localstatus or {}).selected == "Gear Set" then
				DugisGuideViewer:ForceAllSettingsTreeCategories()
			end
			
			--Saving Loot Suggestions Priorities 
			DugisGuideUser.lastDGV_DGV_GAWinCriteriaCustomValue = DugisGuideViewer.chardb[DGV_GAWINCRITERIACUSTOM].options
			
			--Remove all Loot Suggestions Priorities
			DugisGuideViewer.chardb[DGV_GAWINCRITERIACUSTOM].options = {}
			if orderedListContainer then
				DugisGuideViewer:UpdateOrderedListView(DGV_GAWINCRITERIACUSTOM, orderedListContainer:GetChildren())
			end
		else
			--Restoring original DGV_GASMARTSETTARGET
			if DugisGuideUser.lastDGV_GASmartSetTargetValue then
				DugisGuideViewer.SmartSetTargetOnClick(DugisGuideUser.lastDGV_GASmartSetTargetValue)
				if MainDugisMenuFrame:IsVisible() and ((DugisGuideViewer.SettingsTree or {}).localstatus or {}).selected == "Gear Set" then
					DugisGuideViewer:ForceAllSettingsTreeCategories()
				end
				
				DugisGuideUser.lastDGV_GASmartSetTargetValue = nil
			end
			
			--Restoring original DGV_GAWINCRITERIACUSTOM
			if DugisGuideUser.lastDGV_DGV_GAWinCriteriaCustomValue then
				DugisGuideViewer.chardb[DGV_GAWINCRITERIACUSTOM].options = DugisGuideUser.lastDGV_DGV_GAWinCriteriaCustomValue
				if orderedListContainer then
					DugisGuideViewer:UpdateOrderedListView(DGV_GAWINCRITERIACUSTOM, orderedListContainer:GetChildren())
				end
				
				DugisGuideUser.lastDGV_DGV_GAWinCriteriaCustomValue = nil
			end
		end
	end
	
    if settingsId == DGV_AUTOQUESTACCEPT then
        DugisGuideViewer:SetDB(DugisGuideViewer:GetDB(settingsId), DGV_AUTOQUESTTURNIN)
        DugisGuideViewer.UpdateSettingsCheckbox(DGV_AUTOQUESTTURNIN)
    end
    
    if settingsId == "guide-mode" then
        if checked then
            DugisGuideViewer.chardb.EssentialsMode = 0
            DugisGuideViewer:TurnOn(true)
        end
    end
    
    if settingsId == "essential-mode" then
        if checked then
            SaveFramesPositions()

            DugisGuideViewer:TurnOnEssentials()
            DugisGuideViewer:RefreshQuestWatch()
        end
    end   
    
    if settingsId == "off-mode" then
        if checked then
            DugisGuideViewer.chardb.EssentialsMode = 0
            DugisGuideViewer:TurnOff(true)
        end
    end
    
    LibDugi_UIDropDownMenu_Refresh(MainDugisMenuFrame)
end

function DugisGuideViewer.GetPluginMode()
    local isGuideMode = DugisGuideViewer:GuideOn() == true and DugisGuideViewer.chardb.EssentialsMode == 0
    local isEssentialMode = DugisGuideViewer.chardb.EssentialsMode == 1
    local isOffMode = isGuideMode ~= true and not isEssentialMode
    
    return isGuideMode, isEssentialMode, isOffMode
end


function DugisGuideViewer.RefreshMainMenu()
    if LibDugi_DropDownList1:IsShown() then
        DugisGuideViewer.ShowMainMenu()
    end
end

local function HideMainMenuOnOtherDropDowns()
	local button = _G["LibDugi_DropDownList1Button1"]; 
	if button then
		local text = button:GetText()
		if text ~= "Addon" and not DugisGuideViewer.showInProgress then
			DugisGuideViewer.NotificationsHeaderParent:Hide()
			DugisGuideViewer:HideNotifications()
		end
	end
end

function DugisGuideViewer.ShowMainMenu()

	DugisGuideViewer.showInProgress = true

    local clickCallback = DugisGuideViewer.ClickedMenuItem
    local height = DugisGuideViewer:ShowNotifications(LibDugi_DropDownList1, {dX = 8, dY = -8})
	
	if not LibDugi_DropDownList1.notificationHideHooked then
		LibDugi_DropDownList1:HookScript("OnHide", function()
			if not DugisGuideViewer.showInProgress then
				DugisGuideViewer:HideNotifications()
			end
		
			HideMainMenuOnOtherDropDowns()
		end)

	
		LibDugi_DropDownList1:HookScript("OnShow", function(a,b,c,d)
			HideMainMenuOnOtherDropDowns()
		end)
		
		LibDugi_DropDownList1.notificationHideHooked = true		
	end
    
    local menu = {
        {text = L["Addon"], isTitle = true, isNotRadio = true, notCheckable = true},
        
        {text = L["Guide Mode"],     keepShownOnClick = true, checked = function() return select(1, DugisGuideViewer.GetPluginMode()) end,     func = function(itemInfo) clickCallback("guide-mode", itemInfo)      end},
        {text = L["Essential Mode"], keepShownOnClick = true, checked = function() return select(2, DugisGuideViewer.GetPluginMode()) end, func = function(itemInfo) clickCallback("essential-mode", itemInfo)  end},
        {text = L["Off Mode"],       keepShownOnClick = true, checked = function() return select(3, DugisGuideViewer.GetPluginMode()) end,       func = function(itemInfo) clickCallback("off-mode", itemInfo)        end},
        
        {text = L["Quick Settings"], isTitle = true, isNotRadio = true, notCheckable = true},
        
        {text = L["Auto Mount"], isNotRadio = true, keepShownOnClick = true, checked = function() return DugisGuideViewer:UserSetting(DGV_AUTO_MOUNT) end
        , func = function(itemInfo) clickCallback(DGV_AUTO_MOUNT, itemInfo) end},
        
        {text = L["Gear Advisor"], isNotRadio = true, keepShownOnClick = true, checked = function() return DugisGuideViewer:UserSetting(DGV_AUTOEQUIPSMARTSET) end
        , func = function(itemInfo) clickCallback(DGV_AUTOEQUIPSMARTSET, itemInfo) end},
        
        {text = L["Auto Quest Accept/Turn in"], isNotRadio = true, keepShownOnClick = true, checked = function() 
        return DugisGuideViewer:UserSetting(DGV_AUTOQUESTACCEPT) and DugisGuideViewer:UserSetting(DGV_AUTOQUESTTURNIN) end
        , func = function(itemInfo) clickCallback(DGV_AUTOQUESTACCEPT, itemInfo) end},
        
        {text = L["Map Preview"], isNotRadio = true, keepShownOnClick = true, checked = function() return DugisGuideViewer:UserSetting(DGV_ENABLED_MAPPREVIEW) end
        , func = function(itemInfo) clickCallback(DGV_ENABLED_MAPPREVIEW, itemInfo) end},
        
        {text = L["Auto Select Flight Path"], isNotRadio = true, keepShownOnClick = true, checked = function() return DugisGuideViewer:UserSetting(DGV_AUTOFLIGHTPATHSELECT) end
        , func = function(itemInfo) clickCallback(DGV_AUTOFLIGHTPATHSELECT, itemInfo) end},
		
		{text = L["Dugi Zone Map"], isNotRadio = true, keepShownOnClick = true, checked = function() return DugisGuideViewer:UserSetting(DGV_ENABLED_GPS_ARROW) end
        , func = function(itemInfo) clickCallback(DGV_ENABLED_GPS_ARROW, itemInfo) end},
        		
		{text = L["Nameplates Tracking"], isNotRadio = true, keepShownOnClick = true, checked = function() return DugisGuideViewer:UserSetting(DGV_NAMEPLATES_TRACKING) end
        , func = function(itemInfo) clickCallback(DGV_NAMEPLATES_TRACKING, itemInfo) end},
        
        {text = L["More settings.."], isNotRadio = true, notCheckable = true
        , disabled = function()
            return not DugisGuideViewer:GuideOn()
        end
        , func = function(itemInfo) 
            if not DugisMainBorder:IsVisible() then
                ToggleConfig()
            end
            if DugisMain and DugisMain.settingsTab and DugisGuideViewer.DeselectTopTabs then
                DugisMain.settingsTab:Click()
            end
        end},
        
        {text = L["Home"], isNotRadio = true, notCheckable = true
        , disabled = function()
            return not DugisGuideViewer:GuideOn() or DugisGuideViewer.chardb.EssentialsMode == 1
        end
        , func = function(itemInfo) 
            if not DugisMainBorder:IsVisible() then
                ToggleConfig()
            end
            if DugisMain and DugisMain.homeTab then
                DugisMain.homeTab:Click()
            end
        end}      
    }
    
    if not DugisGuideViewer:IsModuleRegistered("Guides") then
        LuaUtils:foreach(menu, function(item, index)
            if item.text == L["Guide Mode"] then
                tremove(menu, index)
            end
        end)
        
        LuaUtils:foreach(menu, function(item, index)
            if item.text == L["Home"] then
                tremove(menu, index)
            end
        end)
    end

    LuaUtils:foreach(menu, function(item)
        item.dY = -height + 5
    end)
    
    if not MainDugisMenuFrame then
        CreateFrame("Frame", "MainDugisMenuFrame", UIParent, "UIDropDownMenuTemplate")
    end
    
    LibDugi_EasyMenu(menu, MainDugisMenuFrame, DugisOnOffButton, 30 , -3, "MENU", nil, {extraHeight = height - 10})
    LibDugi_DropDownList1:SetClampedToScreen(true)
    
    if LuaUtils:IsElvUIInstalled() or Tukui then
       LuaUtils:TransferBackdropFromElvUI()
    end
	
	DugisGuideViewer.showInProgress = false
end

--Potentially used teleport
hooksecurefunc("UseAction", function(index, b, c, d) 
	--Saving current map id
	--todo
	--DugisLastPosition.z, DugisLastPosition.f = GetCurrentMapZone(), GetCurrentMapDungeonLevel()
end)
