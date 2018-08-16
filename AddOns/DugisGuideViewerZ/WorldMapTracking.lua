local DGV = DugisGuideViewer
if not DGV then return end
local L = DugisLocals
local _

local WMT = DGV:RegisterModule("WorldMapTracking")
WMT.essential = true

function WMT:Initialize()
    if DugisGuideUser.excludedTrackingPoints == nil then
        DugisGuideUser.excludedTrackingPoints = {}
    end

	local trackingIndex =
	{
		["Interface\\Minimap\\Tracking\\Auctioneer"] = 1,
		["Interface\\Minimap\\Tracking\\Banker"] = 2,
		["Interface\\Minimap\\Tracking\\BattleMaster"] = 3,
		["Interface\\Minimap\\Tracking\\Class"] = 4,
		["Interface\\Minimap\\Tracking\\FlightMaster"] = 5,
		["Interface\\Minimap\\Tracking\\Food"] = 6,
		["Interface\\Minimap\\Tracking\\Innkeeper"] = 7,
		["Interface\\Minimap\\Tracking\\Mailbox"] = 8,
		["Interface\\Minimap\\Tracking\\Poisons"] = 9,
		["Interface\\Minimap\\Tracking\\Profession"] = 10,
		["Interface\\Minimap\\Tracking\\Reagents"] = 11,
		["Interface\\Minimap\\Tracking\\Repair"] = 12,
		["Interface\\Icons\\tracking_wildpet"] = 13,
		
		[136452] = 1,  -- Auctioneer
		[136453] = 2,  -- Banker
		[136454] = 3,  -- BattleMaster
		[136455] = 4,  -- Class
		[136456] = 5,  -- FlightMaster
		[136457] = 6,  -- Food
		[136458] = 7,  -- Innkeeper
		[136459] = 8,  -- Mailbox
		[136462] = 9,  -- Poisons
		[136463] = 10, -- Profession
		[136464] = 11, -- Reagents
		[136465] = 12, -- Repair
		[613074] = 13  -- tracking_wildpet
		
	}

	local trackingMap = {}
	local real_GetTrackingInfo = GetTrackingInfo
	do
		local i;
		for i=1,GetNumTrackingTypes() do
			local _,icon,_,info = real_GetTrackingInfo(i)
			
			if trackingIndex[icon] then
				trackingMap[trackingIndex[icon]] = i
			end
		end
	end
	
	local function GetTrackingInfo(id)
		if id==4 then
			return L["Class Trainer"], "Interface\\Minimap\\Tracking\\Class", DGV.chardb.ClassTrainerTrackingEnabled
		end
		return real_GetTrackingInfo(trackingMap[id])
	end

	local function UnspecifyMapName(mapName)
		if not mapName then return end
		local dropUnderscoreMapName = string.match(mapName, "[^_]*")
		if dropUnderscoreMapName~=mapName then return dropUnderscoreMapName end
	end
	WMT.UnspecifyMapName = UnspecifyMapName
	
	local function IterateTrackingTypes()
		local count = GetNumTrackingTypes();
		local id = 0
		return function()
			id = id + 1
			if id<=count then return id, GetTrackingInfo(id) end --name, texture, active, category
		end
	end

	local professionTable = setmetatable({},
	{
		__index = function(t,i)
			local spell = tonumber(i)
			local v = i
			if spell then
				v = (GetSpellInfo(i))
			end
			return L[v]
		end,
	})

	local englishProfessionTable= setmetatable(
	{
		["2259"]	= "Alchemy",
		["3100"]	= "Blacksmithing",
		["7411"]	= "Enchanting",
		["4036"]	= "Engineering",
		["45357"]	= "Inscription",
		["25229"]	= "Jewelcrafting",
		["2108"]	= "Leatherworking",
		["3908"]	= "Tailoring",
		["2575"]	= "Mining",
		["8613"]	= "Skinning",
		["2550"]	= "Cooking",
		["3273"]	= "First Aid",
		["131474"]	= "Fishing",
	},
	{__index=function(t,k) rawset(t, k, k); return k; end})

	local DataProviders = {
		--["Mailbox"] = {},
		["Vendor"] = {},
		["ClassTrainer"] = {},
		["ProfessionTrainer"] = {},
		["Banker"] = {},
		["Battlemaster"] = {},
		["Achievement"] = {},
		["RareCreature"] = {},
		["PetBattles"] = {},
	}
	WMT.DataProviders = DataProviders
	
	--Type petType index = {identifier, type icon postfix}
	local allPetTypes = {
		[1] = {"Humanoid"   , "Humanoid"       },
		[2] = {"Dragon"     , "Dragon"         },
		[3] = {"Flying"     , "Flying"         },
		[4] = {"Undead"     , "Undead"         },
		[5] = {"Critter"    , "Critter"        },
		[6] = {"Magical"    , "Magical"        },
		[7] = {"Elemental"  , "Elemental"      },
		[8] = {"Beast"      , "Beast"          },
		[9] = {"Aquatic"    , "Water"          },
		[10] = {"Mechanical" , "Mechanical"    },
	}

	function DataProviders.IterateProviders(invariant, control)
		while true do
			local value
			control,value = next(DataProviders, control)
			if not control then return end
			if type(value)=="table" then 
				return control,value 
			end
		end
	end
	
	function DataProviders:SelectProvider(trackingType, location, ...)
		for k,v in DataProviders.IterateProviders do
			if v.ProvidesFor and v:ProvidesFor(trackingType, location, ...) then
				return v
			end
		end
	end
	
	local function ValidateTrackingType(arg, ...)
		if not DataProviders:SelectProvider(arg) and tonumber(arg)~=8 then
			DGV:DebugFormat("WorldMapTracking invalid data", "|cffff2020tracking type|r", arg, "data", (strjoin(":", ...)))
		end
	end
	
	local function ValidateNumber(arg, ...)
		if not tonumber(arg) then
			DGV:DebugFormat("WorldMapTracking invalid data", "|cffff2020number|r", arg, "data", (strjoin(":", ...)))
		end
	end
	
	local function ValidateCoords(arg, ...)
		local x,y = DGV:UnpackXY(arg)
		if not y or x>1 or y>1 then
			DGV:DebugFormat("WorldMapTracking invalid data", "|cffff2020coord|r", arg, "data", (strjoin(":", ...)))
		end
	end
	
	function DataProviders:IsTrackingEnabled(provider, trackingType, ...)
		provider = provider or self:SelectProvider(trackingType, location, ...)
		if provider and provider.IsTrackingEnabled then
			return provider:IsTrackingEnabled(trackingType, ...)
		else
			return select(3,GetTrackingInfo(trackingType))
		end
	end
	
	function DataProviders:GetTooltipText(provider, trackingType, location, ...)
		provider = provider or self:SelectProvider(trackingType, location, ...)
		if provider and provider.GetTooltipText then
			return provider:GetTooltipText(trackingType, location, ...)
		else
			return (GetTrackingInfo(trackingType))
		end
	end

	function DataProviders:ShouldShow(provider, trackingType, location, ...)
		ValidateTrackingType(trackingType, trackingType, location, ...)
		ValidateCoords(location, trackingType, location, ...)
		provider = provider or self:SelectProvider(trackingType, location, ...)
		if provider and provider.ShouldShow then
			return provider:ShouldShow(trackingType, location, ...)
		else
			return DGV:CheckRequirements(...)
		end
	end
	
	function DataProviders:GetIcon(provider, trackingType, location, ...)
		provider = provider or self:SelectProvider(trackingType, location, ...)
		if provider and provider.GetIcon then
			return provider:GetIcon(trackingType, location, ...)
		else
			return select(2,GetTrackingInfo(trackingType))
		end
	end
	
	function DataProviders:ShouldShowMinimap(provider, trackingType, location, ...)
		provider = provider or self:SelectProvider(trackingType, location, ...)
		if provider and provider.ShouldShowMinimap then
			return provider:ShouldShowMinimap(trackingType, location, ...)
		else
			return false
		end
	end
	
	function DataProviders:GetNPC(provider, trackingType, location, ...)
		provider = provider or self:SelectProvider(trackingType, location, ...)
		if provider and provider.GetNPC then
			return provider:GetNPC(trackingType, location, ...)
		else return end
	end
	
	function DataProviders:GetDetailIcon(provider, trackingType, location, ...)
		provider = provider or self:SelectProvider(trackingType, location, ...)
		if provider and provider.GetDetailIcon then
			return provider:GetDetailIcon(trackingType, location, ...)
		else return end
	end
	
	function DataProviders:GetCustomTrackingInfo(provider, trackingType, location, ...)
		provider = provider or self:SelectProvider(trackingType, location, ...)
		if provider and provider.GetCustomTrackingInfo then
			return provider:GetCustomTrackingInfo(trackingType, location, ...)
		else return end
	end

	local function GetNPCTT1(trackingType, location, npc)
		if DGV.GetLocalizedNPC then
			return DGV:GetLocalizedNPC(npc)
		end
	end

	function DataProviders.Vendor:ProvidesFor(trackingType)
		return trackingType==1 or trackingType==5 or trackingType==6  or trackingType==7 or
			trackingType==9 or trackingType==11 or trackingType==12
	end

	function DataProviders.Vendor:ShouldShow(trackingType, location, npc, subZone, ...)
		ValidateNumber(npc, trackingType, location, npc, subZone, ...)
		if not DGV:CheckRequirements(...) then return end
		local class = select(2,UnitClass("player"))
		if (trackingType==9 and class~="ROGUE") then return false end
		return true
	end

	function DGV:GetFlightMasterName(npc)
		return DataProviders.Vendor:GetTooltipText(5, nil, npc)
	end

	function DataProviders.Vendor:GetTooltipText(trackingType, ...)
		return GetNPCTT1(trackingType, ...) or (GetTrackingInfo(trackingType)) 
	end
	
	function DataProviders.Vendor:GetNPC(trackingType, location, npc)
		return npc
	end

	function DataProviders.ClassTrainer:ProvidesFor(trackingType)
		return trackingType==4
	end

	local function GetGildedNPCTooltip(guildFunc, ...)
		local tt1 = GetNPCTT1(...)
		local tt2;
		if tt1 then tt2 = "<"..guildFunc(...)..">" end
		return tt1 or guildFunc(...), tt2
	end
	
	function DataProviders.ClassTrainer:GetTooltipText(trackingType, location, npc, class, gender)
		local genderString = ""
		if gender=="F" then genderString=" Female" end
		return GetGildedNPCTooltip(
			function(trackingType, location, npc, class) return L[class.." Trainer"..genderString] end,
					trackingType, location, npc, class, gender)
	end

	function DataProviders.ClassTrainer:ShouldShow(trackingType, location, npc, class)
		ValidateNumber(npc, trackingType, location, npc, class)
		return class:lower()==select(2,UnitClass("player")):lower() and true
	end
	
	function DataProviders.ClassTrainer:GetNPC(trackingType, location, npc)
		return npc
	end
	
	function DataProviders.ClassTrainer:IsTrackingEnabled()
		return DGV.chardb.ClassTrainerTrackingEnabled
	end
	
	function DataProviders.ClassTrainer:GetIcon()
		return "Interface\\Minimap\\Tracking\\Class"
	end
	
	function DataProviders.ClassTrainer:ShouldShowMinimap()
		return true
	end

	function DataProviders.ProfessionTrainer:ProvidesFor(trackingType)
		return trackingType==10
	end
	
	function DataProviders.ProfessionTrainer:GetTooltipText(trackingType, location, npc, spell, gender)
		local genderString = ""
		if gender=="F" then genderString=" Female" end
		return GetGildedNPCTooltip(
			function(trackingType, location, npc, spell) return L[englishProfessionTable[spell].." Trainer"..genderString] end,
					trackingType, location, npc, spell)
	end
	
	function DataProviders.ProfessionTrainer:ShouldShow(trackingType, location, npc, spell, gender, ...)
		ValidateNumber(npc, trackingType, location, npc, spell, gender, ...)
		if not DGV:CheckRequirements(...) then return end
		local spellNum = tonumber(spell)
		local class = select(2,UnitClass("player"))
		if (spell=="Portal" and class~="MAGE") or
			(spell=="Pet" and class~="HUNTER")
		then return false end
		--[[if not spellNum then return true end
		local prof1, prof2 = GetProfessions()
		return (not prof1) or (not prof2) or --unchosen professions
			spellNum==2550 or spellnum==3273 or spellNum==131474 or --cooking,first aid,fishing,
			IsUsableSpell(GetSpellInfo(spellNum))]]
		return true
	end
	
	function DataProviders.ProfessionTrainer:GetNPC(trackingType, location, npc)
		return npc
	end

	function DataProviders.Banker:ProvidesFor(trackingType)
		return trackingType==2
	end
	
	function DataProviders.Banker:GetTooltipText(...)
		return GetGildedNPCTooltip(
			function(...) return L["Banker"] end, ...)
	end
	
	function DataProviders.Banker:GetNPC(trackingType, location, npc)
		return npc
	end

	function DataProviders.Battlemaster:ProvidesFor(trackingType)
		return trackingType==3
	end
	
	function DataProviders.Battlemaster:GetTooltipText(...)
		return GetGildedNPCTooltip(
			function(...) return L["Battlemaster"] end, ...)
	end
	
	function DataProviders.Battlemaster:GetNPC(trackingType, location, npc)
		return npc
	end
	--Comment Start for DQE	
	function DataProviders.Achievement:ProvidesFor(trackingType)
		return trackingType=="A"
	end
	
	function DataProviders.Achievement:GetTooltipText(trackingType, location, achievementId, criteriaIndex, extraToolTip)
		achievementId = tonumber(achievementId)
		local tt1, tt2, tt3
		if achievementId then 
			tt1, _, _, _, _, _, tt2 = select(2, GetAchievementInfo(achievementId))
			if tt2 then
				tt2 = format("\n|cffffffff%s", tt2)
			end
			criteriaIndex = tonumber(criteriaIndex)
	
			local achievementNum = tonumber(GetAchievementNumCriteria(achievementId))		
			
			if criteriaIndex and criteriaIndex <= achievementNum then
				tt3 = format("\n|cff9d9d9d%s", GetAchievementCriteriaInfo(achievementId, criteriaIndex))
			end
		end
		if extraToolTip=="" then extraToolTip=nil end
		if extraToolTip then
            if extraToolTip:match("[{].*[}]") ~= nil then
                extraToolTip = string.gsub(extraToolTip, '[{}]', '')
                extraToolTip = L[extraToolTip]
            end
			extraToolTip = format("\n|cffffffff%s", extraToolTip)
		end
		if not tt1 then tt1 = L["Treasure"] end --Need to localize
		return tt1, tt2, tt3, extraToolTip
	end
	
	function DataProviders.Achievement:ShouldShow(trackingType, location, achievementId, criteriaIndex, extraToolTip, questId, ...)
		ValidateNumber(achievementId, trackingType, location, achievementId, criteriaIndex, extraToolTip, questId, ...)

		questId = tonumber(questId)
		if questId and IsQuestFlaggedCompleted(questId) then return end

		achievementId = tonumber(achievementId)
		if achievementId then 
			if achieveID ~= 6856 and 
				achieveID ~= 6716 and 
				achieveID ~= 6846 and 
				achieveID ~= 6754 and 
				achieveID ~= 6857 and 
				achieveID ~= 6850 and 
				achieveID ~= 6855 and 
				achieveID ~= 6847 and 
				achieveID ~= 6858 and -- Exclude lorewalker achievement 
				DGV:UserSetting(DGV_ACCOUNTWIDEACH) then -- Account Wide Achievement setting
				local completed = select(4, GetAchievementInfo(achievementId))
				if completed then return end
			end 
			criteriaIndex = tonumber(criteriaIndex)
			local criteriaNum = tonumber(GetAchievementNumCriteria(achievementId))
			if criteriaIndex and criteriaIndex <= criteriaNum and select(3, GetAchievementCriteriaInfo(achievementId, criteriaIndex)) then
				return 
			end
		end
		return true
	end
	
	function DataProviders.Achievement:IsTrackingEnabled()
		return DGV.chardb.AchievementTrackingEnabled
	end
	
	function DataProviders.Achievement:GetIcon(trackingType, location, achievementId, criteriaIndex, extraToolTip, questId, ...)
		questId = tonumber(questId)
		if questId then
			return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\treasure"
		else
			return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\AchievementIcon"
		end
	end
	
	function DataProviders.Achievement:ShouldShowMinimap()
		return true
	end
	
	function DataProviders.Achievement:GetCustomTrackingInfo()
        if DugisGuideViewer.ExtendedTrackingPointsExists then
            return "Track Achievements", "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\AchievementIcon",
                    function() return DGV.chardb.AchievementTrackingEnabled end,
                    function(value) DGV.chardb.AchievementTrackingEnabled = value end
        end
	end
	
	function DataProviders.RareCreature:ProvidesFor(trackingType)
		return trackingType=="R"
	end
	
	function DataProviders.RareCreature:GetTooltipText(trackingType, location, npc, extraToolTip)
		local tt1 = GetNPCTT1(trackingType, location, npc)
		if extraToolTip=="" then extraToolTip=nil end
		if extraToolTip then
			extraToolTip = format("|cffffffff%s", extraToolTip)
		end
		return tt1 or extraToolTip, tt1 and extraToolTip
	end
	
	function DataProviders.RareCreature:ShouldShow(trackingType, location, npc, extraToolTip, questId, ...)
		ValidateNumber(npc, trackingType, location, npc, extraToolTip, questId, ...)
		questId = tonumber(questId)
		if questId and IsQuestFlaggedCompleted(questId) then return end
		return true
	end
	
	function DataProviders.RareCreature:IsTrackingEnabled()
		return DGV.chardb.RareCreatureTrackingEnabled
	end
	
	function DataProviders.RareCreature:GetIcon()
		return "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\BossIcon"
	end
	
	function DataProviders.RareCreature:ShouldShowMinimap()
		return true
	end
	
	function DataProviders.RareCreature:GetNPC(trackingType, location, npc)
		return npc
	end
	
	function DataProviders.RareCreature:GetCustomTrackingInfo()
        if DugisGuideViewer.ExtendedTrackingPointsExists then
            return "Track Rare Creatures", "Interface\\AddOns\\DugisGuideViewerZ\\Artwork\\BossIcon",
                    function() return DGV.chardb.RareCreatureTrackingEnabled end,
                    function(value) DGV.chardb.RareCreatureTrackingEnabled = value end
        end
	end
	--Comment end for DQE
	local petJournalLookup = {}
	--_G["BATTLE_PET_NAME_"..i]
	function DGV:PopulatePetJournalLookup()
		DGV:UnregisterEvent("PET_JOURNAL_LIST_UPDATE")
		DGV:DebugFormat("PopulatePetJournalLookup")
		--Legion beta cheap fix
		--C_PetJournal.SetFlagFilter(LE_PET_JOURNAL_FLAG_COLLECTED, true)
		--C_PetJournal.SetFlagFilter(LE_PET_JOURNAL_FLAG_FAVORITES, false)
		--C_PetJournal.SetFlagFilter(LE_PET_JOURNAL_FLAG_NOT_COLLECTED, true)
		--C_PetJournal.AddAllPetTypesFilter()
		--C_PetJournal.AddAllPetSourcesFilter()
		wipe(petJournalLookup)
		for i=1,C_PetJournal.GetNumPets(false) do
			local _,speciesID,collected,_,_,_,_,speciesName,_,familyType,creatureID,_,flavorText = 
				C_PetJournal.GetPetInfoByIndex(i)
			petJournalLookup[speciesID] = 
					string.format("%d:%s:%s:%d:%d", creatureID, speciesName, flavorText:gsub("(:)", "%%3A"), familyType, collected and 1)
		end
		DGV:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
	end
	
	local lastNumPets = 0
	function DGV:PET_JOURNAL_LIST_UPDATE()
		local _, num = C_PetJournal.GetNumPets(false)
		if num~=lastNumPets then
			DGV:PopulatePetJournalLookup()
			lastNumPets = num
		end
	end
	
	--[[function DGV:LOOT_CLOSED()
		WMT:UpdateTrackingMap()
	end	
	
	function DGV:LOOT_SLOT_CLEARED()
		WMT:UpdateTrackingMap()
	end]]
	
	function DataProviders.PetBattles:ProvidesFor(trackingType)
		return trackingType=="P"
	end
	
	function DataProviders.PetBattles:GetTooltipText(trackingType, location, speciesID, extraToolTip)
		local value = petJournalLookup[tonumber(speciesID)]
		if not value and speciesID then
		   local speciesName, speciesIcon, petType, companionID, tooltipSource, tooltipDescription, isWild, canBattle, isTradeable, isUnique, obtainable, creatureDisplayID = C_PetJournal.GetPetInfoBySpeciesID(tonumber(speciesID))
			petJournalLookup[tonumber(speciesID)] = 
				string.format("%d:%s:%s:%d:%d", companionID, speciesName, tooltipDescription:gsub("(:)", "%%3A"), petType, nil)
			value = petJournalLookup[tonumber(speciesID)]
		elseif not speciesID then
			return false
		end
		local _, speciesName, flavorText, familyType, collected = strsplit(":", value)
		if flavorText then
			flavorText = format("\"%s\"", flavorText:gsub("(%%3A)", ":"))
		end
		if extraToolTip=="" then extraToolTip=nil end
		if extraToolTip then
			extraToolTip = format("|cffffffff%s", extraToolTip)
		end
		if familyType then
			DGV:DebugFormat("PetBattles:GetTooltipText", "familyType", familyType)
			familyType = format("|cffffffff%s", _G["BATTLE_PET_NAME_"..familyType])
		end
		if collected then
			if tonumber(collected)>0 then
				collected = format("|cff20ff20%s", L["Collected"])
			else
				collected = format("|cffff2020%s", L["Not Collected"])
			end
		end
		return speciesName, nil, familyType, collected, extraToolTip -- no flavorText for now. 
	end
		
    local function getPetTypeFilters()
        if not DugisGuideViewer.chardb["petTypeFilters"] then
            DugisGuideViewer.chardb["petTypeFilters"] = {
                Humanoid     = true,
                Dragon       = true,
                Flying       = true,
                Undead       = true,
                Critter      = true,
                Magical      = true,
                Elemental    = true,
                Beast        = true,
                Aquatic      = true,
                Mechanical   = true
            }              
        end     
        return DugisGuideViewer.chardb["petTypeFilters"]
    end
    
    if DugisGuideViewer.chardb["showCollectedPets"] == nil then
        DugisGuideViewer.chardb["showCollectedPets"] = true
    end 
    
    if DugisGuideViewer.chardb["showNotCollectedPets"] == nil then
        DugisGuideViewer.chardb["showNotCollectedPets"] = true
    end

	function DataProviders.PetBattles:ShouldShow(trackingType, location, speciesID, ...)
		ValidateNumber(speciesID, trackingType, location, speciesID, ...)
        
            local value = petJournalLookup[tonumber(speciesID)]
            if not value and speciesID then
               local speciesName, speciesIcon, petTypeIndex, companionID, tooltipSource, tooltipDescription, isWild, canBattle, isTradeable, isUnique, obtainable, creatureDisplayID = C_PetJournal.GetPetInfoBySpeciesID(tonumber(speciesID))
				petJournalLookup[tonumber(speciesID)] = 
					string.format("%d:%s:%s:%d:%d", companionID, speciesName, tooltipDescription:gsub("(:)", "%%3A"), petTypeIndex, nil)
				value = petJournalLookup[tonumber(speciesID)]
			elseif not speciesID then
				return false
            end
            
            local _, _, petTypeIndex = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
            petType = _G['BATTLE_PET_NAME_' .. petTypeIndex]
            
            local _, _, _, _, collected = strsplit(":", value)
            collected = tonumber(collected)~=0 
			
			--For backward compatibility
			local petTypeName = allPetTypes[petTypeIndex][1]
			
            if (DugisGuideViewer.chardb["showCollectedPets"] and collected) or (DugisGuideViewer.chardb["showNotCollectedPets"] and not collected) then
                if petType then
					if getPetTypeFilters()[petTypeIndex] ~= nil then
						return getPetTypeFilters()[petTypeIndex]
					end
					
					if getPetTypeFilters()[petType] ~= nil then
						return getPetTypeFilters()[petType]
					end
					
					if getPetTypeFilters()[petTypeName] ~= nil then
						return getPetTypeFilters()[petTypeName]
					end
                end
            end  

            return false
	end
	
	function DataProviders.PetBattles:IsTrackingEnabled()
		for i=1, GetNumTrackingTypes() do 
			local name, texture, active, category = real_GetTrackingInfo(i); 
			if texture == 613074 then
				return active
			end
		end
	end
	
	function DataProviders.PetBattles:GetIcon(trackingType, location, speciesID, criteriaIndex, extraToolTip, ...)
		return DataProviders.PetBattles:GetDetailIcon(_, _, speciesID)
	end
	
	function DataProviders.PetBattles:ShouldShowMinimap()
		return false
	end
	
	function DataProviders.PetBattles:GetNPC(trackingType, location, speciesID)
		local value = petJournalLookup[tonumber(speciesID)]
		if not value and speciesID then
		   local speciesName, speciesIcon, petType, companionID, tooltipSource, tooltipDescription, isWild, canBattle, isTradeable, isUnique, obtainable, creatureDisplayID = C_PetJournal.GetPetInfoBySpeciesID(tonumber(speciesID))
			petJournalLookup[tonumber(speciesID)] = 
				string.format("%d:%s:%s:%d:%d", companionID, speciesName, tooltipDescription:gsub("(:)", "%%3A"), petType, nil)
			value = petJournalLookup[tonumber(speciesID)]
		elseif not speciesID then
			return false
		end
		return tonumber((strsplit(":", value)))
	end
	
	function DataProviders.PetBattles:GetDetailIcon(trackingType, location, speciesID)
		--if not petJournalLookup[tonumber(speciesID)] then return end
		local familyType
		if petJournalLookup[tonumber(speciesID)] then 
			familyType = tonumber((select(4, strsplit(":", petJournalLookup[tonumber(speciesID)]))))
		elseif speciesID then 
			familyType = tonumber((select(3, C_PetJournal.GetPetInfoBySpeciesID(speciesID))))
		end 
		if PET_TYPE_SUFFIX[familyType] then
			return "Interface\\PetBattles\\PetIcon-"..PET_TYPE_SUFFIX[familyType];
		else
			return "Interface\\PetBattles\\PetIcon-NO_TYPE";
		end
	end

	function DGV:UnpackXY(coord)
