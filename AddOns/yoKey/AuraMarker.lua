--local addonName, ns = ...
local L, yo = unpack( select( 2, ...))

-- [spellID] = true / false ( buff / debuff)
local LOP = LibStub("LibObjectiveProgress-1.0", true);
local isTeeming

local function HasTeeming( affixes)
	if (next(affixes) ~= nil) then
		for k, v in pairs(affixes) do
			if v == 5 then
				return true;
			end
		end
	end
	return false;
end

local function MouseoverUnitID()
	local guid = UnitGUID("mouseover");
	if (guid ~= nil) then
		local _, _, _, _, _, guidSplit = strsplit("-", guid);
		return tonumber(guidSplit);
	end
	return nil;
end
--https://github.com/tomrus88/BlizzardInterfaceCode/blob/master/Interface/AddOns/Blizzard_APIDocumentation/ChallengeModeInfoDocumentation.lua

local function OnEvent( self, event, ...)
	
	if event == "UPDATE_MOUSEOVER_UNIT" and C_Scenario.IsInScenario then
		local npcID = MouseoverUnitID();
		local _, _, difficulty, _, _, _, _, currentZoneID = GetInstanceInfo();
		local mapID, _ = currentZoneID

		if (npcID ~= nil and mapID ~= nil and isTeeming ~= nil) then
			-- Upper Karazhan Check Should Be Param 4
			--local cmID = C_ChallengeMode.GetActiveChallengeMapID();
			--local upper = cmID == 234

			-- For Siege of Boralus, isAlternate=false means Alliance and isAlternate=true means Horde
			local isAlternate = nil

			if mapID == 1822 and UnitFactionGroup("player") == "Horde" then
    			isAlternate = true
  			end

			local weight = LOP:GetNPCWeightByMap( mapID, npcID, isTeeming, isAlternate);
			if (weight ~= nil) then
				local a, b, steps, c = C_Scenario.GetStepInfo();
				local name, _, status, curValue = C_Scenario.GetCriteriaInfo( steps);
				if curValue then
					local appendString = string.format("|cff00ff00%.2f%%|r / |cffff0000%.2f%%", weight, curValue);
					GameTooltip:AddDoubleLine( name, appendString) 
				end
				GameTooltip:Show()
				--GameTooltip:AppendText(appendString);
				--print( mapID, npcID, isTeeming, upper, appendString)
			end
		end
		
	elseif event == "PLAYER_ENTERING_WORLD" then
		self:UnregisterEvent("PLAYER_ENTERING_WORLD")

		if not yo.Addons.mythicProcents then			
			self:UnregisterEvent("UPDATE_MOUSEOVER_UNIT")
			self:SetScript("OnEvent", nil)
		end
		
		--local affixName, affixDesc, affixNum = C_ChallengeMode.GetAffixInfo( 5);
		local cmLevel, affixes, empowered = C_ChallengeMode.GetActiveKeystoneInfo();
		isTeeming = HasTeeming( affixes);		
	end
end

local Amarker = CreateFrame("Frame")
Amarker:RegisterEvent("PLAYER_ENTERING_WORLD")
Amarker:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
Amarker:SetScript("OnEvent", OnEvent)
