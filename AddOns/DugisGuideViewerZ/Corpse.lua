local DGV = DugisGuideViewer
if not DGV then return end

local Corpse = DGV:RegisterModule("Corpse")
Corpse.essential = true

local L, DebugPrint = DugisLocals, DGV.DebugPrint

function Corpse:Initialize()

	local function PlayerEventPredicate()
		local inInstance, _ = IsInInstance()
		if DGV.carboniteloaded or DGV.tomtomloaded or (not DGV.GuideOn()) or inInstance then return end
		return DGV:UserSetting(DGV_SHOWCORPSEARROW)
	end

	local playerAliveReaction, playerDeadReaction, playerUnghostReaction
	function Corpse:Load()
	
		local function GetCorpsePositionDisruptive()
			local orig_mapId, orig_level = DGV:GetCurrentMapID()
			LuaUtils:DugiSetMapToCurrentZone()
			local corpseX, corpseY = GetCorpseMapPosition_dugi()
			local m1, f1, x1, y1 =  DGV:GetUnitPosition()
			if corpseX and corpseX~=0 then
				if orig_mapId~=m1 or orig_level~=f1 then
					LuaUtils:DugiSetMapByID(orig_mapId)
				end
				return m1, f1, corpseX, corpseY
			end
			local c = GetMapContinent_dugi()
			if c then
				for mapID in DGV.ContinentMapIterator,c do
					LuaUtils:DugiSetMapByID(mapID)
					corpseX, corpseY = GetCorpseMapPosition_dugi()
					if corpseX and corpseX~=0 then
						local corpseFloor = GetCurrentMapDungeonLevel()
						LuaUtils:DugiSetMapByID(orig_mapId)
						return mapID, corpseFloor, corpseX, corpseY
					end
				end
			end
			LuaUtils:DugiSetMapByID(orig_mapId)
		end
		
		function Corpse:GetPosition()
			if not UnitIsDeadOrGhost("player") then return end
			local corpseX, corpseY = GetCorpseMapPosition_dugi()
			if not corpseX or corpseX==0 then
				return GetCorpsePositionDisruptive()
			end
			local m = DGV:GetCurrentMapID() 
			return m, f, corpseX, corpseY
		end
	
		playerAliveReaction = DGV.RegisterReaction("PLAYER_ALIVE"):WithPredicate(PlayerEventPredicate):WithAction(
			function()
				DebugPrint("PLAYER_ALIVE")
				--DGV.DugisArrow:Show()
				--local corpseX, corpseY = GetCorpseMapPosition_dugi()
				--DebugPrint("corpseX:"..corpseX.." corpseY:"..corpseY)
			end)
			
		playerDeadReaction = DGV.RegisterReaction("PLAYER_DEAD"):WithPredicate(PlayerEventPredicate):WithAction(
			function()
				DGV.DoOutOfCombat(Corpse.RemoveThenAddCorpseWaypoint)
			end)
			
		--[[playerUnghostReaction = DGV.RegisterReaction("PLAYER_UNGHOST"):WithPredicate(PlayerEventPredicate):WithAction(
			function()
				DebugPrint("PLAYER_UNGHOST")
				DGV:RemoveAllWaypoints()
				if DGV.chardb.EssentialsMode ~= 1 then 
					DGV:MapCurrentObjective()
				end 
			end)
		--]]
	end
	
	function Corpse:RemoveThenAddCorpseWaypoint()
		DebugPrint("PLAYER_DEAD")
		DGV:RemoveAllWaypoints()
		
		local desc = L["My Corpse"]
		local m, f, x, y = DGV:GetPlayerPosition()
		DebugPrint("corpse position:".."M:"..(m or "").." f:"..(f or "").." x"..(x or "").." y"..(y or ""))
		if x and y then 
			DGV:AddCorpseWaypoint( m, f, x, y, desc)
			DGV.DugisArrow:setArrow( m, f, x*100, y*100, desc )
		end
	end
		
	
	function Corpse:Unload()
		playerAliveReaction:Dispose()
		playerDeadReaction:Dispose()
		--playerUnghostReaction:Dispose()
	end
end