-- 		if not tonumber(coord) then
-- 		  DGV:DebugFormat("UnpackXY", "coord", coord, "stack", debugstack())
-- 		end
		if type(coord)=="string" then
			local xString,yString = coord:match("(%d+.%d+),(%d+%.%d+)")
			if yString then
				return tonumber(xString)/100, tonumber(yString)/100
			end
		end
		if not tonumber(coord) then return end
		local factor 
		if tonumber(coord) > 99999999 then
			factor = 2^16
		else 
			factor = 10000 --Handy notes coord
		end
		local x,y =  floor(coord / factor) / factor, (coord % factor) / factor
		--DGV:DebugFormat("GetXY", "x", x, "y", y)
		return x,y
	end

	--local trackingStates = nil
	local trackingPoints = {}
	WMT.trackingPoints = trackingPoints
	local function UpdateTrackingFilters()
		local mapID, level = WorldMapFrame:GetMapID()
		for _,point in ipairs(trackingPoints) do
			local trackingType, coord = unpack(point.args)
            local id = point.args[3]
            
            local id1 = point.args[1] or ""
            local id2 = point.args[2] or ""
            local id3 = point.args[3] or ""
            local pointKey = id1..id2..id3
              
			if 
				DataProviders:ShouldShow(point.provider, unpack(point.args)) and
				DataProviders:IsTrackingEnabled(point.provider, unpack(point.args)) and
                DugisGuideUser.excludedTrackingPoints and 
                DugisGuideUser.excludedTrackingPoints[pointKey] ~= true
			then
				if not point:IsShown() then
					local icon = DataProviders:GetIcon(point.provider, unpack(point.args))
					if trackingType == "P" then
						point.icon:SetTexture(icon)
						point.icon:SetTexCoord(0.79687500, 0.49218750, 0.50390625, 0.65625000)
						point:SetFrameLevel(602)
					elseif trackingType == "A" then --make achievement higher priority 
						point.icon:SetTexture(icon)
						point.icon:SetTexCoord(0, 1, 0, 1)
						point:SetFrameLevel(603)
					else
						point:SetFrameLevel(602)					
						point.icon:SetTexture(icon)
						point.icon:SetTexCoord(0, 1, 0, 1)
					end
					point:SetHeight(14)
					point:SetWidth(14)
					point:Show()
					if point.minimapPoint then
						point.minimapPoint.icon:SetTexture(icon)
						point.minimapPoint:SetHeight(14)
						point.minimapPoint:SetWidth(14)
						point.minimapPoint:Show()
							
						local x, y = DGV:UnpackXY(coord)
						DugisGuideViewer:PlaceIconOnMinimap(
							
							point.minimapPoint, mapID, level, x, y, true, false)
					end
					local x, y = DGV:UnpackXY(coord)
					DGV:PlaceIconOnWorldMap(WorldMapButton, point, mapID, level, x, y , nil, nil, HBD_PINS_WORLDMAP_SHOW_PARENT)
				end
			else
				point:Hide()
			end
		end
	end

	hooksecurefunc("SetTracking", UpdateTrackingFilters)
	hooksecurefunc("ClearAllTracking", UpdateTrackingFilters)

	local function AddWaypoint(point)
        if DGV:IsModuleRegistered("Target") and DGV:UserSetting(DGV_TARGETBUTTON) then
			local npcId = DataProviders:GetNPC(point.provider, unpack(point.args))
			
			if npcId then
				DGV:SetNPCTarget(npcId)
				if DGV:UserSetting(DGV_TARGETBUTTONSHOW) then 
					DugisGuideViewer.Modules.Target.Frame:Show()
				end

				if DGV:IsModuleRegistered("ModelViewer") and DGV.Modules.ModelViewer.Frame and DGV.Modules.ModelViewer.Frame:IsShown() then
					DGV.Modules.ModelViewer:SetModel(npcId)
				end
			end
		end
    
		local x, y = DGV:UnpackXY(point.args[2])
		DGV:AddCustomWaypoint(
			x, y, DataProviders:GetTooltipText(point.provider, unpack(point.args)),
			DGV:GetCurrentMapID() )
	end

