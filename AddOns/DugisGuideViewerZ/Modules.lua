	--Module support functions and global utility stubs
local DGV = DugisGuideViewer
local L = DugisLocals

DGV.Modules = {}
local _

--By default DugiGuidesIsLoading is set to true because the game is loading from the begining
DugiGuidesIsLoading = true

local function PlaceUtilityStubs(name)
	local evalName = function(n)return not name or name==n end
	--SmallFrame utility stubs
	if evalName("SmallFrame") then
		--DGV.ShowAutoTooltip = DGV.NoOp
		DGV.UpdateSmallFrame = DGV.NoOp
		DGV.LoadInitialView = DGV.NoOp
		DGV.OnWatchFrameUpdate = DGV.NoOp
	end
	--Guides utility stubs
	if evalName("Guides") then
		DGV.UpdateMainFrame = DGV.NoOp
		DGV.UpdateQueryQuests = DGV.NoOp
		DGV.Zone_OnEvent = DGV.NoOp
		DGV.CHAT_MSG_SYSTEM = DGV.NoOp
		DGV.UI_INFO_MESSAGE = DGV.NoOp
		DGV.CHAT_MSG_LOOT = DGV.NoOp
		DGV.UpdateAchieveFrame = DGV.NoOp
		DGV.Guide_CRITERIA_UPDATE = DGV.NoOp
		DGV.PLAYER_LEVEL_UP = DGV.NoOp
		DGV.RegisterGuide = DGV.NoOp
		DGV.UpdateTravelToLocation = DGV.NoOp
		DGV.GetUnfinishedGuideIndexByQID = DGV.NoOp
		DGV.ReturnTag = DGV.NoOp
		DGV.IterateGuideIndicesWithQID = DGV.NoOp
		DGV.isValidGuide = DGV.NoOp
		DGV.ClearScreen = DGV.NoOp
		DGV.CompleteQuest = DGV.NoOp
		--DGV.RegisterQuestChains = DGV.NoOp
		DGV.CheckForFloorChange = DGV.NoOp
		DGV.Guide_CRITERIA_UPDATE = DGV.NoOp
		DGV.UpdateAllSIDs = DGV.NoOp
		DGV.PLAYER_ENTERING_WORLD = DGV.NoOp
		DGV.SCENARIO_CRITERIA_UPDATE = DGV.NoOp			
		function DGV:ShowLargeWindow()
			if not DugisGuideViewer.SettingsTree then
				DGV:CreateSettingsTree(DugisMainBorder)
			end
			DugisGuideViewer.SettingsTree.frame:SetPoint("TOPLEFT", DugisMainBorder, "TOPLEFT", "20", "-20")
			DugisGuideViewer.SettingsTree.frame:SetPoint("BOTTOMRIGHT", DugisMainBorder, "BOTTOMRIGHT", "-20", "20")
			DugisMainBorder:SetHeight(377)
			DugisMainBorder:Show()
			DugisMainBorder.bg:Hide()
			DugisMain:Hide()
			DugisReloadButton:Hide()
			--DugisSuggestButton:Hide()
			DugisResetButton:Hide()
			DugisPercentButton:Hide()
			DGV:SetAllBorders()
		end
	end
	--Professions utility stubs
	if evalName("Professions") then
		DGV.UpdateProfessions =  DGV.NoOp
	end
	--ModelViewer utility stubs
	if evalName("ModelViewer") then
		DGV.HasModel = DGV.NoOp
		DGV.IsModelDataOn = DGV.NoOp
		DGV.ShowModel = DGV.NoOp
		DGV.WipeModels = DGV.NoOp
		if DGV.Modules.ModelViewer then
			DGV.Modules.ModelViewer.RegisterObjects = DGV.NoOp
			DGV.Modules.ModelViewer.RegisterNPCs = DGV.NoOp
		end
	end
	--ReqLevel utility stubs
	if evalName("ReqLevel") then
		DGV.ReqLevel = {}
	end
	if evalName("NPC") then
		DugisNPCs = {}
	end
	--Record utility stubs
	if evalName("Record") then
		SlashCmdList["DGR"] = DGV.NoOp
		DGV.ToggleRecordLimit = DGV.NoOp
		DGV.ShowRecord = DGV.NoOp
		DGV.OnAutoComplete = DGV.NoOp
		DGV.OnQuestDetail = DGV.NoOp
		DGV.OnQuestComplete = DGV.NoOp
		DGV.UpdateRecord = DGV.NoOp
		DGV.UpdateStickyFrame = DGV.NoOp
		DGV.ClearStickyFrame = DGV.NoOp
	end
	--Target utility stubs
	if evalName("Target") then
		DGV.SetTarget = DGV.NoOp
		DGV.WipeTargetNPCs = DGV.NoOp
		DGV.FinalizeTarget = DGV.NoOp
		DGV.SetNPCTarget = DGV.NoOp
	end
	--MiniBlobs utility stubs
	if evalName("MiniBlobs") then
		DGV.IsPlayerAtBlizzardDestination = DGV.NoOp
		DGV.OnMapChangeUpdateArrow = DGV.NoOp
	end
	--QuestPOI utility stubs
	if evalName("QuestPOI") then
		DGV.InitializeQuestPOI = DGV.NoOp
	end
	--MapOverlays utility stubs
	if evalName("MapOverlays") then
		DGV.InitializeMapOverlays = DGV.NoOp
	end
	--UnlistedQuest utility stubs
	if evalName("UnlistedQuest") then
		DGV.IsQuestInGuide = DGV.NoOp
	end
	--DugisArrow utility stubs
	if evalName("DugisArrow") then
		if DGV.Modules.DugisArrow then
			--DGV.AddManualWaypoint = DGV.NoOp
			DGV.Modules.DugisArrow.OnQuestLogChanged = DGV.NoOp
		end
	end
	--DugisWatchFrame utility stubs
	if evalName("DugisWatchFrame") then
		DGV.WatchFrame_CRITERIA_UPDATE = DGV.NoOp
		if DGV.Modules.DugisWatchFrame then
			DGV.Modules.DugisWatchFrame.PlayFlashAnimation = DGV.NoOp
		end
	end
	--WorldMapTracking utility stubs
	if evalName("WorldMapTracking") then
		if DGV.Modules.WorldMapTracking then
			DGV.Modules.WorldMapTracking.ShowMenu = DGV.NoOp
			DGV.Modules.WorldMapTracking.UpdateTrackingMap = DGV.NoOp
		end
	end
	if evalName("TaxiDB") then
		if DGV.Modules.TaxiDB then
			DGV.Modules.TaxiDB.UpdateQueryQuests = DGV.NoOp
		end
	end
