local MOD = DugisGuideViewer
local MiniBlobs = MOD:RegisterModule("MiniBlobs")
MiniBlobs.essential = true

function MiniBlobs:Initialize()
	function MiniBlobs:Load()
		function MOD:IsPlayerAtBlizzardDestination()
			local posX, posY = DugisGuideViewer:GetPlayerMapPosition()
			local blobQid
			if posX then
				--Determine if the player is inside the destination, using the method the map uses to decide whether to pop a tooltip
				--[[ todo: find replaceement for WorldMapBlobFrame
				local questLogIndex, numObjectives = WorldMapBlobFrame:UpdateMouseOverTooltip(posX, posY);
				if questLogIndex then blobQid = select(8, GetQuestLogTitle(questLogIndex)) end
				if questLogIndex and blobQid and MOD.DugisArrow:GetFirstWaypointQuestId() == blobQid then
					return true
				end
				]]
			end
			return false
		end
	end
		
	function MiniBlobs:Unload()
	end
end