--[[	function WMT:GetAchievementProgress(achievementID)
		local numCompleted = 0
		
		if achievementID and achievementID ~= "" then
			local num = GetAchievementNumCriteria(achievementID)
			LuaUtils:loop(num, function(index)
				local _, _, completed = GetAchievementCriteriaInfo(achievementID, index)
				
				if completed then
					numCompleted = numCompleted + 1
				end
			end)
		end
		return numCompleted
	end ]] -- This create stuttering issue with some character, removed for now
	
	local function point_OnClick(self, button)
		self = self.point or self
		if button == "RightButton" then
			local menu = DGV.ArrowMenu:CreateMenu("world_map_point_menu")
			DGV.ArrowMenu:CreateMenuTitle(menu,
					DataProviders:GetTooltipText(self.provider, unpack(self.args)))
			local setWay = DGV.ArrowMenu:CreateMenuItem(menu, L["Set as waypoint"])
			setWay:SetFunction(function ()
				DGV:RemoveAllWaypoints()
				AddWaypoint(self)
			end)
			local addWay = DGV.ArrowMenu:CreateMenuItem(menu, L["Add waypoint"])
			addWay:SetFunction(function () AddWaypoint(self)  end)
                 local id1 = self.args[1] or "" 
                 local id2 = self.args[2] or "" 
                 local id3 = self.args[3] or "" 
                 local pointKey = id1..id2..id3
			local removeTracking = DGV.ArrowMenu:CreateMenuItem(menu, L["Remove tracking"])
			removeTracking:SetFunction(function () 
                DugisGuideUser.excludedTrackingPoints[pointKey] = true
                if self.minimapPoint then
                    DGV:RemoveIconFromMinimap(self.minimapPoint)
                end
                DGV:RemoveWorldMapIcon(self)    
                WMT:UpdateTrackingMap()
            end)
            
			local trackingTypeText = (GetTrackingInfo(self.args[1]))
			if trackingTypeText then
				local untrack = DGV.ArrowMenu:CreateMenuItem(menu,
					string.format(L["Remove %s Tracking"], trackingTypeText))
				untrack:SetFunction(function ()
					MiniMapTracking_SetTracking(nil, self.args[1], nil, false)
				end)
			end
			menu:ShowAtCursor()
		elseif button == "LeftButton" then
			if not IsShiftKeyDown() then
				DGV:RemoveAllWaypoints()
			end
			AddWaypoint(self)
		end
	end
	
	local toolTipIconTexture
	local overPoint
	local function DugisWaypointTooltip_OnShow()
		if DugisWaypointTooltipTextLeft1 and overPoint and overPoint.toolTipIcon then
			local height = DugisWaypointTooltipTextLeft1:GetHeight()
			local width = DugisWaypointTooltipTextLeft1:GetWidth()
			if not toolTipIconTexture then
				toolTipIconTexture = DugisWaypointTooltip:CreateTexture("ARTWORK")
				toolTipIconTexture:SetPoint("TOPRIGHT", -5, -5)
				toolTipIconTexture:SetWidth(height+5)
				toolTipIconTexture:SetHeight(height+5)
			end
			DugisWaypointTooltip:SetMinimumWidth(20+width+20+height)
			toolTipIconTexture:SetTexture(overPoint.toolTipIcon)
			toolTipIconTexture:SetTexCoord(0.79687500, 0.49218750, 0.50390625, 0.65625000) --temporary pet journal solution
			toolTipIconTexture:Show()
		elseif toolTipIconTexture then
			toolTipIconTexture:Hide()
		end
	end
    
    DugisWaypointTooltip.updateDugisWaypointTooltipLines = function()
        DugisWaypointTooltip:ClearLines()
        local lineIndex = 0
        
        if DugisWaypointTooltip.lines then
            LuaUtils:foreach(DugisWaypointTooltip.lines, function(line)
                if DugisGuideViewer:IsModuleLoaded("NPCJournalFrame") then 
                    line = DGV.NPCJournalFrame:ReplaceSpecialTags(line, false)
                end
                if lineIndex == 0 then
                    DugisWaypointTooltip:AddLine(line, nil, nil, nil, true)
                else
                    DugisWaypointTooltip:AddLine(line, 1, 1, 1, true)
                end
                
                lineIndex = lineIndex + 1
            end)
        end
        
		DugisWaypointTooltip:HookScript("OnShow", DugisWaypointTooltip_OnShow)
		DugisWaypointTooltip:Show()
        
        DugisWaypointTooltip:SetClampedToScreen(true)
       
        local screenWidth = GetScreenWidth()
        local mapWidth = WorldMapFrame.ScrollContainer.Child:GetWidth() 
        local xOffset = (screenWidth - mapWidth) / 2
        
        if WorldMapFrame:IsMaximized() then
            DugisWaypointTooltip:SetClampRectInsets(0,0,0,0) 
        else
            DugisWaypointTooltip:SetClampRectInsets(-xOffset + 180,0,0,-35)  
        end
    end
	
	local function AddTooltips(...)
    
        DugisWaypointTooltip.lines = {}
    
		for i=1,select("#", ...) do
            local line = (select(i, ...))
            if line == nil then
                line = ""
            end
            
            --Line processing
            line = string.gsub(line, "=COLON=",":")
            DugisWaypointTooltip.lines[#DugisWaypointTooltip.lines+1] = line
		end
        
        DugisWaypointTooltip:updateDugisWaypointTooltipLines()
	end

	local modelFrame = CreateFrame("PlayerModel", nil, DugisWaypointTooltip)
	WMT.modelFrame = modelFrame
	modelFrame:SetFrameStrata("TOOLTIP")
	
	local function GetMaxLineWidth()
		local maxW
		LuaUtils:loop(10, function(index)
			local line = _G["DugisWaypointTooltipTextLeft"..index]
			if line then
				if not maxW or line:GetWidth() > maxW then
					maxW = line:GetWidth()
				end
			else
				return "break"
			end
		end)
		return maxW
	end

    DugisWaypointTooltip.updateModel = function()
        npcId = DugisWaypointTooltip.npcId
    
        if DGV:UserSetting(DGV_HIDE_MODELS_IN_WORLDMAP) then
            return
        end
    
		if not npcId then return end
        
		local width = 150
		local maxLine = (GetMaxLineWidth() or width) + 30
		
		if maxLine > width then
			width = maxLine
		end
		
		if width > 225 then
			width = 225
			DugisWaypointTooltipTextLeft1:SetWidth(210)		
			if DugisWaypointTooltipTextLeft2 then
				DugisWaypointTooltipTextLeft2:SetWidth(210)
			end
		end
		
        if (DugisWaypointTooltip:GetWidth() < width) then
            DugisWaypointTooltip:SetWidth(width)
        end

		DugisWaypointTooltip:SetWidth(width) 
        
        local textHeight = DugisWaypointTooltip:GetHeight()
        DugisWaypointTooltip:SetHeight(DugisWaypointTooltip:GetWidth() + textHeight - 15)
                
        
        if UIParent:IsVisible() then
            modelFrame:SetPoint("TOPLEFT", 5, -textHeight + 5)
            modelFrame:SetPoint("BOTTOMRIGHT", -5, 5)
		else
            modelFrame:SetPoint("TOPLEFT", 5, -textHeight + 5)
            modelFrame:SetPoint("BOTTOMRIGHT", -5, 5)
		end
        

		local mv = DGV.Modules.ModelViewer
		--DGV:DebugFormat("point_OnEnter", "mv.npcDB[npcId]", mv.npcDB[npcId], "npcId", npcId)
		modelFrame:Show()
		modelFrame:ClearModel()
		if mv and mv.npcDB and mv.npcDB[npcId] then
			local value = mv.npcDB[npcId]
			if value and value ~= "" then
				modelFrame:SetDisplayInfo(value)
			end
		else
			if npcId and npcId ~= "" then
				modelFrame:SetCreature(npcId)
			end
		end
		modelFrame:Show()
        
        --GetModel is missing. More info: http://eu.battle.net/wow/en/forum/topic/17612062455
		if not modelFrame:GetModelFileID() or modelFrame:GetModelFileID()=="" then 
           -- print(modelFrame:GetModelFileID())
            modelFrame:Hide() 
        end    
    
    end

	local function point_OnEnter(self, button)
		local flightMaster = self.args and self.args[1] == 5
		if UIParent:IsVisible() then
			DugisWaypointTooltip:SetParent(UIParent)
		else
			DugisWaypointTooltip:SetParent(self)
		end

		DugisWaypointTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		self = self.point or self
		overPoint = self
		DugisWaypointTooltip:SetFrameStrata("TOOLTIP")
    
        local texts = {DataProviders:GetTooltipText(self.provider, unpack(self.args))}

		local npcId = DataProviders:GetNPC(self.provider, unpack(self.args))
        
        if texts[1] == nil and npcId then
            texts[1] = "NPC "..npcId
        end
		
		if self.name and flightMaster then 
			texts[1] = "|cffffffff"..self.name.."|r"
		elseif flightMaster then
			texts[1] = L["|cfff0eb20Flight location not learned|r"]
		end		
        
		AddTooltips(unpack(texts))

        if not flightMaster then 
			DugisWaypointTooltip.npcId = npcId
	        DugisWaypointTooltip:updateModel()
		end

	end

	local function point_OnLeave(self, button)
		DugisWaypointTooltip:Hide()
		modelFrame:Hide()
		modelFrame:ClearModel()
	end
	
	local function minimapPoint_OnUpdate(self)
	--[[ todo: find replcement, test for API 8.0
		local dist,x,y = DugisGuideViewer.astrolabe:GetDistanceToIcon(self)
		if not dist then
			self:Hide()
			return
		end

		if DugisGuideViewer.astrolabe:IsIconOnEdge(self) then
			self.icon:Hide()
		else
			self.icon:Show()
		end
		]]
	end

	local trackingPointPool = {}
	local minimapPointPool = {}
	local function GetCreatePoint(...)
		local point = tremove(trackingPointPool)
		if not point then
			point = CreateFrame("Button", nil, DugisMapOverlayFrame)
			point:RegisterForClicks("RightButtonUp","LeftButtonUp")
			point:SetScript("OnClick", point_OnClick)
			point:SetScript("OnEnter", point_OnEnter)
			point:SetScript("OnLeave", point_OnLeave)
			point.icon = point:CreateTexture("ARTWORK")
			point.icon:SetAllPoints()
			point.icon:Show()
			--point:SetFrameLevel(502) --Required for to be 1 point above the Blizzard flight master POI
		end
		point:Hide()
		point.args = {...}
		point.args[1] = tonumber(point.args[1]) or point.args[1]
		point.args[2] = tonumber(point.args[2]) or point.args[2]
		point.provider = DataProviders:SelectProvider(...)
		if point.args[1] == 5 and point.args[4] then --Flightmaster Zone name
			point.name = point.args[4]
		end
		local icon = DataProviders:GetDetailIcon(point.provider, unpack(point.args))
		if icon then
			point.toolTipIcon = icon
		else
			point.toolTipIcon = nil
		end
		if DataProviders:ShouldShowMinimap(point.provider, unpack(point.args)) then
			local miniPoint = tremove(minimapPointPool)
			if not miniPoint then
				miniPoint = CreateFrame("Button", nil, DugisMinimapOverlayFrame)
				miniPoint:RegisterForClicks("RightButtonUp","LeftButtonUp")
				miniPoint:SetScript("OnClick", point_OnClick)
				miniPoint:SetScript("OnEnter", point_OnEnter)
				miniPoint:SetScript("OnLeave", point_OnLeave)
				miniPoint:SetScript("OnUpdate", minimapPoint_OnUpdate)
				miniPoint.icon = miniPoint:CreateTexture("ARTWORK")
				miniPoint.icon:SetAllPoints()
				miniPoint.icon:Show()
			end
			miniPoint.point = point
			miniPoint:Hide()
			point.minimapPoint = miniPoint
		end
		tinsert(trackingPoints, point)
		
		return point
	end

	local function GetDistance(point)
		local DugisArrow = DGV.Modules.DugisArrow
		--local x, y = GetXY(point.args[2])
		local x, y = DGV:UnpackXY(point[4])
		--	DugisArrow.map, DugisArrow.floor, DugisArrow.pos_x, DugisArrow.pos_y)
		return DGV:ComputeDistance(point[1], point[2] or  DugisArrow.floor, x, y,
			DugisArrow.map, DugisArrow.floor, DugisArrow.pos_x, DugisArrow.pos_y)
	end
	WMT.GetDistance = GetDistance

	local function IterateZonePoints(mapName, pointData, ofType, allContinents, IterateZonePoints, dontCheckDistance)
		if not pointData then return end
		local DugisArrow = DGV.Modules.DugisArrow
		local currentContinent = GetCurrentMapContinent_dugi()
		local mapName,level = strsplit(":",mapName)
		local nsMapName = UnspecifyMapName(mapName)
		if nsMapName then
			if not DugisGuideUser.CurrentMapVersions or DugisGuideUser.CurrentMapVersions[nsMapName]~=mapName then return end
		end
		
		--Case made for "Dalaran70" mapName
		if not nsMapName and not tonumber(mapName) then
			mapName = mapName:gsub('[0-9]*', "") 
		end
		
		map = DGV:GetMapIDFromName(nsMapName or mapName)
		level = tonumber(level)
		if 
			currentContinent~=DGV:GetCZByMapId(map) and 
			mapName~=DGV:GetDisplayedMapNameOld() and
			not allContinents
		then
			return
		end
		local index = 0
		local zonePointIterator
		zonePointIterator = function()
			index = index + 1
			if not pointData[index] then return nil end
			if ofType then
				local tType = pointData[index]:match("(.-):")
				if tType~=ofType then
					return zonePointIterator()
				end
			end
			local point = {map, level, strsplit(":", pointData[index])}
			point[3] = tonumber(point[3]) or point[3]
			point[4] = tonumber(point[4]) or point[4]