end
PlaceUtilityStubs()

function DGV:RegisterModule(name, ...)
	--DGV:DebugFormat("RegisterModule", "name", name)
	local module = {}
	--module.dependencies = {...}
	module.name = name
	table.insert(DGV.Modules, module)
	DGV.Modules[name] = module
	PlaceUtilityStubs(module.name)
	return module
end

StaticPopupDialogs["DUGIS_RELOAD_PROMPT"] = {
	text = L["Enabling these Dugi Guides features will require the UI to reload.  Do this now?"],
	button1 = L["Yes"],
	button2 = L["No"],
	OnAccept = function()
		DGV.chardb.GuideOn = true
        --In the copper mode RemoveAllWaypoints is not available (clocking it: #128)
        if DugisGuideViewer.RemoveAllWaypoints then
            DugisGuideViewer:RemoveAllWaypoints() --helps with reducing errors with Taxi
        end
		ReloadUI()
	end,
	OnCancel = function(self, data)
		if data then
			data()
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

function DGV:ClearModule(module)
	local name = module.name
	local slFunc = module.ShouldLoad
	wipe(module)
	module.name = name
	module.ShouldLoad = slFunc
	PlaceUtilityStubs(module.name)
end

function DGV:ShowReloadUi()
	local dialog = StaticPopup_Show ("DUGIS_RELOAD_PROMPT")
	dialog.data = StaticPopupDialogs.DUGIS_RELOAD_PROMPT.data
	StaticPopupDialogs.DUGIS_RELOAD_PROMPT.button2 = L["No"]
	StaticPopupDialogs.DUGIS_RELOAD_PROMPT.data = DGV.NoOp
end

function DGV:SetEssentialsOnCancelReload()
	StaticPopupDialogs.DUGIS_RELOAD_PROMPT.button2 = L["Enable Essentials"]
	StaticPopupDialogs.DUGIS_RELOAD_PROMPT.data = function()
		DGV:TurnOnEssentials()
	end
end

local function ShouldLoad(module)
	if not module then return false end
	if module.ShouldLoad then return module:ShouldLoad() end
	return (DugisGuideViewer.chardb.EssentialsMode<1 or module.essential) and DugisGuideViewer:GuideOn()
end

local function InitModule(module)
	if not module.initialized and not module.loaded then
		if not module.Initialize then DGV:ShowReloadUi();return false end --module deleted
		module:Initialize()
		module.initialized = true
	end
	return true
end

local function LocalLoadModule(module, threading)
	if module and not module.loaded and module.Load and ShouldLoad(module) then
		module:Load(threading)
		module.loaded = true
	end
end



function DugiGuidesOnLoadingStart()
    DugisGuideViewer:UpdateIconStatus()
end

local function DugiGuidesOnLoadingEnd()
    DugiGuidesIsLoading = false
    
    ObjectiveTrackerFrame:Show()
    DugisGuideViewer:UpdateIconStatus()
   
    if DugisGuideViewer.Modules.DugisWatchFrame then
        LuaUtils:Delay(1, function()
            DGV.Modules.DugisWatchFrame:DelayUpdate()
			DGV.shouldUpdateObjectiveTracker = true
        end)        
    end
	
	
end

local function UpdateGameLoadingProgress(threading, currentNormalizedProgress)
    if threading then
	
		MainFramePreloader:ShowPreloader()
		
        GamePreloader:Show()
        GamePreloader.TexWrapper.Text:SetText("Loading Dugi Guides "..(LuaUtils:Round(currentNormalizedProgress, 2) * 100).."%..")
        
        if currentNormalizedProgress >= 0.98 then
            GamePreloader:Hide()
            GamePreloader.animationGroup:Stop()
        end
		
		if currentNormalizedProgress >= 0.98  then
			MainFramePreloader:HidePreloader()
		end
    end
end

function OnPlayerInCombat()
    if DugiGuidesIsLoading then
        GamePreloader:Hide()
    end
end

local function LoadModules(threading)
    DugiGuidesOnLoadingStart()
    
    if threading then
        CreateStandardPreloader("GamePreloader", UIParent)  
        GamePreloader:Show()
        GamePreloader.animationGroup:Play()
        GamePreloader.TexWrapper.Background:SetVertexColor(0,0.0,0, 0.0);
        GamePreloader:SetPoint("TOPLEFT", UIParent, GetScreenWidth() * 0.5 -100,  -GetScreenHeight() * 0.1 + 50)
        GamePreloader:SetWidth(225)
        GamePreloader.TexWrapper.Text:SetWidth(220)
    end

    local progress = 0
    UpdateGameLoadingProgress(threading, progress)
    
	for _, module in ipairs(DGV.Modules) do
		if ShouldLoad(module) then
			if not InitModule(module) then return false end
		elseif module and not module.loaded and not module.essential
			and (DGV:UserSetting(DGV_UNLOADMODULES) or not module.initialized) then
			DGV:ClearModule(module) --clear modules not loaded
		end
	end
	for _, module in ipairs(DGV.Modules) do
	
		if threading then
			LuaUtils:WaitForCombatEnd(true)
			LuaUtils:RestIfNeeded(true)
		end
		
		if strmatch(module.name, "DugisGuide_") then
			LocalLoadModule(module, threading)
		else
			LocalLoadModule(module, threading)
		end
            
        UpdateGameLoadingProgress(threading, progress)
        progress = progress + (0.95/#DGV.Modules)   
	end
	for _, module in pairs(DGV.Modules) do
		if module.OnModulesLoaded and module.loaded and not module.Done then
			if threading then
				LuaUtils:RestIfNeeded(true)
			end
		
            module:OnModulesLoaded(threading)
			module.Done = true  --OnModulesLoaded gets loaded twice in a row without this
		end
		--TODO: move this logic to guide modules
		if module.name and strmatch(module.name, "DugisGuide_")  then
			module.Initialize = nil
			module.Load = nil
			--[[if not module.initialized then
				ClearModule(module)
			end]]
		end
        
        progress = progress + (0.05/#DGV.Modules)
        UpdateGameLoadingProgress(threading, progress)
	end

    DugiGuidesOnLoadingEnd()

	return true
end

local function UnloadModules()
    local i
	for i=#DGV.Modules,1,-1 do
		local module = DGV.Modules[i]
		if module.loaded and not ShouldLoad(module) then
			module:Unload()
			module.loaded = false
			module.Done = false
			PlaceUtilityStubs(module.name)
		end
	end
end

function DGV:ReloadModules(threading)
	UnloadModules()
	local result = LoadModules(threading)
	LuaUtils:collectgarbage(threading)
	StaticPopupDialogs.DUGIS_RELOAD_PROMPT.button2 = L["No"]
	StaticPopupDialogs.DUGIS_RELOAD_PROMPT.data = DGV.NoOp
	return result
end

function DGV:IsModuleLoaded(name)
	return DGV.Modules[name] and DGV.Modules[name].loaded
end

--[[function DGV:UnloadModule(name)
	local module = DGV.Modules[name]
	if module and module.loaded then
		module:Unload()
		module.loaded = false
	end
end

function DGV:LoadModule(name)
	local module = DGV.Modules[name]
	if module then
		if not InitModule(module) then return false end
		LocalLoadModule(module)
		module:OnModulesLoaded()
	end
	return true
end]]

function DGV:IsModuleRegistered(name)
	return DGV.Modules[name]
end