--DGV:DebugFormat("IterateZonePoints", "mapName", mapName, "ShouldShow", (DataProviders:ShouldShow(nil, point[3], point[4], unpack(point, 5))), "GetDistance", (GetDistance(point)))
			if DataProviders:ShouldShow(nil, point[3], point[4], unpack(point, 5)) and
				(dontCheckDistance or GetDistance(point))
			then
				return point
			else
				return zonePointIterator()
			end
		end
		return zonePointIterator
	end
	
	local function IterateFlightPoints(invariant, control)
		while invariant do
			local data
			control,data = next(invariant,control)
			if control then
				if not data.requirements or DGV:CheckRequirements(strsplit(":", data.requirements)) then
					local point = {data.m, data.f, 5, data.coord, control}
					if DataProviders:ShouldShow(nil, point[3], point[4], unpack(point, 5)) and
						GetDistance(point)
					then
						return control, point
					end
				end
			else return end
		end
	end

	function DGV.IterateAllFindNearestPoints(ofType, allContinents, dontCheckDistance)
		local faction = UnitFactionGroup("player")

		local key, value, factionTable, factionKey, zonePointIterator, flightPointIterator, flightPointInvariant, flightPointControl
		local trackingPointTable = DugisWorldMapTrackingPoints
		local rootIterator
		rootIterator = function()
			if flightPointIterator then
				flightPointControl, value = flightPointIterator(flightPointInvariant, flightPointControl)
				if not flightPointControl then return end
				return value
			end
			if zonePointIterator then
				local tmp = zonePointIterator()
				if tmp then
					return tmp
				else
					zonePointIterator=nil
				end
			end
			if factionTable then
				factionKey, value = next(factionTable, factionKey)
				if factionKey then
					zonePointIterator = IterateZonePoints(factionKey, value, ofType, allContinents, nil, dontCheckDistance)
				else
					factionTable = nil
				end
			else
				key,value = next(trackingPointTable, key)
				if not key then 
					if trackingPointTable==DugisWorldMapTrackingPoints then 
						trackingPointTable = CollectedWorldMapTrackingPoints_v2
						if trackingPointTable then
							return rootIterator()
						end
					end
					if ofType and ofType~="5" then return end
					local fullData = DGV.Modules.TaxiData:GetFullData()
					local continent = GetCurrentMapContinent_dugi()
					flightPointIterator, flightPointInvariant = IterateFlightPoints, fullData[continent]
				elseif key==faction then
					factionTable = value
				elseif key~="Horde" and key~="Alliance" and key~="Neutral" then
					zonePointIterator = IterateZonePoints(key, value, ofType, allContinents, nil, dontCheckDistance)
				end
			end
			return rootIterator()
		end
		return rootIterator
	end

	local function RemovePoint(point)
		local val, index
		for index, val in ipairs(trackingPoints) do
			if point == val then
				point:Hide()
				if point.minimapPoint then
					tinsert(minimapPointPool, point.minimapPoint)
					point.minimapPoint:Hide()
					point.minimapPoint = nil
				end

				tinsert(trackingPointPool, tremove(trackingPoints, index))
				return
			end
		end
	end

	local function RemoveAllPoints()
		while #trackingPoints>0 do
			local point = tremove(trackingPoints)
			point:Hide()
			if point.minimapPoint then
					tinsert(minimapPointPool, point.minimapPoint)
					point.minimapPoint:Hide()
					point.minimapPoint = nil
				end
			tinsert(trackingPointPool, point)
		end
	end

	local function AddPointsToTheMap(pointData)
		if not pointData then return end
		local data
		for _,data in ipairs(pointData) do
            --Replacing colons in special tags to "=COLON=" to avoid interpreting internat ":" marks 
            data = string.gsub(data, '%(.+%)', function(textFound) 
                return string.gsub(textFound, ":", "=COLON=")
            end) 
			GetCreatePoint(strsplit(":", data))
		end
	end
	
	local function AddFlightPointData()
		local fullData = DGV.Modules.TaxiData:GetFullData()
		local faction = UnitFactionGroup("player")
		local characterData
		if DugisFlightmasterDataTable then 
			characterData = DugisFlightmasterDataTable
		end
		local map = DGV:GetCurrentMapID() 
		if map == 876 or map == 875 then return end		
		local continent = GetCurrentMapContinent_dugi()		
		if fullData and fullData[continent] then
			for npc,data in pairs(fullData[continent]) do
				local requirements = data and data.requirements
				local name 
				if characterData and characterData[continent] and characterData[continent][npc] then 
					name = characterData[continent][npc].name
				end
				if 
					data.m==map and 
					(not requirements or DGV:CheckRequirements(strsplit(":", requirements)))
				then
					GetCreatePoint("5", data.coord, npc, name)
				end
			end
		end
	end
    
	local function GetNearest(button)
		local shortest, shortestDist
		--for _,point in ipairs(trackingPoints) do
		--	local selected
		--	if (button.arg1 and button.arg1==point.args[4]) or button.arg1==point.args[1] then
		for point in DGV.IterateAllFindNearestPoints() do
			local selected
			if (button.arg1 and button.arg1==point[6]) or button.arg1==point[3] then
				selected = point
				local dist = GetDistance(selected)
				if dist and (not shortestDist or dist < shortestDist) then
					shortest = selected
					shortestDist = dist
				end
			end
		end
		return shortest
	end

	local function FindNearest(button)
		local DugisArrow = DGV.Modules.DugisArrow
		DGV:RemoveAllWaypoints()
		--AddWaypoint(GetNearest(button))
		local nearest = GetNearest(button)
		if nearest then
			local x, y = DGV:UnpackXY(nearest[4])
			local map, level = nearest[1], nearest[2] or DugisArrow.floor
			DGV:AddCustomWaypoint(
				x, y, DataProviders:GetTooltipText(nil, unpack(nearest, 3)),
				map, level)
		end
        
        if LuaUtils:IsElvUIInstalled() then
            DropDownList1.showTimer = 1
        else
            LibDugi_DropDownList1.showTimer = 1
        end        

        LibDugi_HideDropDownMenu(1)
        LibDugi_HideDropDownMenu(2)
	end

	local function IterateDropdownLevel(level)
		local listFrame = _G["DropDownList"..level];
               
		local listFrameName = listFrame:GetName();
		local count = listFrame.numButtons
		local i = 0
		return function()
			i = i + 1
			if i<=count then return _G[listFrameName.."Button"..i] end
		end
	end


	
	local function UpdateCurrentMapVersion()
		local currentMapName = DGV:GetDisplayedMapNameOld()
		local nsMapName = UnspecifyMapName(currentMapName)
		if nsMapName then
			if not DugisGuideUser.CurrentMapVersions then
				DugisGuideUser.CurrentMapVersions = {}
			end
			DugisGuideUser.CurrentMapVersions[nsMapName] = currentMapName
		end
	end

	
	--[[ todo: find replacement
	hooksecurefunc("WorldMapFrame_UpdateMap",
		function()
			if WMT.loaded then
				WMT:UpdateTrackingMap()
				UpdateCurrentMapVersion()
			end
		end)
          
	]]

		
	function DGV:MINIMAP_UPDATE_TRACKING()
		WMT:UpdateTrackingMap()
	end

	function DGV:TRAINER_SHOW()
		local npcId = DGV:GuidToNpcId(UnitGUID("npc"))
		local x,y = select(3, DGV:GetPlayerPosition())
		if y then 
			local packed = DGV:PackXY(x,y)
			DGV:DebugFormat("TRAINER_SHOW", "Tracking Data", format("(type):%s:%s", packed, npcId))
		end
	end

	function WMT:OnMapChangedOrOpen()
		WMT:UpdateTrackingMap()
	end
	
	function WMT:Load()
		LuaUtils:Delay(3, function()
            DGV:PopulatePetJournalLookup()
        end)
		function WMT:UpdateTrackingMap()
			if not WMT.loaded then return end
			
			local mapName = DGV:GetDisplayedMapNameOld()
			local level = DGV:UiMapID2DungeonLevel(WorldMapFrame:GetMapID())
			
			RemoveAllPoints()
			if not DGV:UserSetting(DGV_WORLDMAPTRACKING) then return end
            
            local faction = UnitFactionGroup("player")
            
            if mapName and level then
                AddPointsToTheMap(DugisWorldMapTrackingPoints[faction][mapName..":"..level]);
                AddPointsToTheMap(DugisWorldMapTrackingPoints[mapName])
                AddPointsToTheMap(DugisWorldMapTrackingPoints[mapName..":"..level])
            end
            
            --Using map ID - BFA maps
            local mapId = WorldMapFrame:GetMapID()
            
            if not mapId then
                return
            end
            
            AddPointsToTheMap(DugisWorldMapTrackingPoints[mapId])
            AddPointsToTheMap(DugisWorldMapTrackingPoints[faction][mapId])

			if not trackingPoints[1] then
				local nsMapName = UnspecifyMapName(mapName)
				if nsMapName then
					AddPointsToTheMap(DugisWorldMapTrackingPoints[faction][nsMapName..":"..level]);
					AddPointsToTheMap(DugisWorldMapTrackingPoints[nsMapName])
					AddPointsToTheMap(DugisWorldMapTrackingPoints[nsMapName..":"..level])
				end
			end
			if CollectedWorldMapTrackingPoints_v2 and CollectedWorldMapTrackingPoints_v2[faction] then
                if mapName then
                    AddPointsToTheMap(CollectedWorldMapTrackingPoints_v2[faction][mapName..":"..level])
                end
                
                if mapId then
                    AddPointsToTheMap(CollectedWorldMapTrackingPoints_v2[faction][mapId])
                end
				
			end
			AddFlightPointData()
			
			UpdateTrackingFilters()
		end
	
		DGV:RegisterEvent("TRAINER_SHOW")
        
        local function HasMinimapMenuPetTrackingOption()
            local result = false
            
            local dropDownPrefix = ""
            
            LuaUtils:loop(_G[dropDownPrefix.."DropDownList1"].numButtons, function(buttonIndex)
                local buttonIcon = _G[dropDownPrefix.."DropDownList1Button"..buttonIndex.."Icon"]
                local button = _G[dropDownPrefix.."DropDownList1Button"..buttonIndex]
                local text = _G[dropDownPrefix.."DropDownList1Button"..buttonIndex.."NormalText"]
                
                local texture = buttonIcon:GetTexture()
                
                if (texture ~= nil and type(texture) ~= "number" and texture:match("tracking_wildpet")) or texture == 613074 then
                    local list = _G[dropDownPrefix.."DropDownList1"]
                    if buttonIcon:IsShown() then  
                        result = true
                    end
                end

            end)
            
            return result
        end        
       
        local function IsShowMinimapMenu()
            local result = 0
            
            local dropDownPrefix = ""
            
            LuaUtils:loop(_G[dropDownPrefix.."DropDownList1"].numButtons, function(buttonIndex)
                local button = _G[dropDownPrefix.."DropDownList1Button"..buttonIndex]
                
                if button:GetText() == MINIMAP_TRACKING_NONE and button:IsShown() and button:IsVisible() then
                    result = result + 1
                end 
                
                if button:GetText() == TOWNSFOLK_TRACKING_TEXT and button:IsShown() and button:IsVisible() then
                    result = result + 1
                end
            end)
            
            return result == 2
        end

        local moved = false
        local allTrackingPoints = nil
        
        local function GetAllTrackingPoints()
            local result = {}
            for point in DGV.IterateAllFindNearestPoints() do  
                result[#result + 1] = point
            end            
            return result
        end
        

        
        local function PetFilterMenuItemClicked(item)
            local menuType = item.arg1
            local petTypeIndex = item.arg2
            
            if petTypeIndex then
                getPetTypeFilters()[petTypeIndex] = not getPetTypeFilters()[petTypeIndex]
				
				--Clearing old convention
				getPetTypeFilters()[allPetTypes[petTypeIndex][1]] = nil
            end
            
            if menuType == "check-all" then
                LuaUtils:foreach(allPetTypes, function(itemType, itemTypeIndex)
                    getPetTypeFilters()[itemTypeIndex] = true
					
					--Clearing old convention
					getPetTypeFilters()[allPetTypes[itemTypeIndex][1]] = nil
                end)
            end
            
            if menuType == "uncheck-all" then
                LuaUtils:foreach(allPetTypes, function(itemType, itemTypeIndex)
                    getPetTypeFilters()[itemTypeIndex] = false
					
					--Clearing old convention
					getPetTypeFilters()[allPetTypes[itemTypeIndex][1]] = nil
                end)
            end  
            
            if menuType == "collected" then
                DugisGuideViewer.chardb["showCollectedPets"] = not DugisGuideViewer.chardb["showCollectedPets"]
            end
            
            if menuType == "not-collected" then
                DugisGuideViewer.chardb["showNotCollectedPets"] = not DugisGuideViewer.chardb["showNotCollectedPets"]
            end
            
            UpdateTrackingFilters()
            LibDugi_UIDropDownMenu_Refresh(MinimapExtraMenuFrame)
        end  

        local function ShowExtraMenu()
            if not IsShowMinimapMenu() then
                return
            end
            
            if not MinimapExtraMenuFrame then
                extraMenuFrame = CreateFrame("Frame", "MinimapExtraMenuFrame", UIParent, "LibDugi_UIDropDownMenuTemplate")
            end
        
            if allTrackingPoints == nil then
                allTrackingPoints =  GetAllTrackingPoints()
            end

            local nearestOptions = {} 
            local petsOptions = {} 
            local menu = {
                { text = "Dugi Guides", isTitle = true, isNotRadio = true, notCheckable = true
                },
                { text = "Find nearest", hasArrow = true, isNotRadio = true, notCheckable = true,
                    menuList = nearestOptions
                }
            }
            
            if DugisGuideViewer.ExtendedTrackingPointsExists and HasMinimapMenuPetTrackingOption() then
                menu[#menu + 1] = { text = "Tracked Pets |TInterface\\AddOns\\DugisGuideViewerZ\\Artwork\\PetBattleIcon:20:20:5:0|t", hasArrow = true, isNotRadio = true, notCheckable = true,
                    menuList = petsOptions
                }
            end
            
            local function AddPetFilterItemToMenu(name, menuType, petTypeIndex, checkable, icon)
                local info = {}
                info.func = PetFilterMenuItemClicked
                info.text = name
                info.icon = icon
                info.arg1 = menuType
                info.arg2 = petTypeIndex
                info.notCheckable = not checkable
                info.keepShownOnClick = true
                info.isNotRadio = true
                
                if petTypeIndex then
                    info.checked = function(button) 
						local petTypeIndex = button.arg2
						--petType for backward compatibility
						local petType = allPetTypes[button.arg2][1]
						
						if getPetTypeFilters()[petTypeIndex] ~= nil then
							return getPetTypeFilters()[petTypeIndex]
						end
						return getPetTypeFilters()[petType] == true
					end
                end
                
                if menuType == "collected" then
                    info.checked = function() return DugisGuideViewer.chardb["showCollectedPets"] end
                end           
                if menuType == "not-collected" then
                    info.checked = function() return DugisGuideViewer.chardb["showNotCollectedPets"] end
                end
                
                petsOptions[#petsOptions + 1] = info
            end
            
            AddPetFilterItemToMenu("Check All",    "check-all")
            AddPetFilterItemToMenu("Uncheck All",  "uncheck-all")

            local iconPathDir = [[Interface\ICONS\Pet_Type_]]

            AddPetFilterItemToMenu("Collected",         "collected",      nil, true)     
            AddPetFilterItemToMenu("Not Collected",     "not-collected",  nil, true)  

            LuaUtils:foreach(allPetTypes, function(petType, petTypeIndex)
                local petTypeName = petType[1]
                local petTypeIcon = petType[2]
                AddPetFilterItemToMenu(petTypeName, "pet-type", petTypeIndex, true, iconPathDir..petTypeIcon) 
            end)

            local added = {}
            LuaUtils:foreach(allTrackingPoints, function(point)
                local button
                local found = false
                local trackingType = point[3]
                local name, texture = GetTrackingInfo(trackingType)
                if name and not added[name] then
                    added[name] = true
                    
                    local info;
                    info = {}
                    info.text = name
                    info.func = FindNearest;
                    info.icon = texture;
                    info.arg1 = trackingType;
                    info.isNotRadio = true;
                    info.notCheckable = true
                    info.keepShownOnClick = true;
                    info.tCoordLeft = 0;
                    info.tCoordRight = 1;
                    info.tCoordTop = 0;
                    info.tCoordBottom = 1;

                    if trackingType==10 then
                        info.icon = nil;
                        info.func =  nil;
                        info.notCheckable = true;
                        info.keepShownOnClick = false;
                        info.hasArrow = true;
                                
                        info.menuList = {}
                        local added1 = {}
                                
                         LuaUtils:foreach(allTrackingPoints, function(point1)
                            local trackingType, _, _, spell = unpack(point1, 3)
                            if trackingType==10 and spell and not added1[spell] then
                                added1[spell] = true
                                
                                local info1;
                                info1 = {};
                                info1.text = professionTable[spell];
                                info1.func = FindNearest;
                                info1.notCheckable = true
                                info1.icon = select(2, GetTrackingInfo(10));
                                info1.arg1 = spell;
                                info1.isNotRadio = true;
                                info1.keepShownOnClick = false;
                                
                                info.menuList[#info.menuList + 1]  = info1
                            end
                        end)
                        
                    end
                    
                    nearestOptions[#nearestOptions + 1]  = info
                end
            end)
            
            local added = {}
            
            for providerKey,provider in DataProviders.IterateProviders do
                if provider.GetCustomTrackingInfo then
                    local text, icon, configAccessor, configMutator =  provider:GetCustomTrackingInfo()
                    if text then
                    
                        local option = {}
                        local info;
                        option.text = L[text]
                        option.icon = icon
                        option.arg1 = nil;
                        option.checked = configAccessor
                        option.isNotRadio = true;
                        option.func =  function(arg1, arg2, arg3, enabled)
                            configMutator(enabled)
                            WMT:UpdateTrackingMap()
                        end;
                        option.notCheckable = false;
                        option.keepShownOnClick = true;
                        option.hasArrow = false;
                        
                        menu[#menu + 1] = option
                        
                    end
                end
            end

            MinimapExtraMenuFrame.point = "TOPRIGHT"
            MinimapExtraMenuFrame.relativePoint = "BOTTOMRIGHT"

			local top = DropDownList1:GetTop()
			if top ~= nil and top < GetScreenHeight() * 0.5 then
				MinimapExtraMenuFrame.point = "BOTTOMRIGHT"
				MinimapExtraMenuFrame.relativePoint = "TOPRIGHT"
			end
			
             if LuaUtils:IsElvUIInstalled() then
                LibDugi_EasyMenu(menu, MinimapExtraMenuFrame, DropDownList1, 0 , -3, "MENU"); 
                LuaUtils:TransferBackdropFromElvUI()
             else
                LibDugi_EasyMenu(menu, MinimapExtraMenuFrame, DropDownList1, 0 , 0, "MENU");
             end
            
            if not hooked then
                hooked = true

                local DropDownList = DropDownList1
                
                LibDugi_DropDownList1:HookScript("OnEnter", function()
                    DropDownList.showTimer = 10000
                end)            

                DropDownList:HookScript("OnEnter", function()
                    LibDugi_DropDownList1.showTimer = 10000
                end)
            
                DropDownList:HookScript("OnHide", function()
                   if LibDugi_DropDownList1:IsShown() then
                       LibDugi_HideDropDownMenu(1)
                       LibDugi_HideDropDownMenu(2)
                   end
                   
                   allTrackingPoints = nil
                end)
                
                LibDugi_DropDownList1:HookScript("OnHide", function()
                    DropDownList.showTimer = 0.1
                end)
                
            end
        end

        if ElvUIMiniMapTrackingDropDown then
            hooksecurefunc(ElvUIMiniMapTrackingDropDown, "initialize", function()
				LuaUtils:Delay(0.01, function()
					 ShowExtraMenu()
				end)
            end)

            hooksecurefunc("LibDugi_UIDropDownMenu_Initialize",  function()
                LuaUtils:TransferBackdropFromElvUI()
            end)
            
            DropDownList1:HookScript("OnShow", function()
				LuaUtils:Delay(0.01, function()
					 ShowExtraMenu()
				end)
            end)
            
        else
            DropDownList1:HookScript("OnShow", function()
                ShowExtraMenu()
            end)
        end

		--DGV:RegisterEvent("LOOT_CLOSED")
		--DGV:RegisterEvent("LOOT_SLOT_CLEARED")
		DGV:RegisterEvent("PET_JOURNAL_LIST_UPDATE")
		DGV:RegisterEvent("MINIMAP_UPDATE_TRACKING")
		WMT:UpdateTrackingMap()
	end
	
	function WMT:Unload()
		--DGV:UnregisterEvent("LOOT_CLOSED")
		--DGV:UnregisterEvent("LOOT_SLOT_CLEARED")
		DGV:UnregisterEvent("PET_JOURNAL_LIST_UPDATE")
		DGV:UnregisterEvent("TRAINER_SHOW")
		DGV:UnregisterEvent("MINIMAP_UPDATE_TRACKING")
	end

    local function AbandonByQuestId(questID)
        for i=1,GetNumQuestLogEntries() do 
            SelectQuestLogEntry(i)
            local AbandonQID = select(8, GetQuestLogTitle(i))
            if AbandonQID == questID then
                SetAbandonQuest()
                AbandonQuest() 
            end
        end
    end

    local pressedAbandonIndex = nil
    StaticPopupDialogs["GROUP_ABANDON_CONFIRMATION"] = {
        text = L["Abandon All Quests?"],
        button1 = YES,
        button2 = NO,
        OnHide = function()
            pressedAbandonIndex = nil
        end,
        OnAccept = function()
            local questIdsToBeAbandoned = {}
            local questLogIndex = pressedAbandonIndex + 1
            local numEntries = GetNumQuestLogEntries()
            for i = questLogIndex, numEntries do
                local _, _, _, isHeader, _, _, _, questID = GetQuestLogTitle(i)
                if isHeader then
                    break
                else
                    questIdsToBeAbandoned[#questIdsToBeAbandoned + 1] = questID
                end
            end
            LuaUtils:foreach(questIdsToBeAbandoned, function(questID)
                AbandonByQuestId(questID)
            end)
            pressedAbandonIndex = nil
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }

    hooksecurefunc("QuestLogQuests_Update", function(...)
	
		if not QuestScrollFrame.headerFramePool then
			return
		end
		
        for parentButton in QuestScrollFrame.headerFramePool:EnumerateActive() do
            if parentButton.abandonGroupButton == nil then
                local buttonFrame = GUIUtils:AddButton(parentButton, "", 231, 6, 28, 28, 28, 28, function(self)  
                    StaticPopupDialogs["GROUP_ABANDON_CONFIRMATION"].text = L["Abandon All "] .. GetQuestLogTitle(self.abandonGroupButton.questLogIndex) .. L[" Quests?"]
                    if pressedAbandonIndex == nil then
                        pressedAbandonIndex = self.abandonGroupButton.questLogIndex
                        StaticPopup_Show ("GROUP_ABANDON_CONFIRMATION")
                    end
                end, [[INTERFACE\BUTTONS\CancelButton-Up]], [[INTERFACE\BUTTONS\CancelButton-Down]], [[INTERFACE\BUTTONS\CancelButton-Down]])
                buttonFrame.button.abandonGroupButton =  parentButton
                parentButton.abandonGroupButton = buttonFrame
            end
            if parentButton.abandonGroupButton then
                if not DGV:UserSetting(DGV_SHOWQUESTABANDONBUTTON) then
                    parentButton.abandonGroupButton.button:Hide()
                else
                    parentButton.abandonGroupButton.button:Show()
                end
            end
        end
		
    end)
end


local AceGUI = LibStub("AceGUI-3.0")

local speciesData = {}
local exportResults = {}
local exportNavigationIndex = 1
local onePageResultsAmount = 2000 --Pets / page

function DugisGuideViewer:ShowResults()
    if not exportTextEditor then
        exportTextEditor = AceGUI:Create("MultiLineEditBox")
        exportTextEditor.frame:SetParent(UIParent)
        exportTextEditor.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 250, -80)
        exportTextEditor.frame:SetWidth(470)
        exportTextEditor.frame:SetHeight(470)
        exportTextEditor.frame:Show()
    end
    
    exportTextEditor:SetText(exportResults[exportNavigationIndex] or "No more results.")
    
    exportTextEditor.label:SetText("Pets from "..((exportNavigationIndex -1) * onePageResultsAmount).." to "..((exportNavigationIndex * onePageResultsAmount))..". Press 'Next results' to see next results.") 
    exportTextEditor.button:SetScript("OnClick", function()
        exportNavigationIndex = exportNavigationIndex + 1
        DugisGuideViewer:ShowResults()
    end) 
    
    exportTextEditor.button:SetText("Next results")
    exportTextEditor.button:SetWidth(200)
    
    exportTextEditor.button:Enable()
end

--/run DugisGuideViewer:ExportPets()
function DugisGuideViewer:ExportPets(optimized)
    exportNavigationIndex = 1
    
    if not DataExport then
        DataExport = {}
    end

    local zoneKey_Level2PetInfos = {}

    LuaUtils:foreach(speciesData, function(pets, zoneId)
        LuaUtils:foreach(pets, function(pet, petId)
            LuaUtils:foreach(pet, function(points, floor_)
                for xText, yText in gmatch(points, '(%w%w)(%w%w)') do 
                    local x, y = tonumber(xText, 36) / 10, tonumber(yText, 36) / 10
                    
                    local dugiKey = ""..zoneId..":"..floor_
                    
                    if not  zoneKey_Level2PetInfos[dugiKey] then
                        zoneKey_Level2PetInfos[dugiKey] = {}
                    end
                    
                    local petInfos =  zoneKey_Level2PetInfos[dugiKey]
                   
                    local speciesName, speciesIcon, petType, companionID, tooltipSource, tooltipDescription, isWild, canBattle, isTradeable, isUnique, obtainable, creatureDisplayID 
                    = C_PetJournal.GetPetInfoBySpeciesID(petId)
                   
                    petType = _G['BATTLE_PET_NAME_' .. petType]
                   
                    petInfos[#petInfos + 1] = {x = x, y = y, xText =xText, yText = yText,   petId = petId, category = "", petName = speciesName, petType = petType}
                end
            end)
        end)
    end)
    
    --Exporting to Dugi format;
    local counter = 0
    LuaUtils:foreach(zoneKey_Level2PetInfos, function(petInfos, zoneId_Level)
    
        local zoneIdLevel = LuaUtils:split(zoneId_Level, ":")
        local zoneId = zoneIdLevel[1]
        local zoneName = DugisGuideViewer:GetMapNameFromID(zoneId)
        
    
        local result = "\n--"..zoneName.."\nsafeTappend(\""..zoneId_Level.."\", {"
        
        local lastPetId = -1
        for i = 1, #petInfos do
            local petInfo = petInfos[i]
            counter = counter + 1
            
            local comma = ","
            
            if i == #petInfos then
               comma = ""
            end
            
            if lastPetId == petInfo.petId then
                if optimized then
                    --todo: Implement extra specialization for the same pet
                    --result = result..petInfo.xText..petInfo.yText -- Extra optimized
                    --result = result.."\n\"*"..petInfo.x..","..petInfo.y.."\","
                else
                    result = result.."\n\"P:"..petInfo.x..","..petInfo.y..":"..petInfo.petId..":"..petInfo.category .."\""..comma --.."  -- ↑"
                end
            else
                result = result.."\n--"..petInfo.petName.."/"..petInfo.petType..":\n\"P:"..petInfo.x..","..petInfo.y..":"..petInfo.petId..":"..petInfo.category .."\""..comma--.."  -- "..petInfo.petName.."/"..petInfo.petType
            end
            
            lastPetId = petInfo.petId

        end
        
        result = result.."\n})\n"
        
        local exportResultIndex = math.floor(counter / onePageResultsAmount) + 1
        
        if exportResults[exportResultIndex] == nil then
            exportResults[exportResultIndex] = ""
        end
        
        exportResults[exportResultIndex] = exportResults[exportResultIndex]..result
    end)
    
    DugisGuideViewer:ShowResults()
end

